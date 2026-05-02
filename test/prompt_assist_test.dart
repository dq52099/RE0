import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/prompt_assist.dart';

void main() {
  group('buildEditPromptIdeaRequest', () {
    test('returns empty string when idea is blank', () {
      expect(buildEditPromptIdeaRequest('   ', const ['a']), '');
    });

    test('returns plain idea when no image candidates exist', () {
      expect(
        buildEditPromptIdeaRequest('保留人物姿态，改成雨夜霓虹感', const []),
        '保留人物姿态，改成雨夜霓虹感',
      );
    });

    test('builds merged request with numbered image traits', () {
      final text = buildEditPromptIdeaRequest(
        '保留人物姿态，改成雨夜霓虹感',
        const ['少女站在街道中央，冷色霓虹灯', '长发、风衣、电影感逆光'],
      );

      expect(text, contains('用户简单想法：保留人物姿态，改成雨夜霓虹感'));
      expect(text, contains('1. 少女站在街道中央，冷色霓虹灯'));
      expect(text, contains('2. 长发、风衣、电影感逆光'));
      expect(text, contains('生成 3 条适合图片编辑的中文提示词候选'));
    });
  });
}
