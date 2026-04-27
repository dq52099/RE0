import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_error.dart';
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
    appName: '从零开始生图',
    packageName: 'com.dq52099.re0',
    currentVersionName: '1.1.12',
    currentVersionCode: 10112,
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

enum ImageTaskKind {
  generate,
  edit,
}

final activeImageTaskProvider = StateProvider<ImageTaskKind?>((ref) => null);

final imageCapabilitiesProvider = FutureProvider<ImageCapabilities>((ref) async {
  final client = ref.read(gatewayClientProvider);
  final data = await client.imageCapabilities();
  return ImageCapabilities.fromJson(data);
});

final generateImagesProvider =
    AsyncNotifierProvider<GenerateImagesNotifier, List<Map<String, dynamic>>>(() {
  return GenerateImagesNotifier();
});

final editImagesProvider =
    AsyncNotifierProvider<EditImagesNotifier, List<Map<String, dynamic>>>(() {
  return EditImagesNotifier();
});

class GenerateImagesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];

  Future<String?> materialize(
    String runes,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat,
  ) async {
    _ensureTaskAvailable(ref, ImageTaskKind.generate);
    ref.read(activeImageTaskProvider.notifier).state = ImageTaskKind.generate;
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
      ref.read(energyProvider.notifier).state =
          _quotaSummary(res['quota_summary']);
      final items = _resultItems(res['data']);
      state = AsyncValue.data(items);
      return _partialSuccessMessage(
        actionLabel: '生图',
        items: items,
        errors: res['errors'],
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    } finally {
      if (ref.read(activeImageTaskProvider) == ImageTaskKind.generate) {
        ref.read(activeImageTaskProvider.notifier).state = null;
      }
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

class EditImagesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];

  Future<String?> recall(
    String runes,
    String imagePath,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat,
  ) async {
    _ensureTaskAvailable(ref, ImageTaskKind.edit);
    ref.read(activeImageTaskProvider.notifier).state = ImageTaskKind.edit;
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
      ref.read(energyProvider.notifier).state =
          _quotaSummary(res['quota_summary']);
      final items = _resultItems(res['data']);
      state = AsyncValue.data(items);
      return _partialSuccessMessage(
        actionLabel: '改图',
        items: items,
        errors: res['errors'],
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    } finally {
      if (ref.read(activeImageTaskProvider) == ImageTaskKind.edit) {
        ref.read(activeImageTaskProvider.notifier).state = null;
      }
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

void _ensureTaskAvailable(Ref ref, ImageTaskKind nextTask) {
  final activeTask = ref.read(activeImageTaskProvider);
  if (activeTask == null || activeTask == nextTask) {
    return;
  }
  throw GatewayException(
    activeTask == ImageTaskKind.generate
        ? '生图任务进行中，请等待完成后再开始改图。'
        : '改图任务进行中，请等待完成后再开始生图。',
  );
}

Map<String, dynamic> _quotaSummary(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {
    'generate': {'remaining': 0, 'total': 0, 'used': 0},
    'edit': {'remaining': 0, 'total': 0, 'used': 0},
  };
}

List<Map<String, dynamic>> _resultItems(dynamic value) {
  return (value as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String? _partialSuccessMessage({
  required String actionLabel,
  required List<Map<String, dynamic>> items,
  required dynamic errors,
}) {
  final errorCount = (errors as List? ?? []).length;
  if (items.isEmpty || errorCount == 0) {
    return null;
  }
  return '$actionLabel已返回 ${items.length} 张图片，另有 $errorCount 张未完成。';
}
