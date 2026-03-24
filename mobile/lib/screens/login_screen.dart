import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/l10n/app_strings.dart';
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
    final t = AppStrings.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEEE3), Color(0xFFFFF8F4)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFFFFE0D2),
                              child: Icon(Icons.home_rounded, color: Color(0xFF9A4F36)),
                            ),
                            SizedBox(width: 12),
                            Text(
                              t.text('welcome_home'),
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.text('welcome_subtitle'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF6D5A51),
                              ),
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: t.text('display_name'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: t.text('mock_wechat_code'),
                            prefixIcon: const Icon(Icons.verified_user_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: appState.isBusy
                                ? null
                                : () => appState.login(
                                      _codeController.text.trim(),
                                      _nameController.text.trim(),
                                    ),
                            icon: const Icon(Icons.login),
                            label: Text(
                              appState.isBusy ? t.text('signing_in') : t.text('enter_family_app'),
                            ),
                          ),
                        ),
                        if (appState.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            appState.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
