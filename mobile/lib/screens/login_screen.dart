import 'package:family_mobile/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController(text: 'Dad');
  final _codeController = TextEditingController(text: 'demo_code');

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Family App Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Mock WeChat Code'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: appState.isBusy
                  ? null
                  : () => appState.login(_codeController.text.trim(), _nameController.text.trim()),
              child: const Text('Login'),
            ),
            if (appState.error != null) ...[
              const SizedBox(height: 12),
              Text(appState.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
