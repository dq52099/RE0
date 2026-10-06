import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/admin_settings_presentation.dart';

void main() {
  test(
      'Malformed and non-finite numbers fail instead of disappearing from a save',
      () {
    for (final input in ['oops', '', 'NaN', 'Infinity', '4', '3601', '100.5']) {
      expect(validateAdminSettingInput({'provider_timeout_seconds': input}),
          isNotNull);
    }
    expect(validateAdminSettingInput({'provider_timeout_seconds': '1200'}),
        isNull);
    expect(validateAdminSettingInput({'vip_image_quota_multiplier': '0.5'}),
        isNull);
    expect(validateAdminSettingInput({'local_backup_interval_minutes': '3600'}),
        isNull);
  });
  test(
      'Optional addresses can be cleared but populated addresses must be usable',
      () {
    expect(validateAdminSettingInput({'prompt_ai_base_url': ''}), isNull);
    expect(validateAdminSettingInput({'provider_base_url': 'example.com/v1'}),
        isNotNull);
    expect(
        validateAdminSettingInput(
            {'provider_base_url': 'https://example.com/v1'}),
        isNull);
  });
  test(
      'Setting summaries protect sensitive values and describe units and routes',
      () {
    expect(adminSettingValue('prompt_ai_api_key', 'secret-value'), '已配置');
    expect(adminSettingValue('prompt_ai_api_key', ''), '未配置');
    expect(adminSettingValue('provider_active_slot', 'backup'), '备用线路');
    expect(adminSettingValue('provider_healthcheck_enabled', false), '关闭');
    expect(adminSettingValue('provider_timeout_seconds', 900), '900 秒');
    expect(adminSettingValue('provider_backup_model', ''), '沿用主用模型');
    expect(adminSettingLabels.containsKey('provider_image_profile'), isFalse);
  });
}
