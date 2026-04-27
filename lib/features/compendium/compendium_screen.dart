import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';

final historyProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.read(gatewayClientProvider);
  final res = await client.getHistory(1);
  return res['items'] ?? [];
});

class CompendiumScreen extends ConsumerWidget {
  const CompendiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(brand.historyTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(historyProvider),
          ),
        ],
      ),
      body: historyState.when(
        data: (items) {
          if (items.isEmpty) return Center(child: Text(brand.emptyHistoryText));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['url'] != null)
                      CachedGatewayImage(
                        url: item['url'],
                        width: double.infinity,
                        borderRadius: brand.historyImageRadius,
                        fit: BoxFit.cover,
                        accentColor: brand.primaryColor,
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item['status'] == 'success'
                                      ? brand.successColor
                                      : brand.warningColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(item['status'] == 'success' ? '成功' : '失败', style: const TextStyle(fontSize: 12, color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item['action'] == 'generate'
                                    ? brand.generateActionLabel
                                    : brand.editActionLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(item['prompt'] ?? ''),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        error: (err, _) => Center(child: Text('无法读取记忆: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
