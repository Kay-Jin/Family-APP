import secrets
import sqlite3
import string
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import jwt
from flask import Flask, g, jsonify, request

BASE_DIR = Path(__file__).parent
DB_PATH = BASE_DIR / "family_app.db"

app = Flask(__name__)
JWT_SECRET = "dev-secret-change-me"
JWT_ALG = "HS256"
JWT_EXPIRE_DAYS = 30


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = get_db()
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            union_id TEXT UNIQUE NOT NULL,
            display_name TEXT NOT NULL,
            avatar_url TEXT,
            birthday TEXT,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS families (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            invite_code TEXT UNIQUE NOT NULL,
            owner_user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS family_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            role TEXT NOT NULL DEFAULT 'member',
            joined_at TEXT NOT NULL,
            UNIQUE (family_id, user_id)
        );
        CREATE TABLE IF NOT EXISTS photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            uploader_user_id INTEGER NOT NULL,
            image_url TEXT NOT NULL,
            caption TEXT,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS photo_comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            photo_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS photo_likes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            photo_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE (photo_id, user_id)
        );
        CREATE TABLE IF NOT EXISTS daily_questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            question_date TEXT NOT NULL,
            question_text TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS daily_answers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            answer_text TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS birthday_reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            birthday TEXT NOT NULL,
            notify_days_before INTEGER NOT NULL DEFAULT 1,
            enabled INTEGER NOT NULL DEFAULT 1
        );
        """
    )
    db.commit()


def now_iso() -> str:
    return datetime.utcnow().isoformat()


def auth_user_id():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth.replace("Bearer ", "", 1).strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        return int(payload["user_id"])
    except Exception:
        return None


def require_auth():
    user_id = auth_user_id()
    if user_id is None:
        return None, (jsonify({"error": "unauthorized"}), 401)
    return user_id, None


def user_in_family(user_id: int, family_id: int) -> bool:
    db = get_db()
    row = db.execute(
        "SELECT id FROM family_members WHERE family_id = ? AND user_id = ?",
        (family_id, user_id),
    ).fetchone()
    return row is not None


def make_invite_code(length: int = 8) -> str:
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


@app.route("/auth/wechat-login", methods=["POST"])
def wechat_login():
    payload = request.get_json(force=True)
    code = payload.get("code")
    if not code:
        return jsonify({"error": "code is required"}), 400

    db = get_db()
    union_id = f"wx_{code}"  # TODO: replace with real WeChat code exchange.
    user = db.execute("SELECT * FROM users WHERE union_id = ?", (union_id,)).fetchone()
    if user is None:
        display_name = payload.get("display_name", "New Member")
        avatar_url = payload.get("avatar_url")
        db.execute(
            """
            INSERT INTO users (union_id, display_name, avatar_url, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (union_id, display_name, avatar_url, now_iso()),
        )
        db.commit()
        user = db.execute("SELECT * FROM users WHERE union_id = ?", (union_id,)).fetchone()

    return jsonify(
        {
            "user_id": user["id"],
            "union_id": user["union_id"],
            "token": jwt.encode(
                {
                    "user_id": user["id"],
                    "union_id": user["union_id"],
                    "exp": datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRE_DAYS),
                },
                JWT_SECRET,
                algorithm=JWT_ALG,
            ),
        }
    )


@app.route("/families", methods=["POST"])
def create_family():
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    name = payload.get("name")
    if not name:
        return jsonify({"error": "name is required"}), 400

    db = get_db()
    owner = db.execute("SELECT id FROM users WHERE id = ?", (caller_user_id,)).fetchone()
    if owner is None:
        return jsonify({"error": "owner not found"}), 404

    invite_code = make_invite_code()
    db.execute(
        """
        INSERT INTO families (name, invite_code, owner_user_id, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (name, invite_code, caller_user_id, now_iso()),
    )
    family_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    db.execute(
        """
        INSERT INTO family_members (family_id, user_id, role, joined_at)
        VALUES (?, ?, 'owner', ?)
        """,
        (family_id, caller_user_id, now_iso()),
    )
    db.commit()
    return jsonify({"id": family_id, "name": name, "invite_code": invite_code, "owner_user_id": caller_user_id})


@app.route("/families/join", methods=["POST"])
def join_family():
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    invite_code = payload.get("invite_code")
    if not invite_code:
        return jsonify({"error": "invite_code is required"}), 400
    db = get_db()
    family = db.execute("SELECT id FROM families WHERE invite_code = ?", (invite_code,)).fetchone()
    if family is None:
        return jsonify({"error": "family not found"}), 404
    try:
        db.execute(
            "INSERT INTO family_members (family_id, user_id, role, joined_at) VALUES (?, ?, 'member', ?)",
            (family["id"], caller_user_id, now_iso()),
        )
        db.commit()
        return jsonify({"message": "joined", "family_id": family["id"]})
    except sqlite3.IntegrityError:
        return jsonify({"message": "already joined", "family_id": family["id"]})


@app.route("/families/<int:family_id>/members", methods=["GET"])
def list_members(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute("SELECT * FROM family_members WHERE family_id = ?", (family_id,)).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/daily-questions", methods=["POST"])
def create_daily_question():
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    if not user_in_family(caller_user_id, payload["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    db.execute(
        """
        INSERT INTO daily_questions (family_id, question_date, question_text, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (payload["family_id"], payload["question_date"], payload["question_text"], now_iso()),
    )
    db.commit()
    question_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify({"id": question_id, **payload})


@app.route("/families/<int:family_id>/daily-questions", methods=["GET"])
def list_daily_questions(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        "SELECT id, family_id, question_date, question_text FROM daily_questions WHERE family_id = ? ORDER BY id DESC",
        (family_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/daily-answers", methods=["POST"])
def create_daily_answer():
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    payload["user_id"] = caller_user_id
    db = get_db()
    question = db.execute("SELECT family_id FROM daily_questions WHERE id = ?", (payload["question_id"],)).fetchone()
    if question is None:
        return jsonify({"error": "question not found"}), 404
    if not user_in_family(caller_user_id, question["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    db.execute(
        """
        INSERT INTO daily_answers (question_id, user_id, answer_text, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (payload["question_id"], payload["user_id"], payload["answer_text"], now_iso()),
    )
    db.commit()
    answer_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify({"id": answer_id, **payload})


@app.route("/photos", methods=["POST"])
def create_photo():
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    if not user_in_family(caller_user_id, payload["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    payload["uploader_user_id"] = caller_user_id
    db = get_db()
    db.execute(
        """
        INSERT INTO photos (family_id, uploader_user_id, image_url, caption, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (payload["family_id"], payload["uploader_user_id"], payload["image_url"], payload.get("caption"), now_iso()),
    )
    db.commit()
    photo_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify({"id": photo_id, **payload})


@app.route("/families/<int:family_id>/photos", methods=["GET"])
def list_photos(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        """
        SELECT id, family_id, uploader_user_id, image_url, COALESCE(caption, '') AS caption
        FROM photos
        WHERE family_id = ?
        ORDER BY id DESC
        """,
        (family_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/photos/<int:photo_id>/comments", methods=["POST"])
def comment_photo(photo_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    payload["user_id"] = caller_user_id
    db = get_db()
    photo = db.execute("SELECT family_id FROM photos WHERE id = ?", (photo_id,)).fetchone()
    if photo is None:
        return jsonify({"error": "photo not found"}), 404
    if not user_in_family(caller_user_id, photo["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    db.execute(
        """
        INSERT INTO photo_comments (photo_id, user_id, content, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (photo_id, payload["user_id"], payload["content"], now_iso()),
    )
    db.commit()
    comment_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify({"id": comment_id, "photo_id": photo_id, **payload})


@app.route("/photos/<int:photo_id>/likes", methods=["POST"])
def like_photo(photo_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    payload["user_id"] = caller_user_id
    db = get_db()
    photo = db.execute("SELECT family_id FROM photos WHERE id = ?", (photo_id,)).fetchone()
    if photo is None:
        return jsonify({"error": "photo not found"}), 404
    if not user_in_family(caller_user_id, photo["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    try:
        db.execute(
            "INSERT INTO photo_likes (photo_id, user_id, created_at) VALUES (?, ?, ?)",
            (photo_id, payload["user_id"], now_iso()),
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"message": "already liked"})
    return jsonify({"message": "liked"})


@app.route("/birthday-reminders", methods=["POST"])
def create_birthday_reminder():
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    if not user_in_family(caller_user_id, payload["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    payload["user_id"] = caller_user_id
    db = get_db()
    db.execute(
        """
        INSERT INTO birthday_reminders (family_id, user_id, birthday, notify_days_before, enabled)
        VALUES (?, ?, ?, ?, 1)
        """,
        (
            payload["family_id"],
            payload["user_id"],
            payload["birthday"],
            payload.get("notify_days_before", 1),
        ),
    )
    db.commit()
    reminder_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify({"id": reminder_id, **payload})


@app.route("/birthday-reminders/today", methods=["GET"])
def birthday_today():
    caller_user_id, err = require_auth()
    if err:
        return err
    today = date.today().strftime("%m-%d")
    db = get_db()
    rows = db.execute(
        """
        SELECT br.*
        FROM birthday_reminders br
        JOIN family_members fm ON fm.family_id = br.family_id
        WHERE br.enabled = 1 AND fm.user_id = ?
        """,
        (caller_user_id,),
    ).fetchall()
    due = [dict(r) for r in rows if r["birthday"][5:] == today]
    return jsonify(due)


with app.app_context():
    init_db()


if __name__ == "__main__":
    app.run(debug=True, port=8000)
