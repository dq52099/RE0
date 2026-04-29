import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/compact_dropdown_field.dart';
import '../../core/compact_save_notice.dart';
import '../../core/image_capabilities.dart';
import '../../core/providers.dart';
import '../../core/timezone_reset_hint.dart';
import '../compendium/image_preview_screen.dart';

enum _PromptAssistMode {
  idea,
  image,
}

class MaterializerScreen extends ConsumerStatefulWidget {
  const MaterializerScreen({super.key});

  @override
  ConsumerState<MaterializerScreen> createState() => _MaterializerScreenState();
}

class _MaterializerScreenState extends ConsumerState<MaterializerScreen> {
  final TextEditingController _spellController = TextEditingController();
  final TextEditingController _ideaController = TextEditingController();
  final ImagePicker _assistImagePicker = ImagePicker();
  int _count = 1;
  String _size = 'auto';
  String _quality = 'high';
  String _background = 'auto';
  String _outputFormat = 'png';
  String _lastSubmittedPrompt = '';
  _PromptAssistMode _assistMode = _PromptAssistMode.idea;
  List<String> _ideaCandidates = const [];
  List<String> _imageCandidates = const [];
  int _ideaCandidateIndex = 0;
  int _imageCandidateIndex = 0;
  bool _isGeneratingIdeaPrompt = false;
  bool _isRecognizingImagePrompt = false;
  String? _ideaAssistError;
  String? _imageAssistError;
  String? _lastAppliedCandidate;
  File? _assistImageFile;

  @override
  void dispose() {
    _spellController.dispose();
    _ideaController.dispose();
    super.dispose();
  }

  Future<void> _generatePromptFromIdea() async {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      showCenterNotice(context, '请先写下简单想法');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _assistMode = _PromptAssistMode.idea;
      _isGeneratingIdeaPrompt = true;
      _ideaAssistError = null;
    });
    try {
      final candidates =
          await ref.read(gatewayClientProvider).generatePromptCandidates(idea);
      if (!mounted) return;
      if (candidates.isEmpty) {
        setState(() {
          _ideaCandidates = const [];
          _ideaCandidateIndex = 0;
          _ideaAssistError = 'AI 没有返回可用咒文，请换个描述再试。';
        });
        return;
      }
      setState(() {
        _ideaCandidates = candidates;
        _ideaCandidateIndex = 0;
      });
      _applyCurrentCandidateIfSafe();
    } catch (error) {
      if (!mounted) return;
      setState(() =>
          _ideaAssistError = friendlyError(error, fallback: 'AI 生成咒文失败。'));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingIdeaPrompt = false);
      }
    }
  }

  Future<void> _pickAndRecognizeImagePrompt() async {
    final picked = await _assistImagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() {
      _assistMode = _PromptAssistMode.image;
      _assistImageFile = File(picked.path);
      _isRecognizingImagePrompt = true;
      _imageAssistError = null;
    });
    try {
      final candidates = await ref
          .read(gatewayClientProvider)
          .identifyImagePromptCandidates(picked.path);
      if (!mounted) return;
      if (candidates.isEmpty) {
        setState(() {
          _imageCandidates = const [];
          _imageCandidateIndex = 0;
          _imageAssistError = 'AI 没有识别出可用咒文，请换张图片再试。';
        });
        return;
      }
      setState(() {
        _imageCandidates = candidates;
        _imageCandidateIndex = 0;
      });
      _applyCurrentCandidateIfSafe();
    } catch (error) {
      if (!mounted) return;
      setState(() =>
          _imageAssistError = friendlyError(error, fallback: '图片识别咒文失败。'));
    } finally {
      if (mounted) {
        setState(() => _isRecognizingImagePrompt = false);
      }
    }
  }

  List<String> get _activeCandidates => _assistMode == _PromptAssistMode.idea
      ? _ideaCandidates
      : _imageCandidates;

  int get _activeCandidateIndex => _assistMode == _PromptAssistMode.idea
      ? _ideaCandidateIndex
      : _imageCandidateIndex;

  String? get _activeCandidate {
    final candidates = _activeCandidates;
    if (candidates.isEmpty) return null;
    final index = _activeCandidateIndex.clamp(0, candidates.length - 1).toInt();
    return candidates[index];
  }

  void _setActiveCandidateIndex(int index) {
    final candidates = _activeCandidates;
    if (candidates.isEmpty) return;
    final next = index.clamp(0, candidates.length - 1).toInt();
    setState(() {
      if (_assistMode == _PromptAssistMode.idea) {
        _ideaCandidateIndex = next;
      } else {
        _imageCandidateIndex = next;
      }
    });
    _applyCurrentCandidateIfSafe();
  }

  void _applyCurrentCandidateIfSafe() {
    final candidate = _activeCandidate;
    if (candidate == null || candidate.trim().isEmpty) return;
    final current = _spellController.text.trim();
    if (current.isNotEmpty && current != (_lastAppliedCandidate ?? '')) {
      showCenterNotice(context, '已生成候选，点击“使用/替换当前咒文”后再填入');
      return;
    }
    _replaceWithCurrentCandidate();
  }

  void _replaceWithCurrentCandidate() {
    final candidate = _activeCandidate;
    if (candidate == null || candidate.trim().isEmpty) {
      showCenterNotice(context, '当前没有可用候选');
      return;
    }
    _spellController.text = candidate.trim();
    _spellController.selection = TextSelection.collapsed(
      offset: _spellController.text.length,
    );
    _lastAppliedCandidate = _spellController.text;
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final capabilities = ref.watch(imageCapabilitiesProvider).valueOrNull ??
        ImageCapabilities.fallback();
    final options = capabilities.generate;
    final size = _safeValue(_size, options.sizes, options.defaultSize);
    final quality =
        _safeValue(_quality, options.qualities, options.defaultQuality);
    final background =
        _safeValue(_background, options.backgrounds, options.defaultBackground);
    final outputFormat = _safeValue(
      _outputFormat,
      capabilities.outputFormats,
      capabilities.outputFormats.first.value,
    );
    final mana = ref.watch(energyProvider);
    final generateQuota = mana['generate'];
    final remain = generateQuota['is_unlimited'] == true
        ? '无限'
        : '${generateQuota['remaining']} / ${generateQuota['total']}';

    final materializerState = ref.watch(generateImagesProvider);
    final activeTask = ref.watch(activeImageTaskProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(brand.generateTitle),
      ),
      body: BrandBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManaStatus(brand, remain),
              const SizedBox(height: 24),
              Text(
                brand.promptLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _buildPromptAssist(brand),
              const SizedBox(height: 12),
              TextField(
                controller: _spellController,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(hintText: brand.generatePromptHint),
              ),
              if (activeTask == ImageTaskKind.edit) ...[
                const SizedBox(height: 12),
                _buildTaskNotice('改图任务正在进行，请等待完成后再开始生图。'),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = (constraints.maxWidth - 12) / 2;
                  final menuWidth = fieldWidth;
                  return Row(
                    children: [
                      Expanded(
                        child: _dropdownField<int>(
                          label: '数量',
                          value: _count,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: List<int>.generate(
                                  options.maxImages, (index) => index + 1)
                              .map((e) =>
                                  CompactDropdownField.centeredItem<int>(
                                      e, '$e张', context))
                              .toList(),
                          selectedLabels: List<int>.generate(
                                  options.maxImages, (index) => index + 1)
                              .map((e) => '$e张')
                              .toList(),
                          onChanged: (value) => setState(() => _count = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdownField<String>(
                          label: '尺寸',
                          value: size,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: _items(options.sizes),
                          selectedLabels:
                              options.sizes.map((item) => item.label).toList(),
                          onChanged: (value) => setState(() => _size = value!),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = (constraints.maxWidth - 12) / 2;
                  final menuWidth = fieldWidth;
                  return Row(
                    children: [
                      Expanded(
                        child: _dropdownField<String>(
                          label: '质量',
                          value: quality,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: _items(options.qualities),
                          selectedLabels: options.qualities
                              .map((item) => item.label)
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _quality = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdownField<String>(
                          label: '背景',
                          value: background,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: _items(options.backgrounds),
                          selectedLabels: options.backgrounds
                              .map((item) => item.label)
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _background = value!),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return _dropdownField<String>(
                    label: '输出格式',
                    value: outputFormat,
                    width: constraints.maxWidth,
                    menuWidth: constraints.maxWidth,
                    items: _items(capabilities.outputFormats),
                    selectedLabels: capabilities.outputFormats
                        .map((item) => item.label)
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _outputFormat = value!),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: materializerState.isLoading
                      ? null
                      : () async {
                          final prompt = _spellController.text.trim();
                          if (prompt.isEmpty) {
                            showCenterNotice(context, '请先填写提示词');
                            return;
                          }
                          final currentTask = ref.read(activeImageTaskProvider);
                          if (currentTask == ImageTaskKind.edit) {
                            showCenterNotice(context, '改图任务进行中，请稍后再试');
                            return;
                          }
                          FocusScope.of(context).unfocus();
                          setState(() => _lastSubmittedPrompt = prompt);
                          try {
                            final notice = await ref
                                .read(generateImagesProvider.notifier)
                                .materialize(
                                  prompt,
                                  _count,
                                  size,
                                  quality,
                                  background,
                                  outputFormat,
                                );
                            if (!mounted || notice == null) return;
                            showCenterNotice(context, notice);
                          } catch (error) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(friendlyError(error))),
                            );
                          }
                        },
                  child: materializerState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(brand.generateButtonLabel,
                          style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 24),
              materializerState.when(
                data: (items) {
                  if (items.isEmpty) return const SizedBox();
                  return Column(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ImagePreviewScreen(
                                items: items
                                    .map(
                                      (result) => PreviewImageEntry(
                                        url: result['url']?.toString() ?? '',
                                        title: brand.generateActionLabel,
                                        caption: _lastSubmittedPrompt,
                                      ),
                                    )
                                    .where((entry) => entry.url.isNotEmpty)
                                    .toList(),
                                initialIndex: index,
                              ),
                            ),
                          ),
                          child: CachedGatewayImage(
                            url: item['url']?.toString() ?? '',
                            borderRadius: BorderRadius.circular(12),
                            fit: BoxFit.cover,
                            accentColor: brand.primaryColor,
                          ),
                        ),
                      );
                    }),
                  );
                },
                error: (err, _) => Text(
                  '${brand.generateErrorLabel}: ${friendlyError(err)}',
                  style: TextStyle(color: brand.warningColor),
                ),
                loading: () => Center(child: Text(brand.generateLoadingText)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptAssist(AppBrand brand) {
    final isIdea = _assistMode == _PromptAssistMode.idea;
    final isLoading =
        isIdea ? _isGeneratingIdeaPrompt : _isRecognizingImagePrompt;
    final error = isIdea ? _ideaAssistError : _imageAssistError;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.panelColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('根据思路生成'),
                selected: isIdea,
                onSelected: (_) =>
                    setState(() => _assistMode = _PromptAssistMode.idea),
              ),
              ChoiceChip(
                label: const Text('根据图片识别'),
                selected: !isIdea,
                onSelected: (_) =>
                    setState(() => _assistMode = _PromptAssistMode.image),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isIdea)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ideaController,
                    minLines: 1,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, height: 1.28),
                    decoration: const InputDecoration(
                      labelText: '简单想法',
                      hintText: '一个银发少女站在雪山上，二次元风格',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isLoading ? null : _generatePromptFromIdea,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: const Text('生成'),
                ),
              ],
            )
          else
            Row(
              children: [
                if (_assistImageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _assistImageFile!,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image_search_outlined,
                        color: brand.primaryColor),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _assistImageFile == null
                        ? '选择本地图片后反推 3 个咒文候选'
                        : '已选择图片，可重新识别或更换图片',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isLoading ? null : _pickAndRecognizeImagePrompt,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_search_outlined),
                  label: Text(_assistImageFile == null ? '选择' : '识别'),
                ),
              ],
            ),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(error, style: TextStyle(color: brand.warningColor)),
          ],
          _candidateSwitcher(brand),
        ],
      ),
    );
  }

  Widget _candidateSwitcher(AppBrand brand) {
    final candidates = _activeCandidates;
    if (candidates.isEmpty) return const SizedBox.shrink();
    final index = _activeCandidateIndex.clamp(0, candidates.length - 1).toInt();
    final candidate = candidates[index];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high, size: 18, color: brand.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '候选 ${index + 1}/${candidates.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '上一个',
                onPressed: index <= 0
                    ? null
                    : () => _setActiveCandidateIndex(index - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: '下一个',
                onPressed: index >= candidates.length - 1
                    ? null
                    : () => _setActiveCandidateIndex(index + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            candidate,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _replaceWithCurrentCandidate,
              icon: const Icon(Icons.input_outlined),
              label: const Text('使用/替换当前咒文'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManaStatus(AppBrand brand, String remain) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.panelColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: brand.successColor),
              const SizedBox(width: 12),
              Text(
                '${brand.generateQuotaLabel}: $remain',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            utcMidnightLocalResetHint(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  List<DropdownMenuItem<String>> _items(List<ImageOption> options) {
    return options
        .map(
          (item) => CompactDropdownField.centeredItem<String>(
            item.value,
            item.label,
            context,
          ),
        )
        .toList();
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required double width,
    double? menuWidth,
    required List<DropdownMenuItem<T>> items,
    required List<String> selectedLabels,
    required ValueChanged<T?> onChanged,
  }) {
    return CompactDropdownField<T>(
      label: label,
      value: value,
      width: width,
      menuWidth: menuWidth,
      items: items,
      selectedLabels: selectedLabels,
      onChanged: onChanged,
    );
  }

  String _safeValue(
      String current, List<ImageOption> options, String fallback) {
    return options.any((item) => item.value == current) ? current : fallback;
  }
}
