import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_error.dart';
import 'app_brand.dart';
import 'app_update_service.dart';
import 'app_version.dart';
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
    currentVersionName: AppVersion.name,
    currentVersionCode: AppVersion.code,
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

final imageCapabilitiesProvider =
    FutureProvider<ImageCapabilities>((ref) async {
  final client = ref.read(gatewayClientProvider);
  final data = await client.imageCapabilities();
  return ImageCapabilities.fromJson(data);
});

final generateImagesProvider =
    AsyncNotifierProvider<GenerateImagesNotifier, List<Map<String, dynamic>>>(
        () {
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
    final previous = state.valueOrNull ?? const <Map<String, dynamic>>[];
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
      final items = _resultItems(res['data'] ?? res);
      if (items.isEmpty) {
        throw GatewayException(_imageFailureMessage(res, '图片生成失败。'));
      }
      state = AsyncValue.data(items);
      return _partialSuccessMessage(
        actionLabel: '生图',
        items: items,
        errors: res['errors'],
      );
    } catch (e, st) {
      state = previous.isEmpty
          ? AsyncValue.error(e, st)
          : AsyncValue.data(previous);
      return previous.isEmpty ? null : friendlyError(e, fallback: '图片生成失败。');
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
    final previous = state.valueOrNull ?? const <Map<String, dynamic>>[];
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
      final items = _resultItems(res['data'] ?? res);
      if (items.isEmpty) {
        throw GatewayException(_imageFailureMessage(res, '图片修改失败。'));
      }
      state = AsyncValue.data(items);
      return _partialSuccessMessage(
        actionLabel: '改图',
        items: items,
        errors: res['errors'],
      );
    } catch (e, st) {
      state = previous.isEmpty
          ? AsyncValue.error(e, st)
          : AsyncValue.data(previous);
      return previous.isEmpty ? null : friendlyError(e, fallback: '图片修改失败。');
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
  final items = <Map<String, dynamic>>[];

  void collect(dynamic raw) {
    if (raw == null) return;
    if (raw is List) {
      for (final item in raw) {
        collect(item);
      }
      return;
    }
    if (raw is! Map) return;
    final item = Map<String, dynamic>.from(raw);
    final imageUrl = _imageUrl(item);
    if (imageUrl.isNotEmpty) {
      items.add({
        ...item,
        'url': imageUrl,
      });
      return;
    }
    for (final key in ['data', 'images', 'items', 'results', 'output']) {
      collect(item[key]);
    }
  }

  collect(value);
  return items;
}

String _imageUrl(Map<String, dynamic> item) {
  for (final key in ['url', 'src', 'b64_json']) {
    final raw = item[key]?.toString().trim() ?? '';
    if (raw.isNotEmpty) {
      return key == 'b64_json' && !raw.startsWith('data:')
          ? 'data:image/png;base64,$raw'
          : raw;
    }
  }
  final imageUrl = item['image_url'];
  if (imageUrl is String && imageUrl.trim().isNotEmpty) {
    return imageUrl.trim();
  }
  if (imageUrl is Map) {
    final nested = imageUrl['url']?.toString().trim() ?? '';
    if (nested.isNotEmpty) return nested;
  }
  final image = item['image'];
  if (image is Map) {
    final nested = _imageUrl(Map<String, dynamic>.from(image));
    if (nested.isNotEmpty) return nested;
  }
  return '';
}

String _imageFailureMessage(Map<String, dynamic> response, String fallback) {
  final errors = (response['errors'] as List? ?? [])
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
  if (errors.isNotEmpty) {
    return errors.first;
  }
  for (final key in ['detail', 'message', 'error']) {
    final text = response[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '$fallback 未返回可用图片。';
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
