/// User-facing settings. Legacy parameter templates stay on the server.
const adminSettingLabels = <String, String>{
  'ui_title': '应用标题',
  'external_access_base_url': '公开访问地址',
  'allow_public_registration': '允许自助注册',
  'registration_email_required': '注册验证邮箱',
  'registration_invite_required': '注册需要邀请码',
  'vip_image_quota_multiplier': 'VIP 图片额度倍率',
  'daily_checkin_generate_multiplier': '签到生图奖励倍率',
  'daily_checkin_edit_multiplier': '签到改图奖励倍率',
  'daily_image_draw_history_limit': '每日一图保留记录数',
  'provider_primary_enabled': '主用生图服务',
  'provider_backup_enabled': '备用生图服务',
  'provider_base_url': '主用服务地址',
  'provider_api_key': '主用服务密钥',
  'provider_model': '主用生图模型',
  'provider_backup_base_url': '备用服务地址',
  'provider_backup_api_key': '备用服务密钥',
  'provider_backup_model': '备用生图模型',
  'provider_active_slot': '优先使用线路',
  'provider_requested_slot': '优先使用线路',
  'provider_configured': '生图服务配置',
  'provider_timeout_seconds': '生成等待上限',
  'provider_healthcheck_enabled': '定时检测线路',
  'provider_healthcheck_interval_minutes': '线路检测间隔',
  'general_provider_enabled': '一般模式生图服务',
  'general_provider_base_url': '一般模式服务地址',
  'general_provider_api_key': '一般模式服务密钥',
  'general_provider_image_model': '一般模式生图模型',
  'general_provider_configured': '一般模式服务配置',
  'feedback_ai_base_url': '反馈整理服务地址',
  'feedback_ai_api_key': '反馈整理服务密钥',
  'feedback_ai_model': '反馈整理模型',
  'prompt_ai_base_url': '提示词与识图服务地址',
  'prompt_ai_api_key': '提示词与识图服务密钥',
  'prompt_ai_model': '提示词与识图模型',
  'notification_retention_days': '已读通知保留时间',
  'notification_category_limit': '每类通知显示上限',
  'protect_file_access': '图片访问需要登录',
  'force_app_update_enabled': '要求安装最新 APK',
  'force_relogin_enabled': '要求用户重新登录',
};

const adminCategoryDescriptions = <String, String>{
  '基础设置': '应用名称、注册规则和图片额度',
  '生成线路': '主用、备用和一般模式的生图服务',
  'AI 辅助': '提示词、图片识别和反馈整理，独立于生图服务',
  '福利设置': '每日签到发放的生图和改图额度',
  '每日一图': '抽图历史记录的保留数量',
  '通知设置': '通知显示数量和已读记录清理',
  '系统策略': '图片访问、APK 更新和登录要求',
};

const adminRuntimeLabels = <String, String>{
  'provider_requested_slot': '优先使用线路',
  'provider_active_slot': '实际使用线路',
  'provider_configured': '当前生图服务',
  'provider_base_url': '实际服务地址',
  'provider_model': '实际生图模型',
  'provider_timeout_seconds': '生成等待上限',
  'provider_healthcheck_enabled': '定时线路检测',
  'general_provider_enabled': '一般模式',
  'general_provider_configured': '一般模式配置',
};

String adminSettingValue(String key, dynamic raw, {bool sensitive = false}) {
  final value = raw?.toString().trim() ?? '';
  if (sensitive || key.contains('api_key') || key.endsWith('_password')) {
    return value.isEmpty ? '未配置' : '已配置';
  }
  if (value.isEmpty) {
    if (key == 'provider_backup_model') return '沿用主用模型';
    if (key == 'external_access_base_url') return '自动识别';
    return '未设置';
  }
  if (key.endsWith('_configured') || key == 'provider_configured') {
    return value == 'true' ? '已配置' : '未完整配置';
  }
  if (key.endsWith('_enabled') ||
      const {
        'allow_public_registration',
        'registration_email_required',
        'registration_invite_required',
        'protect_file_access',
      }.contains(key)) {
    return const {'true', '1', 'yes', 'on'}.contains(value.toLowerCase())
        ? '开启'
        : '关闭';
  }
  if (key.endsWith('_slot')) {
    return const {'primary': '主用线路', 'backup': '备用线路'}[value] ?? value;
  }
  if (key.endsWith('_minutes')) return '$value 分钟';
  if (key.endsWith('_seconds')) return '$value 秒';
  if (key.endsWith('_days')) return '$value 天';
  if (key.endsWith('_multiplier')) return '$value 倍';
  if (key.endsWith('_limit')) return '$value 条';
  return value;
}

/// Validate raw text before parsing so invalid numbers cannot vanish from a save.
String? validateAdminSettingInput(Map<String, String> values) {
  const numbers = <String, (String, num, num, bool)>{
    'provider_timeout_seconds': ('生成等待上限', 5, 3600, true),
    'provider_healthcheck_interval_minutes': ('线路检测间隔', 5, 1440, true),
    'vip_image_quota_multiplier': ('VIP 图片额度倍率', 0.1, 10, false),
    'daily_checkin_generate_multiplier': ('签到生图奖励倍率', 0.1, 10, false),
    'daily_checkin_edit_multiplier': ('签到改图奖励倍率', 0.1, 10, false),
    'notification_retention_days': ('已读通知保留天数', 1, 365, true),
    'notification_category_limit': ('每类通知显示上限', 1, 200, true),
    'daily_image_draw_history_limit': ('每日一图保留记录数', 1, 50, true),
    'email_smtp_port': ('SMTP 端口', 1, 65535, true),
    'local_backup_interval_minutes': ('自动备份间隔', 5, 10080, true),
    'local_backup_retention_days': ('本地备份保留天数', 1, 365, true),
    'openlist_backup_sync_retention_days': ('OpenList 云端保留天数', 1, 365, true),
    'openlist_backup_upload_timeout_minutes': (
      'OpenList 上传等待上限',
      10,
      720,
      true
    ),
  };
  for (final entry in values.entries) {
    final rule = numbers[entry.key];
    if (rule == null) continue;
    final text = entry.value.trim();
    final number = rule.$4 ? int.tryParse(text) : num.tryParse(text);
    if (number == null ||
        !number.isFinite ||
        number < rule.$2 ||
        number > rule.$3) {
      return '${rule.$1}应为 ${rule.$2}～${rule.$3} 的${rule.$4 ? '整数' : '数字'}。';
    }
  }
  for (final entry in values.entries) {
    if (!entry.key.endsWith('_base_url') &&
        !entry.key.endsWith('_webdav_url') &&
        !entry.key.endsWith('_public_url')) continue;
    if (entry.value.trim().isEmpty) continue;
    final uri = Uri.tryParse(entry.value.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      return '${adminSettingLabels[entry.key] ?? '服务地址'}需要填写完整的 http:// 或 https:// 地址。';
    }
  }
  return null;
}
