import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/screens/home_screen.dart';
import 'package:family_mobile/screens/supabase_family_screen.dart';
import 'package:flutter/material.dart';

/// When the user is signed in to both the local Flask API and Supabase, show one app with two roots.
class DualSessionShell extends StatefulWidget {
  const DualSessionShell({super.key});

  @override
  State<DualSessionShell> createState() => _DualSessionShellState();
}

class _DualSessionShellState extends State<DualSessionShell> {
  int _index = 0;

  String _t(String key) => AppStrings.of(context).text(key);

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
