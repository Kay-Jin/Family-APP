import 'package:family_mobile/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _familyNameController = TextEditingController(text: 'Happy Family');
  final _inviteCodeController = TextEditingController();
  final _questionDateController = TextEditingController(text: '2026-03-24');
  final _questionTextController = TextEditingController(text: 'Today what made you smile?');
  final _photoUrlController = TextEditingController(text: 'https://example.com/photo.jpg');
  final _photoCaptionController = TextEditingController(text: 'Family dinner');
  final _birthdayController = TextEditingController(text: '1990-08-15');
  final _notifyDaysController = TextEditingController(text: '1');

  @override
  void dispose() {
    _familyNameController.dispose();
    _inviteCodeController.dispose();
    _questionDateController.dispose();
    _questionTextController.dispose();
    _photoUrlController.dispose();
    _photoCaptionController.dispose();
    _birthdayController.dispose();
    _notifyDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final family = appState.family;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Home'),
        actions: [
          IconButton(
            onPressed: appState.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.refreshHomeData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (family == null) ...[
              TextField(
                controller: _familyNameController,
                decoration: const InputDecoration(labelText: 'New Family Name'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: appState.isBusy ? null : () => appState.createFamily(_familyNameController.text.trim()),
                child: const Text('Create Family'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inviteCodeController,
                decoration: const InputDecoration(labelText: 'Invite Code'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: appState.isBusy ? null : () => appState.joinFamily(_inviteCodeController.text.trim()),
                child: const Text('Join Family'),
              ),
            ] else ...[
              Card(
                child: ListTile(
                  title: Text(family.name),
                  subtitle: Text('Invite Code: ${family.inviteCode}'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: appState.isBusy ? null : appState.refreshHomeData,
                child: const Text('Refresh Family Data'),
              ),
              const SizedBox(height: 16),
              Text(
                'Create Daily Question',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _questionDateController,
                decoration: const InputDecoration(labelText: 'Question Date (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _questionTextController,
                decoration: const InputDecoration(labelText: 'Question Text'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: appState.isBusy
                    ? null
                    : () => appState.addDailyQuestion(
                          questionDate: _questionDateController.text.trim(),
                          questionText: _questionTextController.text.trim(),
                        ),
                child: const Text('Add Question'),
              ),
              const SizedBox(height: 16),
              Text(
                'Daily Questions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (appState.dailyQuestions.isEmpty)
                const Text('No questions yet')
              else
                ...appState.dailyQuestions.map(
                  (q) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(q.questionText),
                    subtitle: Text(q.questionDate),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Add Photo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _photoUrlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _photoCaptionController,
                decoration: const InputDecoration(labelText: 'Caption'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: appState.isBusy
                    ? null
                    : () => appState.addPhoto(
                          imageUrl: _photoUrlController.text.trim(),
                          caption: _photoCaptionController.text.trim(),
                        ),
                child: const Text('Add Photo'),
              ),
              const SizedBox(height: 16),
              Text(
                'Photos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (appState.photos.isEmpty)
                const Text('No photos yet')
              else
                ...appState.photos.map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.caption.isEmpty ? 'Photo #${p.id}' : p.caption),
                    subtitle: Text(p.imageUrl),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Birthday Reminders',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _birthdayController,
                decoration: const InputDecoration(labelText: 'Birthday (YYYY-MM-DD)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notifyDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Notify Days Before'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: appState.isBusy
                    ? null
                    : () => appState.addBirthdayReminder(
                          birthday: _birthdayController.text.trim(),
                          notifyDaysBefore: int.tryParse(_notifyDaysController.text.trim()) ?? 1,
                        ),
                child: const Text('Add Birthday Reminder'),
              ),
              const SizedBox(height: 8),
              if (appState.birthdayReminders.isEmpty)
                const Text('No reminders yet')
              else
                ...appState.birthdayReminders.map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.birthday),
                    subtitle: Text('Notify ${r.notifyDaysBefore} day(s) before'),
                  ),
                ),
            ],
            if (appState.error != null) ...[
              const SizedBox(height: 16),
              Text(appState.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
