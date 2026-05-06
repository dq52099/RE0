import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/providers.dart';

void main() {
  test('missing retention fields keep existing visible quota', () {
    final fallback = {
      'generate': {'remaining': 45, 'total': 50, 'used': 5},
      'edit': {'remaining': 18, 'total': 20, 'used': 2},
    };

    final summary = historyRetentionSummaryFromUser(
      {'id': 'user_1', 'username': 'tester'},
      fallback: fallback,
    );

    expect(summary['generate']['remaining'], 45);
    expect(summary['generate']['total'], 50);
    expect(summary['edit']['remaining'], 18);
    expect(summary['edit']['total'], 20);
  });

  test('missing retention fields use default quota instead of 0/0', () {
    final summary = historyRetentionSummaryFromUser({
      'id': 'user_1',
      'username': 'tester',
    });

    expect(summary['generate']['remaining'], 50);
    expect(summary['generate']['total'], 50);
    expect(summary['edit']['remaining'], 20);
    expect(summary['edit']['total'], 20);
  });
}
