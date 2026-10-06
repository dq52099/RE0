import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gallery/gallery_screen.dart';
import '../materializer/materializer_screen.dart';
import '../chronogear/chronogear_screen.dart';
import '../compendium/compendium_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/providers.dart';
import '../../core/app_motion.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  int _galleryRefreshToken = 0;
  int _historyRefreshToken = 0;
  int _profileRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        ref.invalidate(imageRequestResumeProvider);
        ref.read(imageRequestResumeProvider.future);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(imageCapabilitiesProvider);
      if (ref.read(activeImageTaskProvider) == null) {
        ref.invalidate(imageRequestResumeProvider);
        ref.read(imageRequestResumeProvider.future);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    ref.listen<Map<String, dynamic>?>(authStateProvider, (previous, next) {
      if (next != null) {
        final previousMode = previous?['image_mode']?.toString();
        final nextMode = next['image_mode']?.toString();
        final previousEffectiveMode =
            previous?['effective_image_mode']?.toString();
        final nextEffectiveMode = next['effective_image_mode']?.toString();
        if (previous == null ||
            previousMode != nextMode ||
            previousEffectiveMode != nextEffectiveMode) {
          ref.read(selectedImageModeProvider.notifier).state = null;
          ref.read(selectedImageModeBaseProvider.notifier).state = null;
          ref.invalidate(imageCapabilitiesProvider);
        }
        ref.read(historyRetentionProvider.notifier).state =
            historyRetentionSummaryFromUser(
          next,
          fallback: ref.read(historyRetentionProvider),
        );
      }
    });
    final screens = [
      GalleryScreen(refreshToken: _galleryRefreshToken),
      const MaterializerScreen(),
      const ChronogearScreen(),
      CompendiumScreen(refreshToken: _historyRefreshToken),
      ProfileScreen(refreshToken: _profileRefreshToken),
    ];

    void selectTab(int index) {
      if (index == _currentIndex) return;
      if (index == 1 || index == 2) {
        ref.invalidate(imageCapabilitiesProvider);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _currentIndex = index;
        _visitedTabs.add(index);
        if (index == 0) _galleryRefreshToken += 1;
        if (index == 3) _historyRefreshToken += 1;
        if (index == 4) _profileRefreshToken += 1;
      });
    }

    final destinations = [
      NavigationDestination(
          icon: const Icon(Icons.photo_library_outlined),
          selectedIcon: const Icon(Icons.photo_library),
          label: brand.galleryTabLabel),
      NavigationDestination(
          icon: const Icon(Icons.auto_fix_high_outlined),
          selectedIcon: const Icon(Icons.auto_fix_high),
          label: brand.generateTabLabel),
      NavigationDestination(
          icon: const Icon(Icons.brush_outlined),
          selectedIcon: const Icon(Icons.brush),
          label: brand.editTabLabel),
      NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history),
          label: brand.historyTabLabel),
      const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: '我的'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final pages = AppTabStack(
      index: _currentIndex,
      visited: _visitedTabs,
      children: screens,
    );

    return Scaffold(
      // Resize here so nested page scaffolds receive consumed keyboard insets.
      resizeToAvoidBottomInset: true,
      body: wide
          ? Row(children: [
              NavigationRail(
                scrollable: true,
                selectedIndex: _currentIndex,
                onDestinationSelected: selectTab,
                labelType: NavigationRailLabelType.all,
                destinations: destinations
                    .map((item) => NavigationRailDestination(
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          label: Text(item.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages),
            ])
          : pages,
      bottomNavigationBar: wide || keyboardOpen
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: selectTab,
              indicatorColor: brand.primaryColor.withValues(alpha: 0.18),
              destinations: destinations,
            ),
    );
  }
}
