import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_brand.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';

class MaterializerScreen extends ConsumerStatefulWidget {
  const MaterializerScreen({super.key});

  @override
  ConsumerState<MaterializerScreen> createState() => _MaterializerScreenState();
}

class _MaterializerScreenState extends ConsumerState<MaterializerScreen> {
  final TextEditingController _spellController = TextEditingController();
  int _count = 1;
  String _size = '1024x1024';
  String _quality = 'high';
  String _background = 'auto';

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final mana = ref.watch(energyProvider);
    final generateQuota = mana['generate'];
    final remain = generateQuota['is_unlimited'] == true ? '无限' : '${generateQuota['remaining']} / ${generateQuota['total']}';

    final materializerState = ref.watch(materializerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(brand.generateTitle),
      ),
      body: SingleChildScrollView(
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
              decoration: InputDecoration(hintText: brand.generatePromptHint),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: DropdownButtonFormField<int>(
                  value: _count,
                  decoration: const InputDecoration(labelText: '数量'),
                  items: [1,2,3,4].map((e) => DropdownMenuItem(value: e, child: Text('$e张'))).toList(),
                  onChanged: (v) => setState(() => _count = v!),
                )),
                const SizedBox(width: 16),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _size,
                  decoration: const InputDecoration(labelText: '尺寸'),
                  items: ['1024x1024', '1024x1536', '1536x1024'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _size = v!),
                )),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: materializerState.isLoading ? null : () {
                  ref.read(materializerProvider.notifier).materialize(
                    _spellController.text, _count, _size, _quality, _background
                  );
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
                '${brand.generateErrorLabel}: $err',
                style: TextStyle(color: brand.warningColor),
              ),
              loading: () => Center(child: Text(brand.generateLoadingText)),
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
}
