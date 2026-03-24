import 'package:family_mobile/screens/home_screen.dart';
import 'package:family_mobile/screens/login_screen.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const FamilyApp());
}

class FamilyApp extends StatelessWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: MaterialApp(
        title: 'Family App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: Consumer<AppState>(
          builder: (context, appState, _) {
            if (appState.isLoading) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!appState.isLoggedIn) {
              return const LoginScreen();
            }
            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
