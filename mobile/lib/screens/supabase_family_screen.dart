import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/widgets/cloud_empty_placeholder.dart';
import 'package:family_mobile/screens/supabase_family_detail_screen.dart';
import 'package:family_mobile/supabase/family_repository.dart';
import 'package:family_mobile/supabase/family_row.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/push/care_local_notifications.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SupabaseFamilyScreen extends StatefulWidget {
  const SupabaseFamilyScreen({super.key});

  @override
  State<SupabaseFamilyScreen> createState() => _SupabaseFamilyScreenState();
}

class _SupabaseFamilyScreenState extends State<SupabaseFamilyScreen> {
  final _repo = FamilyRepository();
  final _createController = TextEditingController();
  final _joinController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<FamilyRow> _families = [];
  bool _dailyReminder = false;
  bool _dailyReminderPrefLoaded = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadDailyReminderPref();
  }

  Future<void> _loadDailyReminderPref() async {
    if (kIsWeb) return;
    final v = await CareLocalNotifications.isEnabled();
    final t = await CareLocalNotifications.getReminderTime();
    if (mounted) {
      setState(() {
        _dailyReminder = v;
        _reminderTime = t;
        _dailyReminderPrefLoaded = true;
      });
    }
  }

  Future<void> _pickReminderTime() async {
    if (kIsWeb) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) return;
    await CareLocalNotifications.setReminderTime(hour: picked.hour, minute: picked.minute);
    if (!mounted) return;
    setState(() => _reminderTime = picked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('snack_reminder_time_updated'))),
    );
  }

  Future<void> _setDailyReminder(bool value) async {
    if (kIsWeb) return;
    try {
      await CareLocalNotifications.setEnabled(
        enabled: value,
        title: _t('care_notif_daily_title'),
        body: _t('care_notif_daily_body'),
      );
      if (mounted) setState(() => _dailyReminder = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_generic'))));
      }
    }
  }

  @override
  void dispose() {
    _createController.dispose();
    _joinController.dispose();
    super.dispose();
  }

  String _t(String key) => AppStrings.of(context).text(key);

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listFamilies();
      setState(() => _families = items);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _createController.text.trim();
    if (name.isEmpty) return;
    setState(() => _error = null);
    try {
      await _repo.createFamily(name: name);
      _createController.clear();
      await _refresh();
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    }
  }

  Future<void> _join() async {
    final code = _joinController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = _t('invite_code_required'));
      return;
    }
    setState(() => _error = null);
    try {
      await _repo.joinFamilyByCode(code);
      _joinController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('join_family'))));
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    }
  }

  Future<void> _edit(FamilyRow family) async {
    final controller = TextEditingController(text: family.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final t = AppStrings.of(dialogContext);
        return AlertDialog(
          title: Text(t.text('edit')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: t.text('name')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.text('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(t.text('save')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    setState(() => _error = null);
    try {
      await _repo.updateFamily(id: family.id, name: newName);
      await _refresh();
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    }
  }

  Future<void> _delete(FamilyRow family) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final t = AppStrings.of(dialogContext);
        return AlertDialog(
          title: Text(t.text('delete')),
          content: Text('${family.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t.text('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t.text('delete_confirm'))),
          ],
        );
      },
    );
    if (ok != true) return;
    setState(() => _error = null);
    try {
      await _repo.deleteFamily(family.id);
      await _refresh();
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('cloud_families_title')),
        actions: [
          PopupMenuButton<String?>(
            tooltip: _t('language'),
            icon: const Icon(Icons.language),
            onSelected: (value) => appState.setLocaleCode(value),
            itemBuilder: (context) => [
              PopupMenuItem<String?>(
                value: null,
                child: Text(_t('system_default')),
              ),
              PopupMenuItem<String?>(
                value: 'en',
                child: Text(_t('language_en')),
              ),
              PopupMenuItem<String?>(
                value: 'zh',
                child: Text(_t('language_zh')),
              ),
              PopupMenuItem<String?>(
                value: 'ko',
                child: Text(_t('language_ko')),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => appState.logout(),
              icon: const Icon(Icons.logout),
              label: Text(_t('logout')),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _createController,
              decoration: InputDecoration(
                labelText: _t('new_family_name'),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _create,
              child: Text(_t('create_family')),
            ),
            const SizedBox(height: 20),
            Text(
              _t('invite_code_hint_join'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _joinController,
              decoration: InputDecoration(
                labelText: _t('invite_code'),
              ),
              autocorrect: false,
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loading ? null : _join,
              child: Text(_t('join_family_supabase')),
            ),
            if (!kIsWeb && _dailyReminderPrefLoaded) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_t('care_daily_local_reminder')),
                subtitle: Text(
                  _t('care_daily_local_reminder_subtitle'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
                ),
                value: _dailyReminder,
                onChanged: _setDailyReminder,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(_t('care_daily_reminder_time')),
                subtitle: Text(
                  '${_reminderTime.format(context)} · ${_t('care_daily_reminder_tap_change')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
                ),
                onTap: _pickReminderTime,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ..._families.map(
              (f) => Card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _loading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SupabaseFamilyDetailScreen(family: f),
                                  ),
                                );
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      f.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_t('invite_code')}: ${f.inviteCode}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : () => _edit(f),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: _loading ? null : () => _delete(f),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
            if (!_loading && _families.isEmpty)
              CloudEmptyPlaceholder(
                icon: Icons.groups_outlined,
                title: _t('no_cloud_families'),
                subtitle: _t('cloud_empty_families_hint'),
              ),
          ],
        ),
      ),
    );
  }
}
