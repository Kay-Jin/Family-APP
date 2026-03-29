import pytest


def _auth(token: str):
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def user_token_3(client):
    r = client.post("/auth/wechat-login", json={"code": "u3", "display_name": "User 3"})
    assert r.status_code == 200
    return r.get_json()["token"]


@pytest.fixture()
def family_three(client, user_token_1, user_token_2, user_token_3):
    r = client.post("/families", json={"name": "Brief V11"}, headers=_auth(user_token_1))
    assert r.status_code == 200
    data = r.get_json()
    fid = data["id"]
    invite = data["invite_code"]
    r2 = client.post("/families/join", json={"invite_code": invite}, headers=_auth(user_token_2))
    assert r2.status_code == 200
    r3 = client.post("/families/join", json={"invite_code": invite}, headers=_auth(user_token_3))
    assert r3.status_code == 200
    return fid


def test_get_family_includes_role_flags(client, family_id, user_token_1):
    r = client.get(f"/families/{family_id}", headers=_auth(user_token_1))
    assert r.status_code == 200
    j = r.get_json()
    assert j["my_role"] == "owner"
    assert j["family_has_parent_role"] is False


def test_patch_my_role_and_parent_flag(client, family_id, user_token_1, user_token_2):
    r = client.patch(
        f"/families/{family_id}/members/me",
        json={"role": "parent"},
        headers=_auth(user_token_1),
    )
    assert r.status_code == 200
    assert r.get_json()["role"] == "parent"

    r2 = client.get(f"/families/{family_id}", headers=_auth(user_token_2))
    assert r2.status_code == 200
    assert r2.get_json()["family_has_parent_role"] is True
    assert r2.get_json()["my_role"] == "member"


def test_parents_only_hidden_from_non_parent(client, family_three, user_token_1, user_token_2, user_token_3):
    fid = family_three
    client.patch(f"/families/{fid}/members/me", json={"role": "parent"}, headers=_auth(user_token_1))
    client.patch(f"/families/{fid}/members/me", json={"role": "child"}, headers=_auth(user_token_2))

    cr = client.post(
        f"/families/{fid}/family-briefs",
        json={
            "child_status_text": "ok",
            "question_text": "hi?",
            "parents_only": True,
        },
        headers=_auth(user_token_2),
    )
    assert cr.status_code == 200
    bid = cr.get_json()["id"]

    r_member = client.get(f"/families/{fid}/family-briefs/pending-list", headers=_auth(user_token_3))
    assert r_member.status_code == 200
    assert r_member.get_json()["briefs"] == []

    r_parent = client.get(f"/families/{fid}/family-briefs/pending-list", headers=_auth(user_token_1))
    assert r_parent.status_code == 200
    ids = [b["id"] for b in r_parent.get_json()["briefs"]]
    assert bid in ids

    r403 = client.get(f"/family-briefs/{bid}", headers=_auth(user_token_3))
    assert r403.status_code == 403


def test_parents_only_visible_after_reply(client, family_three, user_token_1, user_token_2, user_token_3):
    fid = family_three
    client.patch(f"/families/{fid}/members/me", json={"role": "parent"}, headers=_auth(user_token_1))
    client.patch(f"/families/{fid}/members/me", json={"role": "child"}, headers=_auth(user_token_2))

    cr = client.post(
        f"/families/{fid}/family-briefs",
        json={
            "child_status_text": "ok",
            "question_text": "q",
            "parents_only": True,
        },
        headers=_auth(user_token_2),
    )
    bid = cr.get_json()["id"]

    rep = client.post(
        f"/family-briefs/{bid}/replies",
        json={"reply_kind": "quick", "quick_text": "here"},
        headers=_auth(user_token_1),
    )
    assert rep.status_code == 200

    r_ok = client.get(f"/family-briefs/{bid}", headers=_auth(user_token_3))
    assert r_ok.status_code == 200
    assert r_ok.get_json()["parents_only"] is True


def test_only_parent_can_reply_when_parent_role_exists(
    client, family_three, user_token_1, user_token_2, user_token_3
):
    fid = family_three
    client.patch(f"/families/{fid}/members/me", json={"role": "parent"}, headers=_auth(user_token_1))

    cr = client.post(
        f"/families/{fid}/family-briefs",
        json={"child_status_text": "x", "question_text": "y", "parents_only": False},
        headers=_auth(user_token_2),
    )
    bid = cr.get_json()["id"]

    r_child = client.post(
        f"/family-briefs/{bid}/replies",
        json={"reply_kind": "quick", "quick_text": "nope"},
        headers=_auth(user_token_3),
    )
    assert r_child.status_code == 403

    r_parent = client.post(
        f"/family-briefs/{bid}/replies",
        json={"reply_kind": "quick", "quick_text": "yes"},
        headers=_auth(user_token_1),
    )
    assert r_parent.status_code == 200


def test_member_can_reply_when_no_parent_role(client, family_id, user_token_1, user_token_2):
    cr = client.post(
        f"/families/{family_id}/family-briefs",
        json={"child_status_text": "x", "question_text": "y"},
        headers=_auth(user_token_1),
    )
    bid = cr.get_json()["id"]

    r2 = client.post(
        f"/family-briefs/{bid}/replies",
        json={"reply_kind": "quick", "quick_text": "from member"},
        headers=_auth(user_token_2),
    )
    assert r2.status_code == 200
