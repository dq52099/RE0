import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/admin_settings_sync.dart';
import 'package:re0/core/api_error.dart';

void main() {
  test('Address and WebDAV path normalization matches server readback', () {
    final patch = buildAdminSettingsPatch(initialValues: {
      'provider_base_url': 'https://primary.example/v1',
      'openlist_backup_primary_path': '/old',
    }, values: {
      'provider_base_url': 'https://primary.example/v1/',
      'openlist_backup_primary_path': 'new-folder',
    });
    expect(patch, {'openlist_backup_primary_path': '/new-folder'});
    verifyAdminSettingsSaved({
      'provider_base_url': 'https://primary.example/v1/',
      'openlist_backup_primary_path': 'new-folder',
    }, {
      'settings': [
        {'key': 'provider_base_url', 'value': 'https://primary.example/v1'},
        {'key': 'openlist_backup_primary_path', 'value': '/new-folder'},
      ]
    });
  });

  test('edits preserve unrelated server settings and blank credentials', () {
    final patch = buildAdminSettingsPatch(
      initialValues: {
        'provider_model': 'gpt-image-2',
        'provider_backup_enabled': false,
        'provider_backup_model': 'gpt-image-2.5',
        'provider_healthcheck_enabled': false,
        'provider_timeout_seconds': 300,
      },
      values: {
        'provider_model': 'gpt-image-2',
        'provider_backup_enabled': true,
        'provider_backup_model': 'gpt-image-2.5',
        'provider_healthcheck_enabled': false,
        'provider_timeout_seconds': 300,
      },
    );
    expect(patch, {'provider_backup_enabled': true});
  });

  test('server confirms booleans, models, custom profiles, and masked keys',
      () {
    verifyAdminSettingsSaved({
      'provider_backup_enabled': true,
      'provider_backup_model': 'gpt-image-2.5',
      'provider_backup_image_profile': 'custom-profile',
      'provider_healthcheck_enabled': false,
      'provider_timeout_seconds': 300,
      'provider_backup_api_key': 'new-private-key',
    }, {
      'settings': [
        {'key': 'provider_backup_enabled', 'value': 'true'},
        {'key': 'provider_backup_model', 'value': 'gpt-image-2.5'},
        {'key': 'provider_backup_image_profile', 'value': 'custom-profile'},
        {'key': 'provider_healthcheck_enabled', 'value': 'false'},
        {'key': 'provider_timeout_seconds', 'value': '300'},
        {
          'key': 'provider_backup_api_key',
          'value': 'ne***ey',
          'is_sensitive': true,
        },
      ],
    });
  });

  test('HTTP success cannot hide an ignored backup switch', () {
    for (final settings in [
      <Map<String, dynamic>>[],
      [
        {'key': 'provider_backup_enabled', 'value': 'false'}
      ],
      [
        {'key': 'provider_backup_enabled', 'value': null}
      ],
    ]) {
      expect(
        () => verifyAdminSettingsSaved(
          {'provider_backup_enabled': true},
          {'settings': settings},
        ),
        throwsA(isA<GatewayException>()),
      );
    }
  });
}
