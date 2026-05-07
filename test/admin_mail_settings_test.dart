import 'package:flutter_test/flutter_test.dart';
import 'package:re0/features/admin/admin_screen.dart';

void main() {
  test('mail settings payload only contains mail fields', () {
    final payload = buildAdminMailSettingsPayload(
      emailServiceEnabled: true,
      emailPrimaryProvider: ' claw163 ',
      emailBackupProvider: ' resend ',
      emailActiveSlot: ' primary ',
      emailAutoSwitchEnabled: false,
      openclawMailEnabled: true,
      openclawMailUser: ' bot.image@claw.163.com ',
      openclawMailApiKey: ' ck_test ',
      emailSenderName: '',
      resendBase: '',
      resendKey: '',
      resendFrom: ' noreply@example.com ',
      smtpHost: ' smtp.example.com ',
      smtpPort: 'bad-port',
      smtpUsername: ' user@example.com ',
      smtpPassword: '',
      smtpUseSsl: true,
      systemNoticeEmailTo: ' admin@example.com ',
      hermesBase: '',
      hermesKey: '',
    );

    expect(payload['email_code_primary_provider'], 'claw163');
    expect(payload['email_code_backup_provider'], 'resend');
    expect(payload['email_code_active_slot'], 'primary');
    expect(payload['email_sender_name'], '从零开始生图');
    expect(payload['resend_base_url'], 'https://api.resend.com');
    expect(payload['email_smtp_port'], 465);
    expect(payload['openclaw_mail_api_key'], 'ck_test');
    expect(payload.containsKey('resend_api_key'), isFalse);
    expect(payload.containsKey('email_smtp_password'), isFalse);

    for (final key in payload.keys) {
      expect(
        key.startsWith('email_') ||
            key.startsWith('openclaw_mail_') ||
            key.startsWith('resend_') ||
            key.startsWith('system_notice') ||
            key.startsWith('hermes_'),
        isTrue,
        reason: '$key should not be submitted from the mail settings dialog',
      );
    }
  });
}
