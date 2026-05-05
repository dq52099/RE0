import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_error.dart';
import 'compact_save_notice.dart';
import 'gateway_client.dart';

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
  GatewayClient? client,
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
          child: _LevelRewardsContent(
            levelInfo: levelInfo,
            fallbackRewards: _levelRewards,
            client: client,
            highlight: highlight,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: highlight),
                    const SizedBox(width: 8),
                    Text('每日奖励', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: highlight.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: highlight.withValues(alpha: 0.18)),
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
                        '积分 $currentPoints · 每日生图 +${current.generateBonus} · 每日改图 +${current.editBonus}',
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
        ),
      );
    },
  );
}

class _LevelRewardsContent extends StatefulWidget {
  const _LevelRewardsContent({
    required this.levelInfo,
    required this.fallbackRewards,
    required this.client,
    required this.highlight,
    required this.child,
  });

  final Map? levelInfo;
  final List<_LevelReward> fallbackRewards;
  final GatewayClient? client;
  final Color highlight;
  final Widget child;

  @override
  State<_LevelRewardsContent> createState() => _LevelRewardsContentState();
}

class _LevelRewardsContentState extends State<_LevelRewardsContent> {
  Future<Map<String, dynamic>>? _future;
  final Set<int> _claiming = {};

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _future = widget.client!.getLevelRewards();
    }
  }

  Future<void> _claim(int level) async {
    final client = widget.client;
    if (client == null || _claiming.contains(level)) return;
    setState(() => _claiming.add(level));
    try {
      final result = await client.claimLevelReward(level);
      final code = result['invitation_code']?.toString() ?? '';
      if (!mounted) return;
      if (code.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: code));
        showCenterNotice(context, '邀请码已领取并复制');
      } else {
        showCenterNotice(context, '等级奖励已领取');
      }
      setState(() {
        _future = client.getLevelRewards();
      });
    } catch (error) {
      if (!mounted) return;
      showCenterNotice(
        context,
        friendlyError(error, fallback: '领取等级奖励失败。'),
      );
    } finally {
      if (mounted) setState(() => _claiming.remove(level));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_future == null) return widget.child;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        final rewards = (data['rewards'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: widget.highlight),
                const SizedBox(width: 8),
                Text('等级奖励', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              _levelError(context, snapshot.error)
            else ...[
              _levelSummary(context, data),
              const SizedBox(height: 12),
              ...rewards.map((item) => _serverRewardTile(context, item)),
            ],
          ],
        );
      },
    );
  }

  Widget _levelSummary(BuildContext context, Map<String, dynamic> data) {
    final levelInfo = data['level_info'] as Map? ?? widget.levelInfo ?? {};
    final label = levelInfo['label']?.toString() ?? 'LV0';
    final points =
        data['points']?.toString() ?? levelInfo['points']?.toString() ?? '0';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.highlight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.highlight.withValues(alpha: 0.18)),
      ),
      child: Text('$label · 积分 $points · 每级可领取 1 个邀请码'),
    );
  }

  Widget _serverRewardTile(BuildContext context, Map<String, dynamic> item) {
    final level = _intValue(item['level']);
    final color = _colorFromHex(item['badge_color']) ?? widget.highlight;
    final claimable = item['claimable'] == true;
    final claimed = item['claimed'] == true;
    final code = item['invitation_code']?.toString() ?? '';
    final busy = _claiming.contains(level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: claimable ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: color.withValues(alpha: claimable ? 0.38 : 0.14)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Text(
              'LV$level',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['badge_name']?.toString() ?? '等级奖励',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['min_points'] ?? 0} 积分解锁 · 邀请码奖励 ${claimed && code.isNotEmpty ? code : '1 个'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (claimed)
            TextButton(
              onPressed: code.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) showCenterNotice(context, '邀请码已复制');
                    },
              child: const Text('复制'),
            )
          else
            FilledButton(
              onPressed: claimable && !busy ? () => _claim(level) : null,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(claimable ? '领取' : '未解锁'),
            ),
        ],
      ),
    );
  }

  Widget _levelError(BuildContext context, Object? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 8),
          Text(friendlyError(error ?? '读取等级奖励失败。')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _future = widget.client!.getLevelRewards();
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
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
      color: reward.badgeColor
          .withValues(alpha: isCurrent || isNext ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: reward.badgeColor
            .withValues(alpha: isCurrent || isNext ? 0.38 : 0.14),
      ),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: reward.badgeColor.withValues(alpha: 0.16),
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
                '${reward.minPoints} 积分解锁 · 每日生图 +${reward.generateBonus} · 每日改图 +${reward.editBonus}',
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

Color? _colorFromHex(dynamic value) {
  final text = value?.toString().replaceFirst('#', '').trim() ?? '';
  if (text.length != 6) return null;
  final raw = int.tryParse(text, radix: 16);
  if (raw == null) return null;
  return Color(0xFF000000 | raw);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
