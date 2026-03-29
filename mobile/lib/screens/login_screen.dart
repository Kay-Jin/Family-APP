import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/wechat/wechat_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

Future<void> _showWechatCodeDialog(BuildContext context, AppState appState) async {
  final t = AppStrings.of(context);
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(t.text('wechat_supabase_with_code')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: t.text('wechat_oauth_code')),
          autocorrect: false,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.text('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.text('auth_sign_in')),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (code != null && code.isNotEmpty) {
    await appState.signInWithWechatSupabase(code: code);
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(text: 'Dad');
  final _codeController = TextEditingController(text: 'demo_code');
  bool _obscurePassword = true;
  bool _devExpanded = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFFFFE0D2),
                              child: Icon(Icons.home_rounded, color: Color(0xFF9A4F36)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t.text('welcome_home'),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
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
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: t.text('auth_email'),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: t.text('auth_password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: appState.isBusy
                                ? null
                                : () => appState.signInWithEmail(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    ),
                            icon: const Icon(Icons.login),
                            label: Text(
                              appState.isBusy ? t.text('signing_in') : t.text('auth_sign_in'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: appState.isBusy
                                ? null
                                : () => appState.signUpWithEmail(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    ),
                            icon: const Icon(Icons.person_add_outlined),
                            label: Text(t.text('auth_sign_up')),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.cloud_outlined,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.text('login_cloud_hint'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF6D5A51),
                                      height: 1.35,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.text('wechat_need_backend'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6D5A51),
                              ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: appState.isBusy
                                ? null
                                : () => appState.signInWithWechatSupabase(code: 'demo_wechat'),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(t.text('wechat_supabase_demo')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: appState.isBusy ? null : () => _showWechatCodeDialog(context, appState),
                            icon: const Icon(Icons.vpn_key_outlined),
                            label: Text(t.text('wechat_supabase_with_code')),
                          ),
                        ),
                        if (!kIsWeb &&
                            (defaultTargetPlatform == TargetPlatform.android ||
                                defaultTargetPlatform == TargetPlatform.iOS)) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: appState.isBusy || !WechatConfig.isConfigured
                                  ? null
                                  : () => appState.signInWithWechatMobile(),
                              icon: const Icon(Icons.phone_android_outlined),
                              label: Text(
                                t.text(
                                  WechatConfig.isConfigured ? 'wechat_app_login' : 'wechat_app_not_configured',
                                ),
                              ),
                            ),
                          ),
                          if (!WechatConfig.isConfigured)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                t.text('wechat_dart_define_hint'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF6D5A51),
                                    ),
                              ),
                            ),
                        ],
                        if (appState.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            apiErrorMessage(appState.error!, (k) => t.text(k)),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ExpansionTile(
                          title: Text(
                            t.text('dev_local_login'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          initiallyExpanded: _devExpanded,
                          onExpansionChanged: (v) => setState(() => _devExpanded = v),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                  const SizedBox(height: 12),
                                  FilledButton.tonal(
                                    onPressed: appState.isBusy
                                        ? null
                                        : () => appState.login(
                                              _codeController.text.trim(),
                                              _nameController.text.trim(),
                                            ),
                                    child: Text(t.text('enter_family_app')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
