class ImageOption {
  const ImageOption({required this.value, required this.label});

  final String value;
  final String label;
}

class ImageResolutionTier {
  const ImageResolutionTier({required this.value, required this.label});

  final String value;
  final String label;
}

const imageResolutionTiers = [
  ImageResolutionTier(value: 'auto', label: '自动'),
  ImageResolutionTier(value: '1k', label: '1K'),
  ImageResolutionTier(value: '2k', label: '2K'),
  ImageResolutionTier(value: '4k', label: '4K'),
];

class ImageAspectRatioOption {
  const ImageAspectRatioOption({required this.value, required this.label});

  final String value;
  final String label;
}

const imageAspectRatioOptions = [
  ImageAspectRatioOption(value: 'auto', label: '自动'),
  ImageAspectRatioOption(value: '1:1', label: '1:1 方图'),
  ImageAspectRatioOption(value: '4:3', label: '4:3 横图'),
  ImageAspectRatioOption(value: '3:4', label: '3:4 竖图'),
  ImageAspectRatioOption(value: '16:9', label: '16:9 横图'),
  ImageAspectRatioOption(value: '9:16', label: '9:16 竖图'),
];

class ImageActionOptions {
  const ImageActionOptions({
    required this.sizes,
    required this.qualities,
    required this.backgrounds,
    required this.maxImages,
  });

  final List<ImageOption> sizes;
  final List<ImageOption> qualities;
  final List<ImageOption> backgrounds;
  final int maxImages;

  String get defaultSize => _firstValue(sizes, 'auto');
  String get defaultQuality => _firstValue(qualities, 'high');
  String get defaultBackground => _firstValue(backgrounds, 'auto');

  static String _firstValue(List<ImageOption> items, String preferred) {
    for (final item in items) {
      if (item.value == preferred) {
        return preferred;
      }
    }
    return items.isEmpty ? preferred : items.first.value;
  }
}

class ImageCapabilities {
  const ImageCapabilities({
    required this.generate,
    required this.edit,
    required this.outputFormats,
    required this.imageModes,
  });

  final ImageActionOptions generate;
  final ImageActionOptions edit;
  final List<ImageOption> outputFormats;
  final ImageModeCapabilities imageModes;

  static ImageCapabilities fallback() {
    const sizes = [
      ImageOption(value: 'auto', label: '自动'),
      ImageOption(value: '1024x1024', label: '1024 × 1024'),
      ImageOption(value: '1024x768', label: '1024 × 768'),
      ImageOption(value: '768x1024', label: '768 × 1024'),
      ImageOption(value: '1024x576', label: '1024 × 576'),
      ImageOption(value: '576x1024', label: '576 × 1024'),
      ImageOption(value: '1536x1024', label: '1536 × 1024'),
      ImageOption(value: '1024x1536', label: '1024 × 1536'),
      ImageOption(value: '2048x2048', label: '2048 × 2048'),
      ImageOption(value: '2048x1152', label: '2048 × 1152'),
      ImageOption(value: '1152x2048', label: '1152 × 2048'),
      ImageOption(value: '2048x1536', label: '2048 × 1536'),
      ImageOption(value: '1536x2048', label: '1536 × 2048'),
      ImageOption(value: '3840x2160', label: '3840 × 2160'),
      ImageOption(value: '2160x3840', label: '2160 × 3840'),
      ImageOption(value: '4096x2304', label: '4096 × 2304'),
      ImageOption(value: '2304x4096', label: '2304 × 4096'),
      ImageOption(value: '4096x3072', label: '4096 × 3072'),
      ImageOption(value: '3072x4096', label: '3072 × 4096'),
      ImageOption(value: '4096x4096', label: '4096 × 4096'),
    ];
    const qualities = [
      ImageOption(value: 'auto', label: '自动'),
      ImageOption(value: 'low', label: '低'),
      ImageOption(value: 'medium', label: '中'),
      ImageOption(value: 'high', label: '高'),
    ];
    const backgrounds = [
      ImageOption(value: 'auto', label: '自动'),
      ImageOption(value: 'opaque', label: '不透明'),
      ImageOption(value: 'transparent', label: '透明'),
    ];
    return const ImageCapabilities(
      generate: ImageActionOptions(
        sizes: sizes,
        qualities: qualities,
        backgrounds: backgrounds,
        maxImages: 6,
      ),
      edit: ImageActionOptions(
        sizes: sizes,
        qualities: qualities,
        backgrounds: backgrounds,
        maxImages: 6,
      ),
      outputFormats: [
        ImageOption(value: 'png', label: 'PNG'),
        ImageOption(value: 'jpeg', label: 'JPEG'),
        ImageOption(value: 'webp', label: 'WebP'),
      ],
      imageModes:
          ImageModeCapabilities(current: 'vip', allowed: ['vip', 'general']),
    );
  }

  factory ImageCapabilities.fromJson(Map<String, dynamic> json) {
    final profile = _map(json['profile']);
    final maxImages =
        int.tryParse(json['max_images_per_request']?.toString() ?? '') ?? 6;
    return ImageCapabilities(
      generate: _actionOptions(_map(profile['generate']), maxImages),
      edit: _actionOptions(_map(profile['edit']), maxImages),
      outputFormats: const [
        ImageOption(value: 'png', label: 'PNG'),
        ImageOption(value: 'jpeg', label: 'JPEG'),
        ImageOption(value: 'webp', label: 'WebP'),
      ],
      imageModes: ImageModeCapabilities.fromJson(_map(json['image_modes'])),
    );
  }

  static ImageActionOptions _actionOptions(
      Map<String, dynamic> json, int maxImages) {
    return ImageActionOptions(
      sizes: _options(json['sizes']),
      qualities: _plainOptions(json['qualities'], {
        'auto': '自动',
        'low': '低',
        'medium': '中',
        'high': '高',
      }),
      backgrounds: _plainOptions(json['backgrounds'], {
        'auto': '自动',
        'opaque': '不透明',
        'transparent': '透明',
      }),
      maxImages: maxImages,
    );
  }

  static List<ImageOption> _options(dynamic values) {
    return (values as List? ?? [])
        .map((item) {
          if (item is Map) {
            final value = item['value']?.toString() ?? '';
            if (value.isEmpty) return null;
            return ImageOption(
              value: value,
              label: _displayLabel(value, item['label']?.toString()),
            );
          }
          final value = item?.toString() ?? '';
          if (value.isEmpty) return null;
          return ImageOption(value: value, label: _displayLabel(value, null));
        })
        .whereType<ImageOption>()
        .toList();
  }

  static List<ImageOption> _plainOptions(
      dynamic values, Map<String, String> labels) {
    final parsed = _options(values)
        .map((item) => ImageOption(
            value: item.value, label: labels[item.value] ?? item.label))
        .toList();
    return parsed.isEmpty
        ? labels.entries
            .map((item) => ImageOption(value: item.key, label: item.value))
            .toList()
        : parsed;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static String _displayLabel(String value, String? label) {
    final normalized = value.trim();
    final sizeMatch = RegExp(r'^(\d+)x(\d+)$').firstMatch(normalized);
    if (sizeMatch != null) {
      return '${sizeMatch.group(1)} × ${sizeMatch.group(2)}';
    }
    return (label == null || label.trim().isEmpty) ? value : label;
  }
}

class ImageModeCapabilities {
  const ImageModeCapabilities({
    required this.current,
    required this.allowed,
  });

  final String current;
  final List<String> allowed;

  bool get canSwitch => allowed.contains('vip') && allowed.contains('general');

  factory ImageModeCapabilities.fromJson(Map<String, dynamic> json) {
    final allowed = (json['allowed'] as List? ?? const [])
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item == 'vip' || item == 'general')
        .toSet()
        .toList();
    final current = json['current']?.toString().trim().toLowerCase();
    final fallback = allowed.contains('vip') ? 'vip' : 'general';
    return ImageModeCapabilities(
      current: current == 'vip' || current == 'general' ? current! : fallback,
      allowed: allowed.isEmpty ? [fallback] : allowed,
    );
  }
}

String imageModeLabel(String mode) {
  return mode == 'general' ? '一般' : 'VIP';
}

String imageModeFromItem(Map<String, dynamic> item) {
  final raw = item['image_mode']?.toString().trim().toLowerCase();
  if (raw == 'vip' || raw == 'general') return raw!;
  final label = item['image_mode_label']?.toString().trim().toLowerCase();
  if (label == 'vip') return 'vip';
  if (label == '一般' || label == 'normal' || label == 'general') {
    return 'general';
  }
  final model = item['model_name']?.toString() ?? '';
  if (model.startsWith('一般模式:')) return 'general';
  if (model.startsWith('VIP模式:')) return 'vip';
  return model.contains('codex-gpt-image') ? 'general' : 'vip';
}

String imageModeLabelFromItem(Map<String, dynamic> item) {
  final explicit = item['image_mode_label']?.toString().trim();
  if (explicit == 'VIP' || explicit == '一般') return explicit!;
  return imageModeLabel(imageModeFromItem(item));
}

List<ImageOption> filterSizeOptionsByResolution(
  List<ImageOption> sizes,
  String tier,
) {
  bool belongsToTier(ImageOption option) {
    final value = option.value.trim().toLowerCase();
    if (tier == 'auto') return value == 'auto';
    final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(value);
    if (match == null) return false;
    final width = int.tryParse(match.group(1) ?? '') ?? 0;
    final height = int.tryParse(match.group(2) ?? '') ?? 0;
    final longest = width > height ? width : height;
    if (tier == '1k') return longest > 0 && longest < 2048;
    if (tier == '2k') return longest == 2048;
    if (tier == '4k') return longest >= 3840;
    return false;
  }

  final filtered = sizes.where(belongsToTier).toList();
  if (filtered.isNotEmpty) return _dedupeSizesByRatio(filtered);
  if (tier == 'auto') return sizes.isEmpty ? const [] : [sizes.first];
  return _dedupeSizesByRatio(
      sizes.where((item) => item.value != 'auto').toList());
}

List<ImageOption> _strictSizeOptionsByResolution(
  List<ImageOption> sizes,
  String tier,
) {
  if (tier == 'auto')
    return sizes.where((item) => item.value == 'auto').toList();
  return sizes
      .where((item) => _belongsToResolutionTier(item.value, tier))
      .toList();
}

String resolveSizeForResolutionAndAspect(
  List<ImageOption> sizes,
  String tier,
  String aspectRatio,
  String autoAspectRatio,
) {
  if (tier == 'auto' && aspectRatio == 'auto') {
    return _firstSizeValue(sizes, 'auto');
  }
  if (tier == 'auto') {
    final ratioMatches =
        sizes.where((item) => _sizeRatio(item.value) == aspectRatio);
    if (ratioMatches.isNotEmpty) return ratioMatches.first.value;
    return _firstSizeValue(sizes, 'auto');
  }
  if (aspectRatio == 'auto') {
    return defaultSizeForResolution(
      sizes,
      tier,
      _firstSizeValue(sizes, 'auto'),
      autoAspectRatio,
    );
  }
  final exactTierMatches = sizes.where(
    (item) =>
        _belongsToResolutionTier(item.value, tier) &&
        _sizeRatio(item.value) == aspectRatio,
  );
  if (exactTierMatches.isNotEmpty) return exactTierMatches.first.value;

  final ratioMatches =
      sizes.where((item) => _sizeRatio(item.value) == aspectRatio);
  if (ratioMatches.isNotEmpty) {
    final sameTier = ratioMatches
        .where((item) => _belongsToResolutionTier(item.value, tier));
    if (sameTier.isNotEmpty) return sameTier.first.value;
  }

  return defaultSizeForResolution(
    sizes,
    tier,
    _firstSizeValue(sizes, 'auto'),
    autoAspectRatio,
  );
}

String defaultSizeForResolution(
  List<ImageOption> sizes,
  String tier,
  String fallback,
  String preferredAspectRatio,
) {
  final filtered = filterSizeOptionsByResolution(sizes, tier);
  if (filtered.isEmpty) return fallback;
  final strict = _strictSizeOptionsByResolution(sizes, tier);
  if (strict.isEmpty) return fallback;
  final preferred =
      strict.where((item) => _sizeRatio(item.value) == preferredAspectRatio);
  if (preferred.isNotEmpty) return preferred.first.value;
  final square = strict.where((item) => _sizeRatio(item.value) == '1:1');
  return (square.isNotEmpty ? square.first : strict.first).value;
}

String decoratedSizeLabel(ImageOption option) {
  final value = option.value.trim().toLowerCase();
  if (value == 'auto') return option.label;
  final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(value);
  if (match == null) return option.label;
  final width = int.tryParse(match.group(1) ?? '') ?? 0;
  final height = int.tryParse(match.group(2) ?? '') ?? 0;
  if (width <= 0 || height <= 0) return option.label;
  final ratio = _sizeRatio(value);
  final orientation = width == height
      ? '方图'
      : width > height
          ? '横图'
          : '竖图';
  return '$ratio $orientation · ${option.label}';
}

String _sizeRatio(String value) {
  final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(value.trim().toLowerCase());
  if (match == null) return '';
  final width = int.tryParse(match.group(1) ?? '') ?? 0;
  final height = int.tryParse(match.group(2) ?? '') ?? 0;
  if (width <= 0 || height <= 0) return '';
  final divisor = width.gcd(height);
  return '${width ~/ divisor}:${height ~/ divisor}';
}

bool _belongsToResolutionTier(String value, String tier) {
  final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(value.trim().toLowerCase());
  if (match == null) return false;
  final width = int.tryParse(match.group(1) ?? '') ?? 0;
  final height = int.tryParse(match.group(2) ?? '') ?? 0;
  final longest = width > height ? width : height;
  if (tier == '1k') return longest > 0 && longest < 2048;
  if (tier == '2k') return longest == 2048;
  if (tier == '4k') return longest >= 3840;
  return tier == 'auto' && value == 'auto';
}

String _firstSizeValue(List<ImageOption> sizes, String preferred) {
  for (final item in sizes) {
    if (item.value == preferred) return item.value;
  }
  return sizes.isEmpty ? preferred : sizes.first.value;
}

List<ImageOption> _dedupeSizesByRatio(List<ImageOption> sizes) {
  const ratioOrder = ['1:1', '4:3', '3:4', '16:9', '9:16'];
  final byRatio = <String, ImageOption>{};
  final extras = <ImageOption>[];
  for (final item in sizes) {
    final ratio = _sizeRatio(item.value);
    if (ratio.isEmpty) {
      extras.add(item);
      continue;
    }
    byRatio.putIfAbsent(ratio, () => item);
  }
  return [
    for (final ratio in ratioOrder)
      if (byRatio.containsKey(ratio)) byRatio[ratio]!,
    for (final entry in byRatio.entries)
      if (!ratioOrder.contains(entry.key)) entry.value,
    ...extras,
  ];
}
