import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/image_capabilities.dart';
import '../../core/providers.dart';
import '../compendium/image_preview_screen.dart';

class ChronogearScreen extends ConsumerStatefulWidget {
  const ChronogearScreen({super.key});

  @override
  ConsumerState<ChronogearScreen> createState() => _ChronogearScreenState();
}

class _ChronogearScreenState extends ConsumerState<ChronogearScreen> {
  final TextEditingController _spellController = TextEditingController();
  File? _imageFile;
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final capabilities = ref.watch(imageCapabilitiesProvider).valueOrNull ??
        ImageCapabilities.fallback();
    final options = capabilities.edit;
    final size = _safeValue(_size, options.sizes, options.defaultSize);
    final quality = _safeValue(_quality, options.qualities, options.defaultQuality);
    final background = _safeValue(_background, options.backgrounds, options.defaultBackground);
    final outputFormat = _safeValue(
      _outputFormat,
      capabilities.outputFormats,
      capabilities.outputFormats.first.value,
    );
    final mana = ref.watch(energyProvider);
    final editQuota = mana['edit'];
    final remain = editQuota['is_unlimited'] == true ? '无限' : '${editQuota['remaining']} / ${editQuota['total']}';
    final materializerState = ref.watch(editImagesProvider);
    final activeTask = ref.watch(activeImageTaskProvider);

    return Scaffold(
      appBar: AppBar(title: Text(brand.editTitle)),
      body: BrandBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManaStatus(brand, remain),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: brand.panelColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: brand.primaryColor.withOpacity(0.5)),
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: brand.primaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(brand.pickImageText),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                brand.editPromptLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _spellController,
                maxLines: 3,
                decoration: InputDecoration(hintText: brand.editPromptHint),
              ),
              if (activeTask == ImageTaskKind.generate) ...[
                const SizedBox(height: 12),
                _buildTaskNotice('生图任务正在进行，请等待完成后再开始改图。'),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: DropdownButtonFormField<int>(
                    value: _count,
                    isExpanded: true,
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
                    decoration: const InputDecoration(labelText: '质量'),
                    items: _items(options.qualities),
                    onChanged: (v) => setState(() => _quality = v!),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: background,
                    isExpanded: true,
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
                decoration: const InputDecoration(labelText: '输出格式'),
                items: _items(capabilities.outputFormats),
                onChanged: (v) => setState(() => _outputFormat = v!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: materializerState.isLoading || _imageFile == null ? null : () async {
                    final prompt = _spellController.text.trim();
                    if (prompt.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先填写改图提示词。')),
                      );
                      return;
                    }
                    final currentTask = ref.read(activeImageTaskProvider);
                    if (currentTask == ImageTaskKind.generate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('生图任务进行中，请稍后再试。')),
                      );
                      return;
                    }
                    FocusScope.of(context).unfocus();
                    setState(() => _lastSubmittedPrompt = prompt);
                    try {
                      final notice = await ref.read(editImagesProvider.notifier).recall(
                            prompt,
                            _imageFile!.path,
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
                    : Text(brand.editButtonLabel, style: const TextStyle(fontSize: 18)),
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
                                        title: brand.editActionLabel,
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
                  '${brand.editErrorLabel}: ${friendlyError(err)}',
                  style: TextStyle(color: brand.warningColor),
                ),
                loading: () => Center(child: Text(brand.editLoadingText)),
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
          Icon(Icons.history_toggle_off, color: brand.successColor),
          const SizedBox(width: 12),
          Text(
            '${brand.editQuotaLabel}: $remain',
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
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
  }

  String _safeValue(String current, List<ImageOption> options, String fallback) {
    return options.any((item) => item.value == current) ? current : fallback;
  }
}
