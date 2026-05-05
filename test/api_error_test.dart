import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/api_error.dart';

void main() {
  test('friendlyError hides raw upstream usage limit payload', () {
    const raw =
        'Provider returned HTTP 429: {"code":"USAGE_LIMIT_EXCEEDED","message":"error: code=429 reason=\\"DAILY_LIMIT_EXCEEDED\\" message=\\"daily usage limit exceeded\\""}';

    final message = friendlyError(raw);

    expect(message, contains('今日生图通道额度已用尽'));
    expect(message, isNot(contains('USAGE_LIMIT_EXCEEDED')));
    expect(message, isNot(contains('Provider returned HTTP')));
  });
}
