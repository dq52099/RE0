import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/image_capabilities.dart';

void main() {
  test('resolves automatic 4K aspect by device preference', () {
    final sizes = ImageCapabilities.fallback().generate.sizes;

    expect(
      resolveSizeForResolutionAndAspect(sizes, '4k', 'auto', '9:16'),
      '2160x3840',
    );
    expect(
      resolveSizeForResolutionAndAspect(sizes, '4k', 'auto', '16:9'),
      '3840x2160',
    );
  });

  test('does not resolve a requested tier to a lower resolution ratio match',
      () {
    const sizes = [
      ImageOption(value: 'auto', label: 'Auto'),
      ImageOption(value: '1024x1536', label: '1024 x 1536'),
      ImageOption(value: '3840x2160', label: '3840 x 2160'),
    ];

    expect(
      resolveSizeForResolutionAndAspect(sizes, '4k', '9:16', '9:16'),
      isNot('1024x1536'),
    );
    expect(
      resolveSizeForResolutionAndAspect(sizes, '4k', '9:16', '9:16'),
      '3840x2160',
    );
  });

  test('keeps full auto as upstream auto', () {
    final sizes = ImageCapabilities.fallback().generate.sizes;

    expect(
      resolveSizeForResolutionAndAspect(sizes, 'auto', 'auto', '9:16'),
      'auto',
    );
  });
}
