String buildEditPromptIdeaRequest(String idea, List<String> imageCandidates) {
  final ideaText = idea.trim();
  if (ideaText.isEmpty) return '';
  if (imageCandidates.isEmpty) return ideaText;

  return [
    '请基于用户的简单想法，并结合参考图片已有的主体、构图、材质、光影与风格，生成 3 条适合图片编辑的中文提示词候选。',
    '如有冲突，以用户想法为准；保留原图主体与主要构图，重点调整风格、氛围、细节和质感。',
    '用户简单想法：$ideaText',
    '参考图片特征：',
    ...List.generate(
      imageCandidates.length,
      (index) => '${index + 1}. ${imageCandidates[index]}',
    ),
    '要求：直接输出候选提示词，不要解释，不要分段标题。',
  ].join('\n');
}
