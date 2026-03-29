def test_notification_snippet_collapses_whitespace(app_module):
    assert app_module._notification_snippet("hello\n  world") == "hello world"


def test_notification_snippet_truncates(app_module):
    s = app_module._notification_snippet("a" * 200, max_len=20)
    assert len(s) == 20
    assert s.endswith("…")
