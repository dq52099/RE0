import 'package:flutter/material.dart';

class _LevelReward {
  const _LevelReward({
    required this.level,
    required this.minPoints,
    required this.generateBonus,
    required this.editBonus,
    required this.badgeName,
    required this.badgeColor,
  });

  final int level;
  final int minPoints;
  final int generateBonus;
  final int editBonus;
  final String badgeName;
  final Color badgeColor;
}

const List<_LevelReward> _levelRewards = [
  _LevelReward(
    level: 0,
    minPoints: 0,
    generateBonus: 0,
    editBonus: 0,
    badgeName: '见习旅者',
    badgeColor: Color(0xFF94A3B8),
  ),
  _LevelReward(
    level: 1,
    minPoints: 100,
    generateBonus: 5,
    editBonus: 2,
    badgeName: '初阶术士',
    badgeColor: Color(0xFF60A5FA),
  ),
  _LevelReward(
    level: 2,
    minPoints: 500,
    generateBonus: 12,
    editBonus: 5,
    badgeName: '进阶术士',
    badgeColor: Color(0xFF34D399),
  ),
  _LevelReward(
    level: 3,
    minPoints: 1000,
    generateBonus: 24,
    editBonus: 10,
    badgeName: '高阶术士',
    badgeColor: Color(0xFFFBBF24),
  ),
  _LevelReward(
    level: 4,
    minPoints: 2000,
    generateBonus: 40,
    editBonus: 16,
    badgeName: '圣域贤者',
    badgeColor: Color(0xFFFB7185),
  ),
  _LevelReward(
    level: 5,
    minPoints: 3500,
    generateBonus: 60,
    editBonus: 24,
    badgeName: '王都典藏',
    badgeColor: Color(0xFFC084FC),
  ),
  _LevelReward(
    level: 6,
    minPoints: 5000,
    generateBonus: 90,
    editBonus: 36,
    badgeName: '异界宗师',
    badgeColor: Color(0xFFF97316),
  ),
];

Future<void> showLevelRewardsSheet(
  BuildContext context,
  Map? levelInfo, {
  Color? accentColor,
}) async {
  final currentLevel = _intValue(levelInfo?['level']);
  final currentPoints = _intValue(levelInfo?['points']);
  final current = _levelRewards.lastWhere(
    (reward) => reward.level <= currentLevel,
    orElse: () => _levelRewards.first,
  );
  final next = _nextReward(currentLevel);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final highlight = accentColor ?? theme.colorScheme.primary;
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: highlight),
                  const SizedBox(width: 8),
                  Text('等级奖励', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlight.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: highlight.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前 LV${current.level} ${current.badgeName}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: current.badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '积分 $currentPoints · 生图 +${current.generateBonus} · 改图 +${current.editBonus}',
                    ),
                    if (next != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '距离 LV${next.level} 还差 ${(next.minPoints - currentPoints).clamp(0, next.minPoints)} 积分',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._levelRewards.map(
                (reward) => _rewardTile(
                  context,
                  reward,
                  isCurrent: reward.level == current.level,
                  isNext: reward.level == next?.level,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _rewardTile(
  BuildContext context,
  _LevelReward reward, {
  required bool isCurrent,
  required bool isNext,
}) {
  final theme = Theme.of(context);
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: reward.badgeColor.withOpacity(isCurrent || isNext ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: reward.badgeColor.withOpacity(isCurrent || isNext ? 0.38 : 0.14),
      ),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: reward.badgeColor.withOpacity(0.16),
          child: Text(
            'LV${reward.level}',
            style: TextStyle(
              color: reward.badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reward.badgeName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isCurrent)
                    const _StatusPill(label: '当前')
                  else if (isNext)
                    const _StatusPill(label: '下一等级'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${reward.minPoints} 积分解锁 · 生图 +${reward.generateBonus} · 改图 +${reward.editBonus}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

int _intValue(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

_LevelReward? _nextReward(int currentLevel) {
  for (final reward in _levelRewards) {
    if (reward.level > currentLevel) return reward;
  }
  return null;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
