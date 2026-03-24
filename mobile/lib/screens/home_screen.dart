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

  @override
  void dispose() {
    _familyNameController.dispose();
    _inviteCodeController.dispose();
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
