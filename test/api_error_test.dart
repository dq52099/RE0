import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/api_error.dart';

void main() {
  test('friendlyError hides raw upstream usage limit payload', () {
    const raw =
        'Provider returned HTTP 429: {"code":"USAGE_LIMIT_EXCEEDED","message":"error: code=429 reason=\\"DAILY_LIMIT_EXCEEDED\\" message=\\"daily usage limit exceeded\\""}';

    final message = friendlyError(raw);

    expect(message, contains('今日咏唱线路的玛那已耗尽'));
    expect(message, isNot(contains('USAGE_LIMIT_EXCEEDED')));
    expect(message, isNot(contains('Provider returned HTTP')));
  });

  test('friendlyError hides provider key-level detail', () {
    const raw = '文本：key1: 上游返回异常；图片：key2: 上游拒绝访问';

    final message = friendlyError(raw);

    expect(message, contains('咏唱线路'));
    expect(message, isNot(contains('key1')));
    expect(message, isNot(contains('key2')));
  });
}
