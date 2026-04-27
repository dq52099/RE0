import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/image_capabilities.dart';
import '../../core/providers.dart';
import '../compendium/image_preview_screen.dart';

class MaterializerScreen extends ConsumerStatefulWidget {
  const MaterializerScreen({super.key});

  @override
  ConsumerState<MaterializerScreen> createState() => _MaterializerScreenState();
}

class _MaterializerScreenState extends ConsumerState<MaterializerScreen> {
  final TextEditingController _spellController = TextEditingController();
  int _count = 1;
  String _size = 'auto';
  String _quality = 'high';
  String _background = 'auto';
  String _outputFormat = 'png';
  String _lastSubmittedPrompt = '';

  @override
  void dispose() {
    _spellController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final capabilities = ref.watch(imageCapabilitiesProvider).valueOrNull ??
        ImageCapabilities.fallback();
    final options = capabilities.generate;
    final size = _safeValue(_size, options.sizes, options.defaultSize);
    final quality = _safeValue(_quality, options.qualities, options.defaultQuality);
    final background = _safeValue(_background, options.backgrounds, options.defaultBackground);
    final outputFormat = _safeValue(
      _outputFormat,
      capabilities.outputFormats,
      capabilities.outputFormats.first.value,
    );
    final mana = ref.watch(energyProvider);
    final generateQuota = mana['generate'];
    final remain = generateQuota['is_unlimited'] == true ? '无限' : '${generateQuota['remaining']} / ${generateQuota['total']}';

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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    value: _count,
                    isExpanded: true,
                    alignment: Alignment.center,
                    decoration: const InputDecoration(labelText: '数量'),
                    items: List<int>.generate(options.maxImages, (index) => index + 1)
                        .map((e) => DropdownMenuItem(value: e, child: Text('$e张')))
                        .toList(),
                    onChanged: (v) => setState(() => _count = v!),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: size,
                    isExpanded: true,
                    alignment: Alignment.center,
                    decoration: const InputDecoration(labelText: '尺寸'),
                    items: _items(options.sizes),
                    onChanged: (v) => setState(() => _size = v!),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: quality,
                    isExpanded: true,
                    alignment: Alignment.center,
                    decoration: const InputDecoration(labelText: '质量'),
                    items: _items(options.qualities),
                    onChanged: (v) => setState(() => _quality = v!),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: background,
                    isExpanded: true,
                    alignment: Alignment.center,
                    decoration: const InputDecoration(labelText: '背景'),
                    items: _items(options.backgrounds),
                    onChanged: (v) => setState(() => _background = v!),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: outputFormat,
                isExpanded: true,
                alignment: Alignment.center,
                decoration: const InputDecoration(labelText: '输出格式'),
                items: _items(capabilities.outputFormats),
                onChanged: (v) => setState(() => _outputFormat = v!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: materializerState.isLoading ? null : () async {
                    final prompt = _spellController.text.trim();
                    if (prompt.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先填写提示词。')),
                      );
                      return;
                    }
                    final currentTask = ref.read(activeImageTaskProvider);
                    if (currentTask == ImageTaskKind.edit) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('改图任务进行中，请稍后再试。')),
                      );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(notice)),
                      );
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyError(error))),
                      );
                    }
                  },
                  child: materializerState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(brand.generateButtonLabel, style: const TextStyle(fontSize: 18)),
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

  Widget _buildManaStatus(AppBrand brand, String remain) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.panelColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: brand.successColor),
          const SizedBox(width: 12),
          Text(
            '${brand.generateQuotaLabel}: $remain',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  List<DropdownMenuItem<String>> _items(List<ImageOption> options) {
    return options
        .map(
          (item) => DropdownMenuItem<String>(
            value: item.value,
            child: Center(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        )
        .toList();
  }

  String _safeValue(String current, List<ImageOption> options, String fallback) {
    return options.any((item) => item.value == current) ? current : fallback;
  }
}
