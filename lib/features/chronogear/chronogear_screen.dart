import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_brand.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';

class ChronogearScreen extends ConsumerStatefulWidget {
  const ChronogearScreen({super.key});

  @override
  ConsumerState<ChronogearScreen> createState() => _ChronogearScreenState();
}

class _ChronogearScreenState extends ConsumerState<ChronogearScreen> {
  final TextEditingController _spellController = TextEditingController();
  File? _imageFile;
  int _count = 1;
  String _size = '1024x1024';

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
    final mana = ref.watch(energyProvider);
    final editQuota = mana['edit'];
    final remain = editQuota['is_unlimited'] == true ? '无限' : '${editQuota['remaining']} / ${editQuota['total']}';
    final materializerState = ref.watch(materializerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(brand.editTitle)),
      body: SingleChildScrollView(
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: materializerState.isLoading || _imageFile == null ? null : () {
                  ref.read(materializerProvider.notifier).recall(
                    _spellController.text, _imageFile!.path, _count, _size
                  );
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
                  children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CachedGatewayImage(
                      url: item['url'],
                      borderRadius: BorderRadius.circular(12),
                      fit: BoxFit.cover,
                      accentColor: brand.primaryColor,
                    ),
                  )).toList(),
                );
              },
              error: (err, _) => Text(
                '${brand.editErrorLabel}: $err',
                style: TextStyle(color: brand.warningColor),
              ),
              loading: () => Center(child: Text(brand.editLoadingText)),
            )
          ],
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
}
