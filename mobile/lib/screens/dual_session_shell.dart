import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/screens/home_screen.dart';
import 'package:family_mobile/screens/supabase_family_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the user is signed in to both the local Flask API and Supabase, show one app with two roots.
class DualSessionShell extends StatefulWidget {
  const DualSessionShell({super.key});

  @override
  State<DualSessionShell> createState() => _DualSessionShellState();
}

class _DualSessionShellState extends State<DualSessionShell> {
  static const _cloudTipPrefsKey = 'dual_shell_cloud_tip_shown_v1';

  int _index = 0;

  String _t(String key) => AppStrings.of(context).text(key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCloudTip());
  }

  Future<void> _maybeShowCloudTip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cloudTipPrefsKey) == true || !mounted) return;
    await prefs.setBool(_cloudTipPrefsKey, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('shell_cloud_tip')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          SupabaseFamilyScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: _t('tab_local_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.cloud_outlined),
            selectedIcon: const Icon(Icons.cloud_rounded),
            label: _t('tab_cloud_families'),
          ),
        ],
      ),
    );
  }
}
