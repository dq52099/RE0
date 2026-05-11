import 'dart:async';
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
import '../../core/image_quota_price_line.dart';
import '../../core/prompt_assist_copy.dart';
import '../../core/providers.dart';
import '../../core/timezone_reset_hint.dart';
import '../compendium/image_preview_screen.dart';

enum _PromptAssistMode {
  idea,
  image,
}

String _defaultAspectRatioForDevice(BuildContext context) {
  final media = MediaQuery.of(context);
  final size = media.size;
  final shortestSide = size.shortestSide;
  final isPortrait = size.height >= size.width;
  if (isPortrait || shortestSide < 600) return '9:16';
  return '16:9';
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
  String _resolutionTier = 'auto';
  String _aspectRatio = 'auto';
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

  void _dismissPromptAssistFocus([BuildContext? focusContext]) {
    FocusManager.instance.primaryFocus?.unfocus(
      disposition: UnfocusDisposition.scope,
    );
    FocusScope.of(focusContext ?? context).unfocus(
      disposition: UnfocusDisposition.scope,
    );
  }

  Future<void> _generatePromptFromIdea() async {
    final brand = ref.read(brandProvider);
    final copy = promptAssistCopyFor(brand);
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      showCenterNotice(context, '请先写下${brand.generateActionLabel}思路');
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
          _ideaAssistError = copy.generateNoResult;
        });
        return;
      }
      setState(() {
        _ideaCandidates = candidates;
        _ideaCandidateIndex = 0;
      });
      showCenterNotice(context, copy.generateReady);
    } catch (error) {
      if (!mounted) return;
      setState(() => _ideaAssistError =
          friendlyError(error, fallback: copy.generateFailure));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingIdeaPrompt = false);
      }
    }
  }

  Future<void> _pickAssistImagePrompt() async {
    final picked = await _assistImagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() {
      _assistMode = _PromptAssistMode.image;
      _assistImageFile = File(picked.path);
      _imageCandidates = const [];
      _imageCandidateIndex = 0;
      _imageAssistError = null;
      _lastAppliedCandidate = null;
    });
  }

  Future<void> _recognizeSelectedImagePrompt() async {
    final copy = promptAssistCopyFor(ref.read(brandProvider));
    final imageFile = _assistImageFile;
    if (imageFile == null) {
      showCenterNotice(context, '请先选择参考图');
      return;
    }
    _dismissPromptAssistFocus();
    setState(() {
      _assistMode = _PromptAssistMode.image;
      _isRecognizingImagePrompt = true;
      _imageAssistError = null;
    });
    try {
      final candidates = await ref
          .read(gatewayClientProvider)
          .identifyImagePromptCandidates(imageFile.path);
      if (!mounted) return;
      if (candidates.isEmpty) {
        setState(() {
          _imageCandidates = const [];
          _imageCandidateIndex = 0;
          _imageAssistError = copy.imageNoResult;
        });
        return;
      }
      setState(() {
        _imageCandidates = candidates;
        _imageCandidateIndex = 0;
      });
      showCenterNotice(context, copy.imageReady);
    } catch (error) {
      if (!mounted) return;
      setState(() => _imageAssistError =
          friendlyError(error, fallback: copy.imageFailure));
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
  }

  void _replaceWithCurrentCandidate() {
    final copy = promptAssistCopyFor(ref.read(brandProvider));
    final candidate = _activeCandidate;
    if (candidate == null || candidate.trim().isEmpty) {
      showCenterNotice(context, copy.generateNoCurrent);
      return;
    }
    _dismissPromptAssistFocus();
    setState(() {
      _spellController.text = candidate.trim();
      _spellController.selection = TextSelection.collapsed(
        offset: _spellController.text.length,
      );
      _lastAppliedCandidate = _spellController.text;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dismissPromptAssistFocus();
    });
  }

  Future<void> _generateWithCandidate(String candidate) async {
    final brand = ref.read(brandProvider);
    final copy = promptAssistCopyFor(brand);
    final prompt = candidate.trim();
    if (prompt.isEmpty) {
      showCenterNotice(context, copy.generateEmptyCurrent);
      return;
    }
    final activeTask = ref.read(activeImageTaskProvider);
    if (activeTask == ImageTaskKind.generate) {
      showCenterNotice(context, copy.generateBusy(brand));
      return;
    }
    if (activeTask == ImageTaskKind.edit) {
      showCenterNotice(context, copy.editBusy(brand));
      return;
    }
    final capabilities = ref.read(imageCapabilitiesProvider).valueOrNull ??
        ImageCapabilities.fallback();
    final options = capabilities.generate;
    final size = resolveSizeForResolutionAndAspect(
      options.sizes,
      _resolutionTier,
      _aspectRatio,
      _defaultAspectRatioForDevice(context),
    );
    final quality =
        _safeValue(_quality, options.qualities, options.defaultQuality);
    final background =
        _safeValue(_background, options.backgrounds, options.defaultBackground);
    final outputFormat = _safeValue(
      _outputFormat,
      capabilities.outputFormats,
      capabilities.outputFormats.first.value,
    );
    final selectedMode = _selectedImageMode(capabilities);
    final retention = ref.read(historyRetentionProvider);
    final generateRetention = retention['generate'] as Map? ?? {};
    final retentionMessage = _retentionLimitMessage(generateRetention, 1);
    if (retentionMessage != null) {
      showCenterNotice(context, retentionMessage);
      return;
    }
    _dismissPromptAssistFocus();
    setState(() => _lastSubmittedPrompt = prompt);
    try {
      final notice =
          await ref.read(generateImagesProvider.notifier).materialize(
                prompt,
                1,
                size,
                quality,
                background,
                outputFormat,
                selectedMode,
              );
      if (!mounted || notice == null) return;
      showCenterNotice(context, notice);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  Future<void> _generateWithAllCandidates() async {
    final brand = ref.read(brandProvider);
    final copy = promptAssistCopyFor(brand);
    final prompts = _activeCandidates
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (prompts.isEmpty) {
      showCenterNotice(context, copy.generateNoCurrent);
      return;
    }
    final activeTask = ref.read(activeImageTaskProvider);
    if (activeTask == ImageTaskKind.generate) {
      showCenterNotice(context, copy.generateBusy(brand));
      return;
    }
    if (activeTask == ImageTaskKind.edit) {
      showCenterNotice(context, copy.editBusy(brand));
      return;
    }
    final capabilities = ref.read(imageCapabilitiesProvider).valueOrNull ??
        ImageCapabilities.fallback();
    final options = capabilities.generate;
    final size = resolveSizeForResolutionAndAspect(
      options.sizes,
      _resolutionTier,
      _aspectRatio,
      _defaultAspectRatioForDevice(context),
    );
    final quality =
        _safeValue(_quality, options.qualities, options.defaultQuality);
    final background =
        _safeValue(_background, options.backgrounds, options.defaultBackground);
    final outputFormat = _safeValue(
      _outputFormat,
      capabilities.outputFormats,
      capabilities.outputFormats.first.value,
    );
    final selectedMode = _selectedImageMode(capabilities);
    final retention = ref.read(historyRetentionProvider);
    final generateRetention = retention['generate'] as Map? ?? {};
    final retentionMessage =
        _retentionLimitMessage(generateRetention, prompts.length);
    if (retentionMessage != null) {
      showCenterNotice(context, retentionMessage);
      return;
    }
    _dismissPromptAssistFocus();
    setState(() => _lastSubmittedPrompt = prompts.join('\n---\n'));
    showCenterNotice(context, copy.generateBatchNotice(prompts.length));
    try {
      final notice =
          await ref.read(generateImagesProvider.notifier).materializePrompts(
                prompts,
                size,
                quality,
                background,
                outputFormat,
                selectedMode,
              );
      if (!mounted || notice == null) return;
      showCenterNotice(context, notice);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  Future<void> _openAllCandidatesDialog(AppBrand brand) async {
    final copy = promptAssistCopyFor(brand);
    final candidates = _activeCandidates;
    if (candidates.isEmpty) return;
    _dismissPromptAssistFocus();
    await showDialog<void>(
      context: context,
      builder: (context) {
        final media = MediaQuery.of(context);
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: media.size.height * 0.72,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            copy.generateAllTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    brand.primaryColor.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '第 ${index + 1} 条',
                                  style: TextStyle(color: brand.primaryColor),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  candidate,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _setActiveCandidateIndex(index);
                                        _replaceWithCurrentCandidate();
                                      },
                                      icon: const Icon(
                                        Icons.input_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('填入'),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _setActiveCandidateIndex(index);
                                        unawaited(
                                            _generateWithCandidate(candidate));
                                      },
                                      icon: const Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 18,
                                      ),
                                      label: Text(copy.generateUseThisLabel()),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            copy.generateCountLabel(candidates.length),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            unawaited(_generateWithAllCandidates());
                          },
                          icon: const Icon(
                            Icons.auto_awesome_motion_outlined,
                            size: 18,
                          ),
                          label:
                              Text(copy.generateBatchLabel(candidates.length)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    _dismissPromptAssistFocus();
  }

  Future<void> _openCandidatePrompt(String candidate) async {
    _dismissPromptAssistFocus();
    final brand = ref.read(brandProvider);
    final copy = promptAssistCopyFor(brand);
    final controller = TextEditingController(text: candidate);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.generateFullTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: false,
            minLines: 8,
            maxLines: 14,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: brand.generatePromptHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              _dismissPromptAssistFocus(context);
              Navigator.pop(context, controller.text.trim());
            },
            child: Text(copy.fillGenerate),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) {
      _dismissPromptAssistFocus();
      return;
    }
    _dismissPromptAssistFocus();
    setState(() {
      _spellController.text = next;
      _spellController.selection = TextSelection.collapsed(
        offset: _spellController.text.length,
      );
      if (_spellController.text != (_lastAppliedCandidate ?? '')) {
        _lastAppliedCandidate = _spellController.text;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dismissPromptAssistFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final copy = promptAssistCopyFor(brand);
    final capabilities = ref.watch(imageCapabilitiesProvider).valueOrNull ??
        ImageCapabilities.fallback();
    final options = capabilities.generate;
    final size = resolveSizeForResolutionAndAspect(
      options.sizes,
      _resolutionTier,
      _aspectRatio,
      _defaultAspectRatioForDevice(context),
    );
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
    final retention = ref.watch(historyRetentionProvider);
    final generateRetention = retention['generate'] as Map? ?? {};
    final retentionText = _retentionText(generateRetention);
    final selectedMode = _selectedImageMode(capabilities);

    final materializerState = ref.watch(generateImagesProvider);
    final activeTask = ref.watch(activeImageTaskProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(brand.generateTitle),
      ),
      body: BrandBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManaStatus(brand, remain, retentionText, capabilities),
              const SizedBox(height: 24),
              Text(
                brand.promptLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _buildPromptAssist(brand),
              const SizedBox(height: 12),
              _buildPromptField(brand),
              if (activeTask == ImageTaskKind.edit) ...[
                const SizedBox(height: 12),
                _buildTaskNotice(copy.editBlocksGenerate(brand)),
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
                          label: '清晰度',
                          value: _resolutionTier,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: _resolutionItems(),
                          selectedLabels: imageResolutionTiers
                              .map((item) => item.label)
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _resolutionTier = value!),
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
                          label: '尺寸',
                          value: _aspectRatio,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: _aspectItems(),
                          selectedLabels: imageAspectRatioOptions
                              .map((item) => item.label)
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _aspectRatio = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdownField<String>(
                          label: '输出格式',
                          value: outputFormat,
                          width: fieldWidth,
                          menuWidth: menuWidth,
                          items: _items(capabilities.outputFormats),
                          selectedLabels: capabilities.outputFormats
                              .map((item) => item.label)
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _outputFormat = value!),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: activeTask == ImageTaskKind.generate
                      ? null
                      : () async {
                          final prompt = _spellController.text.trim();
                          if (prompt.isEmpty) {
                            showCenterNotice(context, copy.writeGenerate);
                            return;
                          }
                          final currentTask = ref.read(activeImageTaskProvider);
                          if (currentTask == ImageTaskKind.edit) {
                            showCenterNotice(context, copy.editBusy(brand));
                            return;
                          }
                          final retentionMessage = _retentionLimitMessage(
                            generateRetention,
                            _count,
                          );
                          if (retentionMessage != null) {
                            showCenterNotice(context, retentionMessage);
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
                                  selectedMode,
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
                  child: activeTask == ImageTaskKind.generate
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
                          child: _resultImageCard(brand, item),
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
    final copy = promptAssistCopyFor(brand);
    final isIdea = _assistMode == _PromptAssistMode.idea;
    final isLoading =
        isIdea ? _isGeneratingIdeaPrompt : _isRecognizingImagePrompt;
    final error = isIdea ? _ideaAssistError : _imageAssistError;
    const loadingIndicator = SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final actionBarDecoration = BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: brand.primaryColor.withValues(alpha: 0.1)),
    );
    final primaryButtonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      minimumSize: const Size(0, 40),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final imageButtonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      minimumSize: const Size(128, 46),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
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
                label: Text(copy.ideaChip),
                selected: isIdea,
                onSelected: (_) =>
                    setState(() => _assistMode = _PromptAssistMode.idea),
              ),
              ChoiceChip(
                label: Text(copy.imageChip),
                selected: !isIdea,
                onSelected: (_) =>
                    setState(() => _assistMode = _PromptAssistMode.image),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isIdea)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ideaController,
                  minLines: 1,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, height: 1.28),
                  decoration: InputDecoration(
                    labelText: '${brand.generateActionLabel}思路',
                    hintText: brand.generatePromptHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: actionBarDecoration,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: primaryButtonStyle,
                        onPressed: isLoading ? null : _generatePromptFromIdea,
                        icon: isLoading
                            ? loadingIndicator
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(copy.ideaAction),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _referenceImageThumb(
                      file: _assistImageFile,
                      brand: brand,
                      title: '参考图详情',
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _assistImageFile == null
                            ? copy.imageEmptyText
                            : copy.imageSelectedText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: actionBarDecoration,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: imageButtonStyle,
                        onPressed: isLoading ? null : _pickAssistImagePrompt,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _assistImageFile == null ? '选择' : '更换',
                        ),
                      ),
                      FilledButton.icon(
                        style: primaryButtonStyle,
                        onPressed:
                            isLoading ? null : _recognizeSelectedImagePrompt,
                        icon: isLoading
                            ? loadingIndicator
                            : const Icon(Icons.image_search_outlined),
                        label: Text(copy.imageInferVerb),
                      ),
                    ],
                  ),
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

  Widget _referenceImageThumb({
    required File? file,
    required AppBrand brand,
    required String title,
  }) {
    final hasFile = file != null;
    final preview = Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 64,
        height: 64,
        child: hasFile
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      alignment: Alignment.center,
                      child: const Text(
                        '详情',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              )
            : Icon(Icons.image_search_outlined, color: brand.primaryColor),
      ),
    );
    if (!hasFile) return preview;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openReferenceImagePreview(file, title),
        child: preview,
      ),
    );
  }

  void _openReferenceImagePreview(File file, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          items: [
            PreviewImageEntry(
              url: '',
              filePath: file.path,
              title: title,
            ),
          ],
          showDownload: false,
        ),
      ),
    );
  }

  Widget _buildPromptField(AppBrand brand) {
    return TextField(
      controller: _spellController,
      minLines: 4,
      maxLines: 8,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: (value) {
        if (value.trim() != (_lastAppliedCandidate ?? '')) {
          _lastAppliedCandidate = null;
        }
      },
      decoration: InputDecoration(
        hintText: brand.generatePromptHint,
        fillColor:
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
        filled: true,
        suffixIcon: const Icon(Icons.edit_note_outlined),
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.38,
          ),
    );
  }

  Widget _candidateText(String candidate) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openCandidatePrompt(candidate),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  candidate,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_full,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _candidateSwitcher(AppBrand brand) {
    final copy = promptAssistCopyFor(brand);
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
                  copy.generateSwitcherLabel(index, candidates.length),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => _openAllCandidatesDialog(brand),
                child: const Text('查看全部'),
              ),
              IconButton(
                tooltip: copy.previousGenerateTooltip(),
                onPressed: index <= 0
                    ? null
                    : () => _setActiveCandidateIndex(index - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: copy.nextGenerateTooltip(),
                onPressed: index >= candidates.length - 1
                    ? null
                    : () => _setActiveCandidateIndex(index + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _candidateText(candidate),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _replaceWithCurrentCandidate,
                icon: const Icon(Icons.input_outlined, size: 18),
                label: const Text('填入'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManaStatus(
    AppBrand brand,
    String remain,
    String retentionText,
    ImageCapabilities capabilities,
  ) {
    final selectedMode = _selectedImageMode(capabilities);
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
              Expanded(
                child: Text(
                  '${brand.generateQuotaLabel}: $remain',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.collections_bookmark_outlined,
                  size: 18, color: brand.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${brand.generateActionLabel} 记忆: $retentionText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (capabilities.imageModes.canSwitch) ...[
            _buildImageModeSwitchRow(brand, capabilities, selectedMode),
            const SizedBox(height: 8),
          ],
          _buildImageModePriceRow(brand, capabilities),
          const SizedBox(height: 8),
          Text(
            utcMidnightLocalResetHint(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildImageModeSwitchRow(
    AppBrand brand,
    ImageCapabilities capabilities,
    String selectedMode,
  ) {
    return Row(
      children: [
        Icon(Icons.alt_route_rounded, size: 18, color: brand.primaryColor),
        const SizedBox(width: 12),
        Text(
          '线路:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'vip', label: Text('VIP')),
            ButtonSegment(value: 'general', label: Text('一般')),
          ],
          selected: {selectedMode},
          onSelectionChanged: (values) {
            final next = values.first;
            ref.read(selectedImageModeProvider.notifier).state = next;
            ref.read(selectedImageModeBaseProvider.notifier).state =
                capabilities.imageModes.current;
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: WidgetStateProperty.all(
              Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageModePriceRow(
    AppBrand brand,
    ImageCapabilities capabilities,
  ) {
    return Row(
      children: [
        Icon(Icons.route_outlined, size: 18, color: brand.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: ImageQuotaPriceLine(
            capabilities: capabilities.imageModes,
            accentColor: brand.primaryColor,
          ),
        ),
      ],
    );
  }

  String _selectedImageMode(ImageCapabilities capabilities) {
    final selected = ref.watch(selectedImageModeProvider);
    final selectedBase = ref.watch(selectedImageModeBaseProvider);
    final userMode = imageModeFromUser(ref.watch(authStateProvider));
    if (selectedBase != null &&
        selectedBase != capabilities.imageModes.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedImageModeProvider.notifier).state = null;
        ref.read(selectedImageModeBaseProvider.notifier).state = null;
      });
      return userMode ?? capabilities.imageModes.current;
    }
    if (selected != null &&
        selectedBase != null &&
        capabilities.imageModes.allowed.contains(selected)) {
      return selected;
    }
    if (userMode != null) return userMode;
    return capabilities.imageModes.current;
  }

  Widget _resultImageCard(
    AppBrand brand,
    Map<String, dynamic> item,
  ) {
    final modeLabel = imageModeLabelFromItem(item);
    final channelLabel = _channelLabel(item);
    return Stack(
      children: [
        CachedGatewayImage(
          url: item['url']?.toString() ?? '',
          borderRadius: BorderRadius.circular(12),
          fit: BoxFit.cover,
          accentColor: brand.primaryColor,
          cacheWidth: 900,
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: _resultRouteBadge(modeLabel, channelLabel),
        ),
      ],
    );
  }

  Widget _resultRouteBadge(String modeLabel, String channelLabel) {
    final text = channelLabel.isEmpty
        ? '模式 $modeLabel'
        : '模式 $modeLabel·通道 $channelLabel';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 156),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _channelLabel(Map<String, dynamic> item) {
    final explicit = item['provider_slot_label']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final slot = item['provider_slot']?.toString().trim().toLowerCase();
    if (slot == 'primary') return '主用';
    if (slot == 'backup') return '备用';
    if (slot == 'general') return '一般';
    return '';
  }

  String _retentionText(Map quota) {
    if (quota['is_unlimited'] == true) {
      return '无限';
    }
    return '${quota['remaining'] ?? 0}/${quota['total'] ?? 0}';
  }

  String? _retentionLimitMessage(Map quota, int requested) {
    if (quota['is_unlimited'] == true) {
      return null;
    }
    final remaining = int.tryParse(quota['remaining']?.toString() ?? '') ?? 0;
    if (remaining >= requested) {
      return null;
    }
    final used = quota['used'] ?? 0;
    final total = quota['total'] ?? 0;
    final copy = promptAssistCopyFor(ref.read(brandProvider));
    return copy.generateRetentionLimitMessage(
      brand: ref.read(brandProvider),
      used: used,
      total: total,
      requested: requested,
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

  List<DropdownMenuItem<String>> _resolutionItems() {
    return imageResolutionTiers
        .map(
          (item) => CompactDropdownField.centeredItem<String>(
            item.value,
            item.label,
            context,
          ),
        )
        .toList();
  }

  List<DropdownMenuItem<String>> _aspectItems() {
    return imageAspectRatioOptions
        .map(
          (item) => CompactDropdownField.centeredItem<String>(
            item.value,
            item.label,
            context,
          ),
        )
        .toList();
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
