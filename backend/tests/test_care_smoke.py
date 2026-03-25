import io


def _auth_headers(token: str):
    return {"Authorization": f"Bearer {token}"}


def test_status_updates_smoke(client, family_id, user_token_1):
    r = client.get(f"/families/{family_id}/status-updates", headers=_auth_headers(user_token_1))
    assert r.status_code == 200
    assert isinstance(r.get_json(), list)

    r2 = client.post(
        f"/families/{family_id}/status-updates",
        json={"status_code": "home_safe", "note": "ok"},
        headers=_auth_headers(user_token_1),
    )
    assert r2.status_code == 200
    created = r2.get_json()
    assert created["family_id"] == family_id
    assert created["status_code"] == "home_safe"

    r3 = client.get(f"/families/{family_id}/status-updates", headers=_auth_headers(user_token_1))
    assert r3.status_code == 200
    items = r3.get_json()
    assert any(i["id"] == created["id"] for i in items)


def test_emergency_contacts_and_care_reminders_smoke(client, family_id, user_token_1):
    r0 = client.get(f"/families/{family_id}/care-reminders", headers=_auth_headers(user_token_1))
    assert r0.status_code == 200
    reminders0 = r0.get_json()
    assert isinstance(reminders0, list)
    assert any(x.get("type") == "missing_primary_contact" for x in reminders0)

    r1 = client.post(
        f"/families/{family_id}/emergency-contacts",
        json={
            "contact_name": "Alice",
            "relation": "Daughter",
            "phone": "123456",
            "city": "Test City",
            "medical_notes": "N/A",
            "is_primary": True,
        },
        headers=_auth_headers(user_token_1),
    )
    assert r1.status_code == 200

    r2 = client.get(f"/families/{family_id}/emergency-contacts", headers=_auth_headers(user_token_1))
    assert r2.status_code == 200
    contacts = r2.get_json()
    assert isinstance(contacts, list)
    assert any(c.get("is_primary") == 1 for c in contacts)

    r3 = client.get(f"/families/{family_id}/care-reminders", headers=_auth_headers(user_token_1))
    assert r3.status_code == 200
    reminders = r3.get_json()
    assert not any(x.get("type") == "missing_primary_contact" for x in reminders)


def test_medical_card_upsert_and_reminder_smoke(client, family_id, user_token_1):
    r0 = client.get(f"/families/{family_id}/medical-card", headers=_auth_headers(user_token_1))
    assert r0.status_code == 200
    data0 = r0.get_json()
    assert data0["family_id"] == family_id

    r1 = client.put(
        f"/families/{family_id}/medical-card",
        json={
            "allergies": "Penicillin",
            "medications": "Aspirin",
            "hospitals": "City Hospital",
            "other_notes": "N/A",
            "accompaniment_requested": True,
            "accompaniment_note": "Need someone to accompany on Friday.",
        },
        headers=_auth_headers(user_token_1),
    )
    assert r1.status_code == 200

    r2 = client.get(f"/families/{family_id}/medical-card", headers=_auth_headers(user_token_1))
    assert r2.status_code == 200
    data2 = r2.get_json()
    assert data2["allergies"] == "Penicillin"
    assert int(data2["accompaniment_requested"]) == 1

    r3 = client.get(f"/families/{family_id}/care-reminders", headers=_auth_headers(user_token_1))
    assert r3.status_code == 200
    reminders = r3.get_json()
    assert any(x.get("type") == "accompaniment_requested" for x in reminders)


def test_voice_message_create_list_rename_delete_smoke(client, family_id, user_token_1, user_token_2):
    r1 = client.post(
        f"/families/{family_id}/voice-messages",
        json={"title": "Hi", "audio_url": "https://example.com/a.m4a", "duration_seconds": 3},
        headers=_auth_headers(user_token_1),
    )
    assert r1.status_code == 200
    msg = r1.get_json()

    r2 = client.get(f"/families/{family_id}/voice-messages", headers=_auth_headers(user_token_1))
    assert r2.status_code == 200
    assert any(v["id"] == msg["id"] for v in r2.get_json())

    r_forbidden = client.patch(
        f"/voice-messages/{msg['id']}",
        json={"title": "New"},
        headers=_auth_headers(user_token_2),
    )
    assert r_forbidden.status_code == 403

    r3 = client.patch(
        f"/voice-messages/{msg['id']}",
        json={"title": "New"},
        headers=_auth_headers(user_token_1),
    )
    assert r3.status_code == 200

    r4 = client.delete(f"/voice-messages/{msg['id']}", headers=_auth_headers(user_token_1))
    assert r4.status_code == 200


def test_voice_upload_and_delete_removes_file(client, app_module, family_id, user_token_1):
    data = {
        "title": "Upload test",
        "duration_seconds": "2",
        "file": (io.BytesIO(b"FAKEAUDIO"), "voice.m4a"),
    }
    r = client.post(
        f"/families/{family_id}/voice-messages/upload",
        data=data,
        content_type="multipart/form-data",
        headers=_auth_headers(user_token_1),
    )
    assert r.status_code == 200
    msg = r.get_json()
    assert msg["audio_url"].startswith("/uploads/")

    saved_name = msg["audio_url"].replace("/uploads/", "", 1)
    file_path = app_module.UPLOAD_DIR / saved_name
    assert file_path.exists()

    r2 = client.delete(f"/voice-messages/{msg['id']}", headers=_auth_headers(user_token_1))
    assert r2.status_code == 200
    assert not file_path.exists()

