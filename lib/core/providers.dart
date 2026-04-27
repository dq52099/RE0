import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_brand.dart';
import 'app_update_service.dart';
import 'gateway_client.dart';
import 'image_capabilities.dart';
import 'image_cache_service.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final gatewayClientProvider = Provider<GatewayClient>((ref) {
  return GatewayClient();
});

final imageCacheProvider = Provider<ImageCacheService>((ref) {
  return ImageCacheService();
});

final appUpdateProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
    repository: 'dq52099/RE0',
    assetNamePrefix: 'RE0',
    appId: 're0',
    appName: 'RE0',
    packageName: 'com.dq52099.re0',
    currentVersionName: '1.1.2',
    currentVersionCode: 10102,
  );
});

final brandProvider = StateNotifierProvider<BrandNotifier, AppBrand>((ref) {
  return BrandNotifier(ref.read(sharedPrefsProvider));
});

class BrandNotifier extends StateNotifier<AppBrand> {
  BrandNotifier(this._prefs)
      : super(AppBrands.byId(_prefs.getString(_storageKey)));

  static const _storageKey = 'active_brand';

  final SharedPreferences _prefs;

  Future<void> setBrand(String id) async {
    final brand = AppBrands.byId(id);
    state = brand;
    await _prefs.setString(_storageKey, brand.id);
  }
}

final authStateProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final energyProvider = StateProvider<Map<String, dynamic>>((ref) => {
  'generate': {'remaining': 0, 'total': 0, 'used': 0},
  'edit': {'remaining': 0, 'total': 0, 'used': 0},
});

final imageCapabilitiesProvider = FutureProvider<ImageCapabilities>((ref) async {
  final client = ref.read(gatewayClientProvider);
  final data = await client.imageCapabilities();
  return ImageCapabilities.fromJson(data);
});

final materializerProvider = AsyncNotifierProvider<MaterializerNotifier, List<dynamic>>(() {
  return MaterializerNotifier();
});

class MaterializerNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async => [];

  Future<void> materialize(
    String runes,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat,
  ) async {
    state = const AsyncValue.loading();
    try {
      final client = ref.read(gatewayClientProvider);
      final res = await client.materialize(
        runes,
        count,
        size,
        quality,
        background,
        outputFormat,
      );
      ref.read(energyProvider.notifier).state = res['quota_summary'];
      state = AsyncValue.data(res['data']);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recall(
    String runes,
    String imagePath,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat,
  ) async {
    state = const AsyncValue.loading();
    try {
      final client = ref.read(gatewayClientProvider);
      final res = await client.recall(
        runes,
        imagePath,
        count,
        size,
        quality,
        background,
        outputFormat,
      );
      ref.read(energyProvider.notifier).state = res['quota_summary'];
      state = AsyncValue.data(res['data']);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}
