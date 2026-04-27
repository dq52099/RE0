import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../materializer/materializer_screen.dart';
import '../chronogear/chronogear_screen.dart';
import '../compendium/compendium_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  int _historyRefreshToken = 0;
  int _profileRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final screens = [
      const MaterializerScreen(),
      const ChronogearScreen(),
      CompendiumScreen(refreshToken: _historyRefreshToken),
      ProfileScreen(refreshToken: _profileRefreshToken),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 2) {
              _historyRefreshToken += 1;
            }
            if (index == 3) {
              _profileRefreshToken += 1;
            }
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: brand.primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.auto_fix_high),
            label: brand.generateTabLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.loop),
            label: brand.editTabLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: brand.historyTabLabel,
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
