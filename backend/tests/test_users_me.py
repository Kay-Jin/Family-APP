def _h(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_get_me(client, user_token_1):
    r = client.get("/users/me", headers=_h(user_token_1))
    assert r.status_code == 200
    data = r.get_json()
    assert data["user_id"] >= 1
    assert "display_name" in data
    assert data.get("supabase_user_id") in (None, "")


def test_patch_me_supabase_user_id(client, user_token_1):
    uid = "11111111-1111-4111-8111-111111111111"
    r = client.patch("/users/me", json={"supabase_user_id": uid}, headers=_h(user_token_1))
    assert r.status_code == 200
    assert r.get_json()["supabase_user_id"] == uid
    r2 = client.get("/users/me", headers=_h(user_token_1))
    assert r2.get_json()["supabase_user_id"] == uid


def test_patch_me_supabase_conflict(client, user_token_1, user_token_2):
    uid = "22222222-2222-4222-8222-222222222222"
    assert client.patch("/users/me", json={"supabase_user_id": uid}, headers=_h(user_token_1)).status_code == 200
    r = client.patch("/users/me", json={"supabase_user_id": uid}, headers=_h(user_token_2))
    assert r.status_code == 409


def test_patch_me_clear_supabase(client, user_token_1):
    uid = "33333333-3333-4333-8333-333333333333"
    assert client.patch("/users/me", json={"supabase_user_id": uid}, headers=_h(user_token_1)).status_code == 200
    r = client.patch("/users/me", json={"supabase_user_id": None}, headers=_h(user_token_1))
    assert r.status_code == 200
    assert r.get_json()["supabase_user_id"] is None
