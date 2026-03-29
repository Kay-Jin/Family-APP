import 'dart:io';

import 'package:family_mobile/care/care_nudge_evaluator.dart';
import 'package:family_mobile/care/quick_status_code.dart';
import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/screens/companion_room_screen.dart';
import 'package:family_mobile/supabase/care_cloud_repository.dart';
import 'package:family_mobile/supabase/cloud_family_birthday_reminder.dart';
import 'package:family_mobile/supabase/cloud_family_status_post.dart';
import 'package:family_mobile/supabase/cloud_family_voice_message.dart';
import 'package:family_mobile/supabase/cloud_medical_card.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/util/date_time_display.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseFamilyCarePanel extends StatefulWidget {
  const SupabaseFamilyCarePanel({super.key, required this.familyId});

  final String familyId;

  @override
  State<SupabaseFamilyCarePanel> createState() => _SupabaseFamilyCarePanelState();
}

class _SupabaseFamilyCarePanelState extends State<SupabaseFamilyCarePanel> {
  final _repo = CareCloudRepository();
  final _statusNote = TextEditingController();
  final _voiceTitle = TextEditingController();
  final _bdName = TextEditingController();
  final _bdMonth = TextEditingController();
  final _bdDay = TextEditingController();
  final _mdName = TextEditingController();
  final _mdAllergies = TextEditingController();
  final _mdMeds = TextEditingController();
  final _mdHospitals = TextEditingController();
  final _mdEmergName = TextEditingController();
  final _mdEmergPhone = TextEditingController();
  final _mdAccompany = TextEditingController();

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  List<CloudFamilyStatusPost> _posts = [];
  List<CloudFamilyVoiceMessage> _voices = [];
  final Map<String, String> _voiceUrlByPath = {};
  List<CloudMedicalCard> _allMedical = [];
  List<CloudFamilyBirthdayReminder> _birthdays = [];
  List<CareNudge> _nudges = [];

  bool _loading = true;
  String? _error;
  bool _busy = false;

  bool _gentleRadar = false;
  bool _sharePresence = false;
  Map<String, DateTime> _presence = {};

  bool _preferWarmUi = true;
  bool _largeText = false;

  bool _recording = false;
  DateTime? _recordStarted;
  String? _pendingVoicePath;
  int _pendingVoiceSeconds = 0;
  String? _playingVoiceId;

  static const _prefWarm = 'cloud_care_ui_warm_v1';
  static const _prefLarge = 'cloud_care_ui_large_v1';

  String _t(String key) => AppStrings.of(context).text(key);

  String _nudgeText(CareNudge n) {
    var s = _t(n.messageKey);
    n.params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  List<Widget> _buildPresenceRows(TextStyle scaled) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final rows = _presence.entries.where((e) => e.key != uid).toList();
    if (rows.isEmpty) {
      return [Text(_t('no_activity'), style: scaled.copyWith(color: const Color(0xFF6D5A51)))];
    }
    return rows
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${e.key.substring(0, 8)}… · ${formatIsoDateTimeLocal(context, e.value.toIso8601String())}',
              style: scaled.copyWith(fontSize: (scaled.fontSize ?? 14) * 0.9),
            ),
          ),
        )
        .toList();
  }

  double get _scale => _largeText ? 1.15 : 1.0;

  @override
  void initState() {
    super.initState();
    _loadLocalUiPrefs();
    _refresh();
  }

  Future<void> _loadLocalUiPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _preferWarmUi = p.getBool(_prefWarm) ?? true;
      _largeText = p.getBool(_prefLarge) ?? false;
    });
  }

  Future<void> _setWarmUi(bool warm) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefWarm, warm);
    if (mounted) setState(() => _preferWarmUi = warm);
  }

  Future<void> _setLargeText(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefLarge, v);
    if (mounted) setState(() => _largeText = v);
  }

  @override
  void dispose() {
    _statusNote.dispose();
    _voiceTitle.dispose();
    _bdName.dispose();
    _bdMonth.dispose();
    _bdDay.dispose();
    _mdName.dispose();
    _mdAllergies.dispose();
    _mdMeds.dispose();
    _mdHospitals.dispose();
    _mdEmergName.dispose();
    _mdEmergPhone.dispose();
    _mdAccompany.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.touchCarePresence(widget.familyId);
      final user = Supabase.instance.client.auth.currentUser;
      final posts = await _repo.listStatusPosts(widget.familyId);
      final voices = await _repo.listVoiceMessages(widget.familyId);
      final medical = await _repo.listMedicalCardsForFamily(widget.familyId);
      final birthdays = await _repo.listBirthdayReminders(widget.familyId);
      final prefs = await _repo.getMyCarePreferences(widget.familyId);
      final presence = await _repo.listCarePresenceForFamily(widget.familyId);
      final lastS = await _repo.lastStatusPostAt(widget.familyId);
      final lastA = await _repo.lastAnswerInFamily(widget.familyId);
      final mood = await _repo.recentFamilyContentHasMoodKeyword(widget.familyId);

      final signed = <String, String>{};
      for (final v in voices) {
        try {
          signed[v.storagePath] = await _repo.signedVoiceUrl(v.storagePath);
        } catch (_) {}
      }

      CloudMedicalCard? mine;
      if (user != null) {
        for (final c in medical) {
          if (c.userId == user.id) {
            mine = c;
            break;
          }
        }
      }

      final nudges = CareNudgeEvaluator.evaluate(
        now: DateTime.now(),
        lastStatusAt: lastS,
        lastAnswerAt: lastA,
        birthdays: birthdays,
        moodKeywordInRecentContent: mood,
        gentleRadarEnabled: prefs.gentleRadar,
        currentUserId: user?.id,
        otherMembersCarePresence: presence,
      );

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _voices = voices;
        _voiceUrlByPath
          ..clear()
          ..addAll(signed);
        _allMedical = medical;
        _birthdays = birthdays;
        _nudges = nudges;
        _gentleRadar = prefs.gentleRadar;
        _sharePresence = prefs.sharePresence;
        _presence = presence;
        if (mine != null) {
          _mdName.text = mine.displayName ?? '';
          _mdAllergies.text = mine.allergies ?? '';
          _mdMeds.text = mine.medications ?? '';
          _mdHospitals.text = mine.hospitals ?? '';
          _mdEmergName.text = mine.emergencyContactName ?? '';
          _mdEmergPhone.text = mine.emergencyContactPhone ?? '';
          _mdAccompany.text = mine.accompanimentNote ?? '';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postStatus(String code) async {
    setState(() => _busy = true);
    try {
      await _repo.postQuickStatus(
        familyId: widget.familyId,
        statusCode: code,
        note: _statusNote.text,
      );
      _statusNote.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('snack_status_published'))));
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistCarePrefs({required bool gentle, required bool share}) async {
    setState(() => _busy = true);
    try {
      await _repo.saveMyCarePreferences(
        familyId: widget.familyId,
        gentleRadarEnabled: gentle,
        shareCarePresence: share,
      );
      if (mounted) {
        setState(() {
          _gentleRadar = gentle;
          _sharePresence = share;
        });
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveMedical() async {
    setState(() => _busy = true);
    try {
      await _repo.upsertMyMedicalCard(
        familyId: widget.familyId,
        displayName: _mdName.text,
        allergies: _mdAllergies.text,
        medications: _mdMeds.text,
        hospitals: _mdHospitals.text,
        emergencyContactName: _mdEmergName.text,
        emergencyContactPhone: _mdEmergPhone.text,
        accompanimentNote: _mdAccompany.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('save_medical_card'))));
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addBirthday() async {
    final name = _bdName.text.trim();
    final m = int.tryParse(_bdMonth.text.trim());
    final d = int.tryParse(_bdDay.text.trim());
    if (name.isEmpty || m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_generic'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.addBirthdayReminder(familyId: widget.familyId, personName: name, month: m, day: d);
      _bdName.clear();
      _bdMonth.clear();
      _bdDay.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBirthday(CloudFamilyBirthdayReminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('delete_reminder')),
        content: Text(_t('delete_birthday_cloud_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('delete_confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteBirthdayReminder(r.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    }
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('voice_recording_not_web'))));
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('microphone_permission_denied'))));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/care_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordStarted = DateTime.now();
      _pendingVoicePath = null;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    final started = _recordStarted;
    final sec = started == null ? 0 : DateTime.now().difference(started).inSeconds;
    setState(() {
      _recording = false;
      _recordStarted = null;
      _pendingVoicePath = path;
      _pendingVoiceSeconds = sec < 0 ? 0 : sec;
    });
  }

  Future<void> _uploadVoice() async {
    final title = _voiceTitle.text.trim();
    final path = _pendingVoicePath;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('voice_title_required'))));
      return;
    }
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('record_audio_first'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await File(path).readAsBytes();
      await _repo.uploadVoiceMessage(
        familyId: widget.familyId,
        title: title,
        audioBytes: bytes,
        fileExtension: 'm4a',
        durationSeconds: _pendingVoiceSeconds,
      );
      _voiceTitle.clear();
      _pendingVoicePath = null;
      _pendingVoiceSeconds = 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('voice_uploaded'))));
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _playVoice(CloudFamilyVoiceMessage v) async {
    final url = _voiceUrlByPath[v.storagePath];
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('unable_play_voice'))));
      return;
    }
    try {
      if (_playingVoiceId == v.id && _player.playing) {
        await _player.pause();
        setState(() => _playingVoiceId = null);
        return;
      }
      await _player.setUrl(url);
      await _player.play();
      setState(() => _playingVoiceId = v.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('unable_play_voice'))));
      }
    }
  }

  Future<void> _deleteVoice(CloudFamilyVoiceMessage v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('delete_voice')),
        content: Text(_t('delete_voice_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('delete_confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteVoiceMessage(v.id, v.storagePath);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _preferWarmUi ? const Color(0xFFE6866A) : const Color(0xFF5C7A89);
    final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    final scaled = baseStyle.fontSize != null
        ? baseStyle.copyWith(fontSize: baseStyle.fontSize! * _scale)
        : baseStyle;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(_t('smart_care_reminders'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_nudges.isEmpty)
            Text(_t('no_care_reminders'), style: scaled)
          else
            ..._nudges.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_nudgeText(n), style: scaled),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: true, label: Text(_t('care_mode_warm'))),
                    ButtonSegment(value: false, label: Text(_t('care_mode_calm'))),
                  ],
                  selected: {_preferWarmUi},
                  onSelectionChanged: (s) => _setWarmUi(s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('care_large_text'), style: scaled),
            value: _largeText,
            onChanged: _setLargeText,
          ),
          const SizedBox(height: 12),
          Text(_t('family_status_card'), style: theme.textTheme.titleMedium?.copyWith(fontSize: 18 * _scale)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuickStatusCode.all
                .map(
                  (code) => FilledButton.tonal(
                    onPressed: _busy ? null : () => _postStatus(code),
                    child: Text(_t(QuickStatusCode.l10nKeyFor(code)), style: TextStyle(fontSize: 15 * _scale)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _statusNote,
            decoration: InputDecoration(labelText: _t('note_optional')),
            maxLines: 2,
            style: scaled,
          ),
          const SizedBox(height: 16),
          Text(_t('care_recent_status'), style: theme.textTheme.titleSmall?.copyWith(fontSize: 16 * _scale)),
          const SizedBox(height: 6),
          if (!_loading && _posts.isEmpty)
            Text(_t('care_no_status_yet'), style: scaled.copyWith(color: const Color(0xFF6D5A51)))
          else
            ..._posts.take(12).map((p) => _statusTile(p, scaled)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('voice_mailbox'), style: theme.textTheme.titleMedium),
              Text(_t('voice_permission_copy'), style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(_t('cloud_care_voice_hint'), style: scaled.copyWith(color: const Color(0xFF6D5A51))),
          const SizedBox(height: 8),
          if (!kIsWeb) ...[
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : (_recording ? _stopRecording : _startRecording),
                  child: Text(_recording ? _t('stop_recording') : _t('start_recording')),
                ),
                const SizedBox(width: 12),
                if (_pendingVoicePath != null)
                  Expanded(
                    child: Text(
                      '${_t('duration_seconds_manual')}: $_pendingVoiceSeconds',
                      style: scaled,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _voiceTitle,
              decoration: InputDecoration(labelText: _t('title'), hintText: _t('voice_title_placeholder')),
              style: scaled,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _uploadVoice,
              child: Text(_t('upload_recorded_voice')),
            ),
          ] else
            Text(_t('voice_recording_not_web'), style: scaled),
          const SizedBox(height: 12),
          ..._voices.map((v) => _voiceTile(v, scaled)),
          const SizedBox(height: 20),
          Text(_t('medical_card_mine'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _mdName, decoration: InputDecoration(labelText: _t('name')), style: scaled),
          TextField(controller: _mdAllergies, decoration: InputDecoration(labelText: _t('allergies')), style: scaled),
          TextField(controller: _mdMeds, decoration: InputDecoration(labelText: _t('common_medications')), style: scaled),
          TextField(controller: _mdHospitals, decoration: InputDecoration(labelText: _t('common_hospitals')), style: scaled),
          TextField(
            controller: _mdEmergName,
            decoration: InputDecoration(labelText: _t('emergency_contact_card')),
            style: scaled,
          ),
          TextField(controller: _mdEmergPhone, decoration: InputDecoration(labelText: _t('phone')), style: scaled),
          TextField(
            controller: _mdAccompany,
            decoration: InputDecoration(labelText: _t('accompaniment_note')),
            maxLines: 2,
            style: scaled,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _saveMedical,
            child: Text(_t('save_medical_card')),
          ),
          const SizedBox(height: 16),
          Text(_t('care_family_medical_summary'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          ..._allMedical.map((c) => ListTile(
                dense: true,
                title: Text(c.displayName ?? c.userId.substring(0, 8)),
                subtitle: Text(
                  [
                    if ((c.allergies ?? '').isNotEmpty) '${_t('allergies')}: ${c.allergies}',
                    if ((c.emergencyContactPhone ?? '').isNotEmpty) '${_t('phone')}: ${c.emergencyContactPhone}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
          const SizedBox(height: 16),
          Text(_t('birthdays'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(controller: _bdName, decoration: InputDecoration(labelText: _t('person_name')), style: scaled),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bdMonth,
                  decoration: InputDecoration(labelText: _t('birthday_month')),
                  keyboardType: TextInputType.number,
                  style: scaled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _bdDay,
                  decoration: InputDecoration(labelText: _t('birthday_day')),
                  keyboardType: TextInputType.number,
                  style: scaled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : _addBirthday, child: Text(_t('add_cloud_birthday'))),
          ..._birthdays.map(
            (r) => ListTile(
              title: Text(r.personName),
              subtitle: Text('${r.month}/${r.day}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteBirthday(r),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(_t('care_radar_title'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(_t('care_radar_body'), style: scaled.copyWith(color: const Color(0xFF6D5A51), height: 1.35)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('care_radar_gentle'), style: scaled),
            value: _gentleRadar,
            onChanged: _busy
                ? null
                : (v) => _persistCarePrefs(gentle: v, share: _sharePresence),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('care_share_presence'), style: scaled),
            value: _sharePresence,
            onChanged: _busy
                ? null
                : (v) => _persistCarePrefs(gentle: _gentleRadar, share: v),
          ),
          Text(_t('care_presence_legend'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          ..._buildPresenceRows(scaled),
          const SizedBox(height: 20),
          Text(_t('companion_room_title'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CompanionRoomScreen()),
              );
            },
            icon: const Icon(Icons.timer_outlined),
            label: Text(_t('open_companion_room')),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _statusTile(CloudFamilyStatusPost p, TextStyle scaled) {
    final who = p.authorDisplayName ?? p.userId.substring(0, 8);
    final label = _t(QuickStatusCode.l10nKeyFor(p.statusCode));
    final note = (p.note ?? '').trim();
    return ListTile(
      dense: true,
      title: Text('$who · $label', style: scaled),
      subtitle: note.isNotEmpty ? Text(note, style: scaled) : null,
      trailing: Text(
        formatIsoDateTimeLocal(context, p.createdAt.toIso8601String()),
        style: scaled.copyWith(fontSize: (scaled.fontSize ?? 14) * 0.85, color: const Color(0xFF6D5A51)),
      ),
    );
  }

  Widget _voiceTile(CloudFamilyVoiceMessage v, TextStyle scaled) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final own = uid != null && v.userId == uid;
    return ListTile(
      title: Text(v.title, style: scaled),
      subtitle: Text(v.authorDisplayName ?? v.userId, style: scaled),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_playingVoiceId == v.id ? Icons.pause_circle_outline : Icons.play_circle_outline),
            onPressed: () => _playVoice(v),
          ),
          if (own)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteVoice(v),
            ),
        ],
      ),
    );
  }
}
