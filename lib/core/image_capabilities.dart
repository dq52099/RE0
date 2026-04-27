class ImageOption {
  const ImageOption({required this.value, required this.label});

  final String value;
  final String label;
}

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
  });

  final ImageActionOptions generate;
  final ImageActionOptions edit;
  final List<ImageOption> outputFormats;

  static ImageCapabilities fallback() {
    const sizes = [
      ImageOption(value: 'auto', label: '自动'),
      ImageOption(value: '1024x1024', label: '1024 × 1024'),
      ImageOption(value: '1536x1024', label: '1536 × 1024'),
      ImageOption(value: '1024x1536', label: '1024 × 1536'),
      ImageOption(value: '2048x2048', label: '2048 × 2048'),
      ImageOption(value: '3840x2160', label: '3840 × 2160'),
      ImageOption(value: '2160x3840', label: '2160 × 3840'),
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
    );
  }

  factory ImageCapabilities.fromJson(Map<String, dynamic> json) {
    final profile = _map(json['profile']);
    final maxImages = int.tryParse(json['max_images_per_request']?.toString() ?? '') ?? 6;
    return ImageCapabilities(
      generate: _actionOptions(_map(profile['generate']), maxImages),
      edit: _actionOptions(_map(profile['edit']), maxImages),
      outputFormats: const [
        ImageOption(value: 'png', label: 'PNG'),
        ImageOption(value: 'jpeg', label: 'JPEG'),
        ImageOption(value: 'webp', label: 'WebP'),
      ],
    );
  }

  static ImageActionOptions _actionOptions(Map<String, dynamic> json, int maxImages) {
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

  static List<ImageOption> _plainOptions(dynamic values, Map<String, String> labels) {
    final parsed = _options(values)
        .map((item) => ImageOption(value: item.value, label: labels[item.value] ?? item.label))
        .toList();
    return parsed.isEmpty
        ? labels.entries.map((item) => ImageOption(value: item.key, label: item.value)).toList()
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
