import secrets
import sqlite3
import string
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import jwt
from flask import Flask, g, jsonify, request, send_from_directory
from werkzeug.utils import secure_filename

BASE_DIR = Path(__file__).parent
DB_PATH = BASE_DIR / "family_app.db"
UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

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
        CREATE TABLE IF NOT EXISTS family_status_updates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status_code TEXT NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS voice_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            sender_user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            audio_url TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS emergency_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            contact_name TEXT NOT NULL,
            relation TEXT NOT NULL,
            phone TEXT NOT NULL,
            city TEXT,
            medical_notes TEXT,
            is_primary INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS family_medical_cards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL UNIQUE,
            updated_by_user_id INTEGER NOT NULL,
            allergies TEXT,
            medications TEXT,
            hospitals TEXT,
            other_notes TEXT,
            accompaniment_requested INTEGER NOT NULL DEFAULT 0,
            accompaniment_note TEXT,
            updated_at TEXT NOT NULL
        );
        """
    )
    db.commit()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


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
    family = db.execute(
        "SELECT id, name, invite_code, owner_user_id FROM families WHERE invite_code = ?",
        (invite_code,),
    ).fetchone()
    if family is None:
        return jsonify({"error": "family not found"}), 404
    try:
        db.execute(
            "INSERT INTO family_members (family_id, user_id, role, joined_at) VALUES (?, ?, 'member', ?)",
            (family["id"], caller_user_id, now_iso()),
        )
        db.commit()
        return jsonify(
            {
                "message": "joined",
                "family_id": family["id"],
                "family": {
                    "id": family["id"],
                    "name": family["name"],
                    "invite_code": family["invite_code"],
                    "owner_user_id": family["owner_user_id"],
                },
            }
        )
    except sqlite3.IntegrityError:
        return jsonify(
            {
                "message": "already joined",
                "family_id": family["id"],
                "family": {
                    "id": family["id"],
                    "name": family["name"],
                    "invite_code": family["invite_code"],
                    "owner_user_id": family["owner_user_id"],
                },
            }
        )


@app.route("/families/<int:family_id>", methods=["GET"])
def get_family(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    family = db.execute(
        "SELECT id, name, invite_code, owner_user_id FROM families WHERE id = ?",
        (family_id,),
    ).fetchone()
    if family is None:
        return jsonify({"error": "family not found"}), 404
    return jsonify(dict(family))


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


@app.route("/daily-questions/<int:question_id>/answers", methods=["GET"])
def list_daily_answers(question_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    db = get_db()
    question = db.execute("SELECT family_id FROM daily_questions WHERE id = ?", (question_id,)).fetchone()
    if question is None:
        return jsonify({"error": "question not found"}), 404
    if not user_in_family(caller_user_id, question["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    rows = db.execute(
        """
        SELECT
            da.id,
            da.question_id,
            da.user_id,
            u.display_name AS user_display_name,
            da.answer_text,
            da.created_at
        FROM daily_answers da
        JOIN users u ON u.id = da.user_id
        WHERE da.question_id = ?
        ORDER BY da.id DESC
        """,
        (question_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


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


@app.route("/photos/upload", methods=["POST"])
def upload_photo():
    caller_user_id, err = require_auth()
    if err:
        return err
    family_id_raw = request.form.get("family_id")
    if not family_id_raw:
        return jsonify({"error": "family_id is required"}), 400
    try:
        family_id = int(family_id_raw)
    except ValueError:
        return jsonify({"error": "family_id must be an integer"}), 400
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    file = request.files.get("file")
    if file is None:
        return jsonify({"error": "file is required"}), 400
    filename = secure_filename(file.filename or "upload.jpg")
    if not filename:
        filename = "upload.jpg"
    suffix = Path(filename).suffix or ".jpg"
    saved_name = f"{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}_{secrets.token_hex(6)}{suffix}"
    target_path = UPLOAD_DIR / saved_name
    file.save(target_path)

    image_url = f"/uploads/{saved_name}"
    caption = request.form.get("caption", "")
    db = get_db()
    db.execute(
        """
        INSERT INTO photos (family_id, uploader_user_id, image_url, caption, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (family_id, caller_user_id, image_url, caption, now_iso()),
    )
    db.commit()
    photo_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify(
        {
            "id": photo_id,
            "family_id": family_id,
            "uploader_user_id": caller_user_id,
            "image_url": image_url,
            "caption": caption,
        }
    )


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
        SELECT
            p.id,
            p.family_id,
            p.uploader_user_id,
            p.image_url,
            COALESCE(p.caption, '') AS caption,
            (
                SELECT COUNT(1)
                FROM photo_likes pl
                WHERE pl.photo_id = p.id
            ) AS like_count,
            (
                SELECT COUNT(1)
                FROM photo_comments pc
                WHERE pc.photo_id = p.id
            ) AS comment_count,
            EXISTS (
                SELECT 1
                FROM photo_likes pl2
                WHERE pl2.photo_id = p.id AND pl2.user_id = ?
            ) AS has_liked
        FROM photos
        p
        WHERE p.family_id = ?
        ORDER BY p.id DESC
        """,
        (caller_user_id, family_id),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/uploads/<path:filename>", methods=["GET"])
def serve_upload(filename: str):
    return send_from_directory(UPLOAD_DIR, filename)


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


@app.route("/photos/<int:photo_id>/comments", methods=["GET"])
def list_photo_comments(photo_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    db = get_db()
    photo = db.execute("SELECT family_id FROM photos WHERE id = ?", (photo_id,)).fetchone()
    if photo is None:
        return jsonify({"error": "photo not found"}), 404
    if not user_in_family(caller_user_id, photo["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    rows = db.execute(
        """
        SELECT
            pc.id,
            pc.photo_id,
            pc.user_id,
            u.display_name AS user_display_name,
            pc.content,
            pc.created_at
        FROM photo_comments pc
        JOIN users u ON u.id = pc.user_id
        WHERE pc.photo_id = ?
        ORDER BY pc.id DESC
        """,
        (photo_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/photos/<int:photo_id>", methods=["DELETE"])
def delete_photo(photo_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    db = get_db()
    photo = db.execute(
        "SELECT id, family_id, uploader_user_id, image_url FROM photos WHERE id = ?",
        (photo_id,),
    ).fetchone()
    if photo is None:
        return jsonify({"error": "photo not found"}), 404
    if not user_in_family(caller_user_id, photo["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    if caller_user_id != photo["uploader_user_id"]:
        return jsonify({"error": "only uploader can delete this photo"}), 403

    db.execute("DELETE FROM photo_comments WHERE photo_id = ?", (photo_id,))
    db.execute("DELETE FROM photo_likes WHERE photo_id = ?", (photo_id,))
    db.execute("DELETE FROM photos WHERE id = ?", (photo_id,))
    db.commit()

    image_url = photo["image_url"] or ""
    if image_url.startswith("/uploads/"):
        file_path = UPLOAD_DIR / image_url.replace("/uploads/", "", 1)
        if file_path.exists():
            file_path.unlink()
    return jsonify({"message": "deleted"})


@app.route("/photos/<int:photo_id>", methods=["PATCH"])
def update_photo(photo_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    caption = payload.get("caption")
    if caption is None:
        return jsonify({"error": "caption is required"}), 400

    db = get_db()
    photo = db.execute(
        "SELECT id, family_id, uploader_user_id FROM photos WHERE id = ?",
        (photo_id,),
    ).fetchone()
    if photo is None:
        return jsonify({"error": "photo not found"}), 404
    if not user_in_family(caller_user_id, photo["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    if caller_user_id != photo["uploader_user_id"]:
        return jsonify({"error": "only uploader can edit this photo"}), 403

    db.execute("UPDATE photos SET caption = ? WHERE id = ?", (caption, photo_id))
    db.commit()
    return jsonify({"message": "updated", "id": photo_id, "caption": caption})


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


@app.route("/photos/<int:photo_id>/likes", methods=["DELETE"])
def unlike_photo(photo_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    db = get_db()
    photo = db.execute("SELECT family_id FROM photos WHERE id = ?", (photo_id,)).fetchone()
    if photo is None:
        return jsonify({"error": "photo not found"}), 404
    if not user_in_family(caller_user_id, photo["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    db.execute(
        "DELETE FROM photo_likes WHERE photo_id = ? AND user_id = ?",
        (photo_id, caller_user_id),
    )
    db.commit()
    return jsonify({"message": "unliked"})


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


@app.route("/families/<int:family_id>/birthday-reminders", methods=["GET"])
def list_birthday_reminders(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        """
        SELECT id, family_id, user_id, birthday, notify_days_before, enabled
        FROM birthday_reminders
        WHERE family_id = ?
        ORDER BY id DESC
        """,
        (family_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/families/<int:family_id>/activities", methods=["GET"])
def list_family_activities(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        """
        SELECT * FROM (
            SELECT
                'daily_question' AS activity_type,
                dq.id AS activity_id,
                'Family member' AS actor_name,
                dq.question_text AS content,
                dq.created_at AS created_at
            FROM daily_questions dq
            WHERE dq.family_id = ?

            UNION ALL

            SELECT
                'photo' AS activity_type,
                p.id AS activity_id,
                u.display_name AS actor_name,
                COALESCE(p.caption, '') AS content,
                p.created_at AS created_at
            FROM photos p
            JOIN users u ON u.id = p.uploader_user_id
            WHERE p.family_id = ?

            UNION ALL

            SELECT
                'daily_answer' AS activity_type,
                da.id AS activity_id,
                u.display_name AS actor_name,
                da.answer_text AS content,
                da.created_at AS created_at
            FROM daily_answers da
            JOIN daily_questions dq ON dq.id = da.question_id
            JOIN users u ON u.id = da.user_id
            WHERE dq.family_id = ?

            UNION ALL

            SELECT
                'photo_comment' AS activity_type,
                pc.id AS activity_id,
                u.display_name AS actor_name,
                pc.content AS content,
                pc.created_at AS created_at
            FROM photo_comments pc
            JOIN photos p ON p.id = pc.photo_id
            JOIN users u ON u.id = pc.user_id
            WHERE p.family_id = ?
        )
        ORDER BY created_at DESC
        LIMIT 50
        """,
        (family_id, family_id, family_id, family_id),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/birthday-reminders/<int:reminder_id>", methods=["PATCH"])
def update_birthday_reminder(reminder_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    birthday = payload.get("birthday")
    notify_days_before = payload.get("notify_days_before")
    enabled = payload.get("enabled")

    db = get_db()
    reminder = db.execute(
        "SELECT id, family_id, user_id FROM birthday_reminders WHERE id = ?",
        (reminder_id,),
    ).fetchone()
    if reminder is None:
        return jsonify({"error": "reminder not found"}), 404
    if not user_in_family(caller_user_id, reminder["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    if caller_user_id != reminder["user_id"]:
        return jsonify({"error": "only creator can edit reminder"}), 403

    fields = []
    params = []
    if birthday is not None:
        fields.append("birthday = ?")
        params.append(birthday)
    if notify_days_before is not None:
        fields.append("notify_days_before = ?")
        params.append(int(notify_days_before))
    if enabled is not None:
        fields.append("enabled = ?")
        params.append(1 if bool(enabled) else 0)
    if not fields:
        return jsonify({"error": "no update fields provided"}), 400

    params.append(reminder_id)
    db.execute(f"UPDATE birthday_reminders SET {', '.join(fields)} WHERE id = ?", params)
    db.commit()
    return jsonify({"message": "updated", "id": reminder_id})


@app.route("/birthday-reminders/<int:reminder_id>", methods=["DELETE"])
def delete_birthday_reminder(reminder_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    db = get_db()
    reminder = db.execute(
        "SELECT id, family_id, user_id FROM birthday_reminders WHERE id = ?",
        (reminder_id,),
    ).fetchone()
    if reminder is None:
        return jsonify({"error": "reminder not found"}), 404
    if not user_in_family(caller_user_id, reminder["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    if caller_user_id != reminder["user_id"]:
        return jsonify({"error": "only creator can delete reminder"}), 403
    db.execute("DELETE FROM birthday_reminders WHERE id = ?", (reminder_id,))
    db.commit()
    return jsonify({"message": "deleted"})


@app.route("/families/<int:family_id>/status-updates", methods=["POST"])
def create_status_update(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    payload = request.get_json(force=True)
    status_code = payload.get("status_code", "").strip()
    note = payload.get("note", "").strip()
    if not status_code:
        return jsonify({"error": "status_code is required"}), 400
    db = get_db()
    db.execute(
        """
        INSERT INTO family_status_updates (family_id, user_id, status_code, note, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (family_id, caller_user_id, status_code, note, now_iso()),
    )
    db.commit()
    update_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify(
        {
            "id": update_id,
            "family_id": family_id,
            "user_id": caller_user_id,
            "status_code": status_code,
            "note": note,
        }
    )


@app.route("/families/<int:family_id>/status-updates", methods=["GET"])
def list_status_updates(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        """
        SELECT
            s.id,
            s.family_id,
            s.user_id,
            u.display_name AS user_display_name,
            s.status_code,
            COALESCE(s.note, '') AS note,
            s.created_at
        FROM family_status_updates s
        JOIN users u ON u.id = s.user_id
        WHERE s.family_id = ?
        ORDER BY s.id DESC
        LIMIT 100
        """,
        (family_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/families/<int:family_id>/voice-messages", methods=["POST"])
def create_voice_message(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    payload = request.get_json(force=True)
    title = payload.get("title", "").strip()
    audio_url = payload.get("audio_url", "").strip()
    duration_seconds = int(payload.get("duration_seconds", 0))
    if not title or not audio_url:
        return jsonify({"error": "title and audio_url are required"}), 400
    db = get_db()
    db.execute(
        """
        INSERT INTO voice_messages (family_id, sender_user_id, title, audio_url, duration_seconds, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (family_id, caller_user_id, title, audio_url, duration_seconds, now_iso()),
    )
    db.commit()
    msg_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify(
        {
            "id": msg_id,
            "family_id": family_id,
            "sender_user_id": caller_user_id,
            "title": title,
            "audio_url": audio_url,
            "duration_seconds": duration_seconds,
        }
    )


@app.route("/families/<int:family_id>/voice-messages", methods=["GET"])
def list_voice_messages(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        """
        SELECT
            v.id,
            v.family_id,
            v.sender_user_id,
            u.display_name AS sender_display_name,
            v.title,
            v.audio_url,
            v.duration_seconds,
            v.created_at
        FROM voice_messages v
        JOIN users u ON u.id = v.sender_user_id
        WHERE v.family_id = ?
        ORDER BY v.id DESC
        LIMIT 100
        """,
        (family_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/families/<int:family_id>/voice-messages/upload", methods=["POST"])
def upload_voice_message(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403

    title = (request.form.get("title") or "").strip()
    if not title:
        return jsonify({"error": "title is required"}), 400
    duration_raw = request.form.get("duration_seconds", "0")
    try:
        duration_seconds = int(duration_raw)
    except ValueError:
        duration_seconds = 0

    file = request.files.get("file")
    if file is None:
        return jsonify({"error": "file is required"}), 400
    filename = secure_filename(file.filename or "voice.m4a")
    suffix = Path(filename).suffix or ".m4a"
    saved_name = f"voice_{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}_{secrets.token_hex(6)}{suffix}"
    target_path = UPLOAD_DIR / saved_name
    file.save(target_path)

    audio_url = f"/uploads/{saved_name}"
    db = get_db()
    db.execute(
        """
        INSERT INTO voice_messages (family_id, sender_user_id, title, audio_url, duration_seconds, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (family_id, caller_user_id, title, audio_url, duration_seconds, now_iso()),
    )
    db.commit()
    msg_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify(
        {
            "id": msg_id,
            "family_id": family_id,
            "sender_user_id": caller_user_id,
            "title": title,
            "audio_url": audio_url,
            "duration_seconds": duration_seconds,
        }
    )


@app.route("/voice-messages/<int:message_id>", methods=["PATCH"])
def update_voice_message(message_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    payload = request.get_json(force=True)
    title = (payload.get("title") or "").strip()
    if not title:
        return jsonify({"error": "title is required"}), 400
    db = get_db()
    row = db.execute(
        "SELECT id, family_id, sender_user_id FROM voice_messages WHERE id = ?",
        (message_id,),
    ).fetchone()
    if row is None:
        return jsonify({"error": "voice message not found"}), 404
    if not user_in_family(caller_user_id, row["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    if caller_user_id != row["sender_user_id"]:
        return jsonify({"error": "only sender can edit"}), 403
    db.execute("UPDATE voice_messages SET title = ? WHERE id = ?", (title, message_id))
    db.commit()
    return jsonify({"message": "updated", "id": message_id, "title": title})


@app.route("/voice-messages/<int:message_id>", methods=["DELETE"])
def delete_voice_message(message_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    db = get_db()
    row = db.execute(
        "SELECT id, family_id, sender_user_id, audio_url FROM voice_messages WHERE id = ?",
        (message_id,),
    ).fetchone()
    if row is None:
        return jsonify({"error": "voice message not found"}), 404
    if not user_in_family(caller_user_id, row["family_id"]):
        return jsonify({"error": "forbidden"}), 403
    if caller_user_id != row["sender_user_id"]:
        return jsonify({"error": "only sender can delete"}), 403
    db.execute("DELETE FROM voice_messages WHERE id = ?", (message_id,))
    db.commit()

    audio_url = row["audio_url"] or ""
    if audio_url.startswith("/uploads/"):
        file_path = UPLOAD_DIR / audio_url.replace("/uploads/", "", 1)
        if file_path.exists():
            file_path.unlink()
    return jsonify({"message": "deleted", "id": message_id})


@app.route("/families/<int:family_id>/emergency-contacts", methods=["POST"])
def create_emergency_contact(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    payload = request.get_json(force=True)
    contact_name = payload.get("contact_name", "").strip()
    relation = payload.get("relation", "").strip()
    phone = payload.get("phone", "").strip()
    city = payload.get("city", "").strip()
    medical_notes = payload.get("medical_notes", "").strip()
    is_primary = 1 if bool(payload.get("is_primary", False)) else 0
    if not contact_name or not relation or not phone:
        return jsonify({"error": "contact_name, relation, phone are required"}), 400
    db = get_db()
    db.execute(
        """
        INSERT INTO emergency_contacts
            (family_id, user_id, contact_name, relation, phone, city, medical_notes, is_primary, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (family_id, caller_user_id, contact_name, relation, phone, city, medical_notes, is_primary, now_iso()),
    )
    db.commit()
    contact_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    return jsonify(
        {
            "id": contact_id,
            "family_id": family_id,
            "user_id": caller_user_id,
            "contact_name": contact_name,
            "relation": relation,
            "phone": phone,
            "city": city,
            "medical_notes": medical_notes,
            "is_primary": is_primary,
        }
    )


@app.route("/families/<int:family_id>/emergency-contacts", methods=["GET"])
def list_emergency_contacts(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    rows = db.execute(
        """
        SELECT
            e.id,
            e.family_id,
            e.user_id,
            u.display_name AS user_display_name,
            e.contact_name,
            e.relation,
            e.phone,
            COALESCE(e.city, '') AS city,
            COALESCE(e.medical_notes, '') AS medical_notes,
            e.is_primary,
            e.created_at
        FROM emergency_contacts e
        JOIN users u ON u.id = e.user_id
        WHERE e.family_id = ?
        ORDER BY e.is_primary DESC, e.id DESC
        """,
        (family_id,),
    ).fetchall()
    return jsonify([dict(r) for r in rows])


@app.route("/families/<int:family_id>/medical-card", methods=["GET"])
def get_medical_card(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    row = db.execute(
        """
        SELECT
            id,
            family_id,
            updated_by_user_id,
            COALESCE(allergies, '') AS allergies,
            COALESCE(medications, '') AS medications,
            COALESCE(hospitals, '') AS hospitals,
            COALESCE(other_notes, '') AS other_notes,
            accompaniment_requested,
            COALESCE(accompaniment_note, '') AS accompaniment_note,
            updated_at
        FROM family_medical_cards
        WHERE family_id = ?
        """,
        (family_id,),
    ).fetchone()
    if row is None:
        return jsonify(
            {
                "id": None,
                "family_id": family_id,
                "updated_by_user_id": None,
                "allergies": "",
                "medications": "",
                "hospitals": "",
                "other_notes": "",
                "accompaniment_requested": 0,
                "accompaniment_note": "",
                "updated_at": None,
            }
        )
    return jsonify(dict(row))


@app.route("/families/<int:family_id>/medical-card", methods=["PUT"])
def upsert_medical_card(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    payload = request.get_json(force=True)
    allergies = (payload.get("allergies") or "").strip()
    medications = (payload.get("medications") or "").strip()
    hospitals = (payload.get("hospitals") or "").strip()
    other_notes = (payload.get("other_notes") or "").strip()
    accompaniment_requested = 1 if bool(payload.get("accompaniment_requested", False)) else 0
    accompaniment_note = (payload.get("accompaniment_note") or "").strip()
    db = get_db()
    existing = db.execute("SELECT id FROM family_medical_cards WHERE family_id = ?", (family_id,)).fetchone()
    if existing is None:
        db.execute(
            """
            INSERT INTO family_medical_cards
                (family_id, updated_by_user_id, allergies, medications, hospitals, other_notes,
                 accompaniment_requested, accompaniment_note, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                family_id,
                caller_user_id,
                allergies,
                medications,
                hospitals,
                other_notes,
                accompaniment_requested,
                accompaniment_note,
                now_iso(),
            ),
        )
        db.commit()
        card_id = db.execute("SELECT last_insert_rowid()").fetchone()[0]
    else:
        card_id = existing["id"]
        db.execute(
            """
            UPDATE family_medical_cards
            SET
                updated_by_user_id = ?,
                allergies = ?,
                medications = ?,
                hospitals = ?,
                other_notes = ?,
                accompaniment_requested = ?,
                accompaniment_note = ?,
                updated_at = ?
            WHERE family_id = ?
            """,
            (
                caller_user_id,
                allergies,
                medications,
                hospitals,
                other_notes,
                accompaniment_requested,
                accompaniment_note,
                now_iso(),
                family_id,
            ),
        )
        db.commit()
    return jsonify({"message": "ok", "id": card_id, "family_id": family_id})


@app.route("/families/<int:family_id>/care-reminders", methods=["GET"])
def list_care_reminders(family_id: int):
    caller_user_id, err = require_auth()
    if err:
        return err
    if not user_in_family(caller_user_id, family_id):
        return jsonify({"error": "forbidden"}), 403
    db = get_db()
    reminders = []

    latest_status = db.execute(
        "SELECT created_at FROM family_status_updates WHERE family_id = ? ORDER BY id DESC LIMIT 1",
        (family_id,),
    ).fetchone()
    if latest_status:
        last = datetime.fromisoformat(latest_status["created_at"])
        idle_days = (datetime.now(timezone.utc) - last).days
        if idle_days >= 3:
            reminders.append(
                {
                    "type": "low_interaction",
                    "title": "Family has been quiet recently",
                    "message": f"No status update in {idle_days} day(s), send a quick check-in.",
                    "severity": "medium",
                }
            )
    else:
        reminders.append(
            {
                "type": "no_status_yet",
                "title": "No check-in status yet",
                "message": "Create your first family status update to start daily connection.",
                "severity": "low",
            }
        )

    today = date.today()
    birthday_rows = db.execute(
        "SELECT birthday, notify_days_before FROM birthday_reminders WHERE family_id = ? AND enabled = 1",
        (family_id,),
    ).fetchall()
    for row in birthday_rows:
        try:
            bday = datetime.strptime(row["birthday"], "%Y-%m-%d").date()
        except ValueError:
            continue
        this_year = date(today.year, bday.month, bday.day)
        if this_year < today:
            this_year = date(today.year + 1, bday.month, bday.day)
        days_left = (this_year - today).days
        if days_left <= int(row["notify_days_before"]):
            reminders.append(
                {
                    "type": "birthday_soon",
                    "title": "Upcoming family birthday",
                    "message": f"A birthday is coming in {days_left} day(s).",
                    "severity": "high" if days_left <= 1 else "medium",
                }
            )

    primary_contacts = db.execute(
        "SELECT COUNT(1) AS c FROM emergency_contacts WHERE family_id = ? AND is_primary = 1",
        (family_id,),
    ).fetchone()
    if int(primary_contacts["c"]) == 0:
        reminders.append(
            {
                "type": "missing_primary_contact",
                "title": "Emergency card incomplete",
                "message": "No primary emergency contact set for this family.",
                "severity": "medium",
            }
        )

    card = db.execute(
        "SELECT accompaniment_requested, COALESCE(accompaniment_note, '') AS note FROM family_medical_cards WHERE family_id = ?",
        (family_id,),
    ).fetchone()
    if card is not None and int(card["accompaniment_requested"]) == 1:
        note = (card["note"] or "").strip()
        reminders.append(
            {
                "type": "accompaniment_requested",
                "title": "Medical accompaniment requested",
                "message": note if note else "A family member requested help to accompany a medical visit.",
                "severity": "high",
            }
        )

    return jsonify(reminders)


with app.app_context():
    init_db()


if __name__ == "__main__":
    app.run(debug=True, port=8000)
