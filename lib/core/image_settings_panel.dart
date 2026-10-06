import 'package:flutter/material.dart';

import 'compact_dropdown_field.dart';
import 'frontend_widgets.dart';
import 'image_capabilities.dart';

class ImageSettingsPanel extends StatelessWidget {
  const ImageSettingsPanel({
    super.key,
    required this.options,
    required this.outputFormats,
    required this.count,
    required this.resolution,
    required this.aspect,
    required this.quality,
    required this.background,
    required this.outputFormat,
    required this.onCount,
    required this.onResolution,
    required this.onAspect,
    required this.onQuality,
    required this.onBackground,
    required this.onOutputFormat,
  });

  final ImageActionOptions options;
  final List<ImageOption> outputFormats;
  final int count;
  final String resolution, aspect, quality, background, outputFormat;
  final ValueChanged<int> onCount;
  final ValueChanged<String> onResolution,
      onAspect,
      onQuality,
      onBackground,
      onOutputFormat;

  @override
  Widget build(BuildContext context) => FrontendSection(
        title: '图片设置',
        icon: Icons.tune_rounded,
        subtitle: '先选张数、分辨率和画面比例，其他参数可按需调整。',
        child: LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = constraints.maxWidth >= 320 * scale ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 12, runSpacing: 18, children: [
                  _field<int>(
                      context,
                      '张数',
                      count,
                      width,
                      {for (var i = 1; i <= options.maxImages; i++) i: '$i 张'},
                      onCount),
                  _field<String>(
                      context,
                      '分辨率',
                      resolution,
                      width,
                      {
                        for (final item in imageResolutionTiers)
                          item.value: item.label
                      },
                      onResolution),
                  _field<String>(
                      context,
                      '画面比例',
                      aspect,
                      width,
                      {
                        for (final item in imageAspectRatioOptions)
                          item.value: item.label
                      },
                      onAspect),
                ]),
                const SizedBox(height: 8),
                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  title: const Text('高级设置'),
                  subtitle: const Text('质量、背景、文件格式'),
                  children: [
                    Wrap(spacing: 12, runSpacing: 18, children: [
                      _field(
                          context,
                          '质量',
                          quality,
                          width,
                          {
                            for (final item in options.qualities)
                              item.value: item.label
                          },
                          onQuality),
                      _field(
                          context,
                          '背景',
                          background,
                          width,
                          {
                            for (final item in options.backgrounds)
                              item.value: item.label
                          },
                          onBackground),
                      _field(
                          context,
                          '文件格式',
                          outputFormat,
                          width,
                          {
                            for (final item in outputFormats)
                              item.value: item.label
                          },
                          onOutputFormat),
                    ]),
                    const SizedBox(height: 12),
                    const Text('分辨率决定图片尺寸；质量和背景效果取决于当前模型的支持情况。'),
                  ],
                ),
              ]);
        }),
      );

  Widget _field<T>(BuildContext context, String label, T value, double width,
          Map<T, String> items, ValueChanged<T> onChanged) =>
      CompactDropdownField<T>(
        label: label,
        value: value,
        width: width,
        items: items.entries
            .map((item) => CompactDropdownField.centeredItem(
                item.key, item.value, context))
            .toList(),
        selectedLabels: items.values.toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      );
}
