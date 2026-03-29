import 'dart:async';
import 'dart:convert';

import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Child-side flow: three blocks (status, optional contact note, question) with templates.
class FamilyBriefComposeScreen extends StatefulWidget {
  const FamilyBriefComposeScreen({super.key});

  static const draftPrefsKey = 'family_brief_compose_draft_v1';

  @override
  State<FamilyBriefComposeScreen> createState() => _FamilyBriefComposeScreenState();
}

class _FamilyBriefComposeScreenState extends State<FamilyBriefComposeScreen> {
  final _status = TextEditingController();
  final _contact = TextEditingController();
  final _question = TextEditingController();
  bool _parentsOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
  }

  Future<void> _loadDraft() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(FamilyBriefComposeScreen.draftPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _status.text = m['s'] as String? ?? '';
        _contact.text = m['c'] as String? ?? '';
        _question.text = m['q'] as String? ?? '';
        _parentsOnly = m['po'] == true || m['po'] == 1;
      });
    } catch (_) {}
    if (_question.text.isEmpty && mounted) {
      _question.text = AppStrings.of(context).text('brief_tpl_question_default');
    }
  }

  Future<void> _saveDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      FamilyBriefComposeScreen.draftPrefsKey,
      jsonEncode({
        's': _status.text,
        'c': _contact.text,
        'q': _question.text,
        'po': _parentsOnly,
      }),
    );
  }

  Future<void> _clearDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(FamilyBriefComposeScreen.draftPrefsKey);
  }

  @override
  void dispose() {
    unawaited(_saveDraft());
    _status.dispose();
    _contact.dispose();
    _question.dispose();
    super.dispose();
  }

  String _t(String k) => AppStrings.of(context).text(k);

  List<String> _statusTemplates() => [
        _t('brief_tpl_child_busy_1'),
        _t('brief_tpl_child_busy_2'),
        _t('brief_tpl_child_busy_3'),
        _t('brief_tpl_child_joy_1'),
        _t('brief_tpl_child_joy_2'),
        _t('brief_tpl_child_joy_3'),
        _t('brief_tpl_child_care_1'),
        _t('brief_tpl_child_care_2'),
        _t('brief_tpl_child_care_3'),
      ];

  List<String> _contactTemplates() => [
        _t('brief_tpl_contact_1'),
        _t('brief_tpl_contact_2'),
        _t('brief_tpl_contact_3'),
      ];

  Future<void> _submit(AppState app) async {
    final s = _status.text.trim();
    final q = _question.text.trim();
    if (s.isEmpty || q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('brief_fields_required'))),
      );
      return;
    }
    final c = _contact.text.trim();
    await app.sendFamilyBrief(
      childStatusText: s,
      contactNote: c.isEmpty ? null : c,
      questionText: q,
      parentsOnly: _parentsOnly,
    );
    if (!mounted) return;
    if (app.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(app.error!, (k) => _t(k)))),
      );
      return;
    }
    await _clearDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('brief_sent_ok'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('brief_compose_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _t('brief_visibility_note'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('brief_parents_only_title')),
            subtitle: Text(
              _t('brief_parents_only_subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _parentsOnly,
            onChanged: (v) {
              setState(() => _parentsOnly = v);
              unawaited(_saveDraft());
            },
          ),
          const SizedBox(height: 8),
          Text(_t('brief_section_status'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(_t('brief_pick_template'), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _statusTemplates().map((line) {
              return ActionChip(
                label: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
                onPressed: () {
                  setState(() => _status.text = line);
                  unawaited(_saveDraft());
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _status,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _t('brief_section_status'),
            ),
            onChanged: (_) => unawaited(_saveDraft()),
          ),
          const SizedBox(height: 20),
          Text(_t('brief_section_contact'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _contactTemplates().map((line) {
              return ActionChip(
                label: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
                onPressed: () {
                  setState(() => _contact.text = line);
                  unawaited(_saveDraft());
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contact,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _t('note_optional'),
            ),
            onChanged: (_) => unawaited(_saveDraft()),
          ),
          const SizedBox(height: 20),
          Text(_t('brief_section_question'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _question,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => unawaited(_saveDraft()),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: app.isBusy ? null : () => _submit(app),
            icon: const Icon(Icons.send_rounded),
            label: Text(_t('brief_send')),
          ),
        ],
      ),
    );
  }
}
