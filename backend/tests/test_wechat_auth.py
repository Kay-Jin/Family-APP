def test_wechat_login_requires_code(client):
    r = client.post("/auth/wechat-login", json={})
    assert r.status_code == 400


def test_wechat_login_demo_code(client):
    r = client.post("/auth/wechat-login", json={"code": "demo_wechat", "display_name": "Demo"})
    assert r.status_code == 200
    data = r.get_json()
    assert "token" in data
    assert data.get("union_id") == "demo_wechat_union"


def test_pytest_synthetic_union_stable(client):
    """u1 / u2 fixtures rely on deterministic unions when PYTEST_CURRENT_TEST is set."""
    r1 = client.post("/auth/wechat-login", json={"code": "u1"})
    r2 = client.post("/auth/wechat-login", json={"code": "u1"})
    assert r1.status_code == 200 and r2.status_code == 200
    assert r1.get_json()["union_id"] == r2.get_json()["union_id"]
