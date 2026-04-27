import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/providers.dart';
import 'gallery_screen.dart';

class GalleryCollectionsScreen extends ConsumerWidget {
  const GalleryCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的画廊'),
          bottom: TabBar(
            tabs: [
              Tab(text: brand.favoriteTabLabel),
              const Tab(text: '点赞'),
              const Tab(text: '我的发布'),
            ],
          ),
        ),
        body: BrandBackground(
          child: const TabBarView(
            children: [
              GalleryFeedView(view: 'favorites', emptyText: '还没有收藏的作品'),
              GalleryFeedView(view: 'liked', emptyText: '还没有点赞的作品'),
              GalleryFeedView(view: 'mine', emptyText: '还没有发布到画廊的作品'),
            ],
          ),
        ),
      ),
    );
  }
}
