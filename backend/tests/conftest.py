import importlib

import pytest


@pytest.fixture()
def app_module(tmp_path, monkeypatch):
    """
    Provide a backend app module wired to an isolated temp DB + uploads dir.

    Note: backend/app.py initializes a default DB at import time. For tests we
    re-point DB_PATH/UPLOAD_DIR and run init_db() again under app_context.
    """
    m = importlib.import_module("app")

    test_db = tmp_path / "test_family_app.db"
    test_uploads = tmp_path / "uploads"
    test_uploads.mkdir(exist_ok=True)

    monkeypatch.setattr(m, "DB_PATH", test_db)
    monkeypatch.setattr(m, "UPLOAD_DIR", test_uploads)

    with m.app.app_context():
        m.init_db()

    return m


@pytest.fixture()
def client(app_module):
    return app_module.app.test_client()


def _auth_headers(token: str):
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def user_token_1(client):
    r = client.post("/auth/wechat-login", json={"code": "u1", "display_name": "User 1"})
    assert r.status_code == 200
    return r.get_json()["token"]


@pytest.fixture()
def user_token_2(client):
    r = client.post("/auth/wechat-login", json={"code": "u2", "display_name": "User 2"})
    assert r.status_code == 200
    return r.get_json()["token"]


@pytest.fixture()
def family_id(client, user_token_1, user_token_2):
    r = client.post("/families", json={"name": "Test Family"}, headers=_auth_headers(user_token_1))
    assert r.status_code == 200
    data = r.get_json()
    fid = data["id"]
    invite = data["invite_code"]

    r2 = client.post("/families/join", json={"invite_code": invite}, headers=_auth_headers(user_token_2))
    assert r2.status_code == 200

    return fid

