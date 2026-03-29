import fcm_dispatch


def test_dispatch_skips_without_env(monkeypatch):
    monkeypatch.delenv("PUSH_DISPATCH_SECRET", raising=False)
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_FUNCTIONS_URL", raising=False)
    assert (
        fcm_dispatch.dispatch_fcm_to_users(
            ["00000000-0000-4000-8000-000000000001"],
            "t",
            "b",
        )
        is None
    )


def test_dispatch_skips_empty_user_list(monkeypatch):
    monkeypatch.setenv("PUSH_DISPATCH_SECRET", "x")
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    assert fcm_dispatch.dispatch_fcm_to_users([], "t", "b") is None
