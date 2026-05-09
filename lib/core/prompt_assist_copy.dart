import 'app_brand.dart';

class PromptAssistCopy {
  const PromptAssistCopy({
    required this.generateNoun,
    required this.generateVerb,
    required this.generateSlot,
    required this.generateOverflowVerb,
    required this.editNoun,
    required this.editVerb,
    required this.editSlot,
    required this.editOverflowVerb,
    required this.ideaChip,
    required this.ideaAction,
    required this.imageChip,
    required this.imageInferVerb,
  });

  final String generateNoun;
  final String generateVerb;
  final String generateSlot;
  final String generateOverflowVerb;
  final String editNoun;
  final String editVerb;
  final String editSlot;
  final String editOverflowVerb;
  final String ideaChip;
  final String ideaAction;
  final String imageChip;
  final String imageInferVerb;

  String get generateNoResult => '没有生成可用$generateNoun，请换个描述再试。';
  String get generateReady => '已生成$generateNoun，可查看全部或切换使用。';
  String get generateFailure => '$generateNoun生成失败。';
  String get imageNoResult => '$imageInferVerb后没有得到可用$generateNoun，请换张图片再试。';
  String get imageReady => '已$imageInferVerb出$generateNoun，可查看全部或切换使用。';
  String get imageFailure => '图片$imageInferVerb失败，未得到可用$generateNoun。';
  String get generateNoCurrent => '当前没有可用$generateNoun';
  String get generateEmptyCurrent => '当前$generateNoun为空';
  String get generateAllTitle => '全部$generateNoun';
  String get generateFullTitle => '完整$generateNoun';
  String get fillGenerate => '填入$generateNoun';
  String get writeGenerate => '请先编写$generateNoun';
  String get imageEmptyText => '选择本地图片后$imageInferVerb 3 条$generateNoun';
  String get imageSelectedText => '已选择图片，可重新$imageInferVerb或更换图片';

  String generateBusy(AppBrand brand) =>
      '${brand.generateActionLabel}正在进行，请稍后再试';
  String editBusy(AppBrand brand) => '${brand.editActionLabel}正在进行，请稍后再试';
  String editBlocksGenerate(AppBrand brand) =>
      '${brand.editActionLabel}正在进行，请等待完成后再开始$generateVerb。';

  String generateBatchNotice(int count) =>
      '将按 $count 条$generateNoun逐条$generateVerb，结果会陆续显示。';
  String generateUseThisLabel() => '使用当前$generateNoun';
  String generateCountLabel(int count) => '共 $count 条$generateNoun';
  String generateBatchLabel(int count) => '使用当前$count条$generateNoun';
  String generateSwitcherLabel(int index, int total) =>
      '$generateNoun ${index + 1}/$total';
  String previousGenerateTooltip() => '上一条$generateNoun';
  String nextGenerateTooltip() => '下一条$generateNoun';

  String generateRetentionLimitMessage({
    required AppBrand brand,
    required Object used,
    required Object total,
    required int requested,
  }) {
    final requestText = requested > 1 ? '本次需要 $requested 个席位，' : '';
    return '${brand.historyTabLabel}的$generateSlot已满（已用 $used / 上限 $total）。$requestText继续$generateOverflowVerb会挤掉最早的记录；请先到${brand.historyTabLabel}手动清理后再试。';
  }

  String get editNoResult => '没有生成可用$editNoun，请换个想法或图片再试。';
  String get editReady => '已生成$editNoun，可查看全部或切换使用。';
  String get editFailure => '$editNoun生成失败。';
  String get editNoCurrent => '当前没有可用$editNoun';
  String get editEmptyCurrent => '当前$editNoun为空';
  String get editAllTitle => '全部$editNoun';
  String get editFullTitle => '完整$editNoun';
  String get fillEdit => '填入$editNoun';
  String get writeEdit => '请先编写$editNoun';
  String get pickEditSource => '请先选择需要$editVerb的原图';

  String generateBlocksEdit(AppBrand brand) =>
      '${brand.generateActionLabel}正在进行，请等待完成后再开始${brand.editActionLabel}。';

  String editBatchNotice(int count) =>
      '将按 $count 条$editNoun逐条$editVerb，结果会陆续显示。';
  String editUseThisLabel() => '使用当前$editNoun';
  String editCountLabel(int count) => '共 $count 条$editNoun';
  String editBatchLabel(int count) => '使用当前$count条$editNoun';
  String editIntroNoImage() => '先选择图片，再输入简单想法，推荐 3 条$editNoun';
  String editIntroWithImage() => '结合当前图片和简单想法，推荐 3 条$editNoun';
  String editSwitcherLabel(int index, int total) =>
      '$editNoun ${index + 1}/$total';
  String previousEditTooltip() => '上一条$editNoun';
  String nextEditTooltip() => '下一条$editNoun';

  String editRetentionLimitMessage({
    required AppBrand brand,
    required Object used,
    required Object total,
    required int requested,
  }) {
    final requestText = requested > 1 ? '本次需要 $requested 个席位，' : '';
    return '${brand.historyTabLabel}的$editSlot已满（已用 $used / 上限 $total）。$requestText继续$editOverflowVerb会挤掉最早的记录；请先到${brand.historyTabLabel}手动清理后再试。';
  }
}

PromptAssistCopy promptAssistCopyFor(AppBrand brand) {
  switch (brand.style) {
    case BrandStyle.botw:
      return const PromptAssistCopy(
        generateNoun: '符文',
        generateVerb: '具现化',
        generateSlot: '具现化席位',
        generateOverflowVerb: '具现化',
        editNoun: '修正符文',
        editVerb: '回溯',
        editSlot: '回溯席位',
        editOverflowVerb: '回溯',
        ideaChip: '按灵感解析',
        ideaAction: '解析',
        imageChip: '以图解析',
        imageInferVerb: '解析',
      );
    case BrandStyle.re0:
      return const PromptAssistCopy(
        generateNoun: '咒文',
        generateVerb: '咏唱',
        generateSlot: '咏唱席位',
        generateOverflowVerb: '咏唱',
        editNoun: '回归咒文',
        editVerb: '回归',
        editSlot: '回归席位',
        editOverflowVerb: '回响',
        ideaChip: '按思路推演',
        ideaAction: '推演',
        imageChip: '以图反推',
        imageInferVerb: '反推',
      );
    case BrandStyle.genshin:
      return const PromptAssistCopy(
        generateNoun: '元素灵感',
        generateVerb: '绘制',
        generateSlot: '绘卷席位',
        generateOverflowVerb: '绘制',
        editNoun: '炼金指令',
        editVerb: '重塑',
        editSlot: '重塑席位',
        editOverflowVerb: '重塑',
        ideaChip: '按灵感调和',
        ideaAction: '调和',
        imageChip: '以图参照',
        imageInferVerb: '参照',
      );
    case BrandStyle.starRail:
      return const PromptAssistCopy(
        generateNoun: '开拓坐标',
        generateVerb: '跃迁',
        generateSlot: '跃迁席位',
        generateOverflowVerb: '跃迁',
        editNoun: '回溯指令',
        editVerb: '回溯',
        editSlot: '回溯席位',
        editOverflowVerb: '回溯',
        ideaChip: '按坐标推演',
        ideaAction: '推演',
        imageChip: '以图回放',
        imageInferVerb: '回放',
      );
    case BrandStyle.wuthering:
      return const PromptAssistCopy(
        generateNoun: '共鸣频谱',
        generateVerb: '共鸣',
        generateSlot: '共鸣席位',
        generateOverflowVerb: '共鸣',
        editNoun: '调律指令',
        editVerb: '调律',
        editSlot: '调律席位',
        editOverflowVerb: '调律',
        ideaChip: '按频谱推演',
        ideaAction: '推演',
        imageChip: '以图解析',
        imageInferVerb: '解析',
      );
    case BrandStyle.zzz:
      return const PromptAssistCopy(
        generateNoun: '委托说明',
        generateVerb: '执行委托',
        generateSlot: '委托席位',
        generateOverflowVerb: '执行委托',
        editNoun: '剪辑脚本',
        editVerb: '剪辑',
        editSlot: '剪辑席位',
        editOverflowVerb: '剪辑',
        ideaChip: '按委托整理',
        ideaAction: '整理',
        imageChip: '以图解析',
        imageInferVerb: '解析',
      );
    case BrandStyle.yanyun:
      return const PromptAssistCopy(
        generateNoun: '题画词',
        generateVerb: '入画',
        generateSlot: '入画席位',
        generateOverflowVerb: '入画',
        editNoun: '改画批注',
        editVerb: '重写',
        editSlot: '重写席位',
        editOverflowVerb: '重写',
        ideaChip: '按题意起稿',
        ideaAction: '起稿',
        imageChip: '以图临摹',
        imageInferVerb: '临摹',
      );
  }
}
