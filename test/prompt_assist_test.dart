import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/prompt_assist.dart';

void main() {
  group('parsePromptCandidates', () {
    test('parses candidates from raw json text', () {
      const raw =
          '{"candidates":["古风国风人物海报，一位灵动少女主角站在画面中央","东方玄幻角色设定图，中心全身像为一名清冷美丽的古装少女","古典仙侠人物志封面，主视觉是一位仙气少女置于中央"]}';

      expect(
        parsePromptCandidates(raw),
        [
          '古风国风人物海报，一位灵动少女主角站在画面中央',
          '东方玄幻角色设定图，中心全身像为一名清冷美丽的古装少女',
          '古典仙侠人物志封面，主视觉是一位仙气少女置于中央',
        ],
      );
    });

    test('parses candidates when json text is nested in candidates', () {
      const raw =
          '{"candidates":["古风国风人物海报，一位灵动少女主角站在画面中央","东方玄幻角色设定图，中心全身像为一名清冷美丽的古装少女","古典仙侠人物志封面，主视觉是一位仙气少女置于中央"]}';

      expect(
        parsePromptCandidates({
          'candidates': [raw]
        }),
        [
          '古风国风人物海报，一位灵动少女主角站在画面中央',
          '东方玄幻角色设定图，中心全身像为一名清冷美丽的古装少女',
          '古典仙侠人物志封面，主视觉是一位仙气少女置于中央',
        ],
      );
    });

    test('does not expose unresolved json as a single candidate', () {
      const malformed = '{"candidates":["一条候选",';

      expect(parsePromptCandidates(malformed), isEmpty);
    });
  });
}
