import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const BoxyingMobileApp(),
    ),
  );
}

class BoxyingMobileApp extends ConsumerWidget {
  const BoxyingMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return MaterialApp(
      title: brand.appTitle,
      debugShowCheckedModeBanner: false,
      theme: brand.theme,
      home: const LoginScreen(),
    );
  }
}
