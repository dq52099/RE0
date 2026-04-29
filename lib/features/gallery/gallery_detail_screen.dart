import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/compact_save_notice.dart';
import '../../core/image_save_flow.dart';
import '../../core/providers.dart';
import '../../core/value_parsers.dart';
import '../compendium/image_preview_screen.dart';

class GalleryDetailScreen extends ConsumerStatefulWidget {
  const GalleryDetailScreen({
    super.key,
    required this.initialPost,
  });

  final Map<String, dynamic> initialPost;

  @override
  ConsumerState<GalleryDetailScreen> createState() =>
      _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends ConsumerState<GalleryDetailScreen> {
  late Map<String, dynamic> _post;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _isRefreshingComments = false;
  bool _isDownloading = false;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.initialPost);
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isRefreshingComments = true);
    try {
      final comments = await ref
          .read(gatewayClientProvider)
          .getGalleryComments(_post['id'].toString());
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (_) {
      // Keep current comments if refresh fails.
    } finally {
      if (mounted) {
        setState(() => _isRefreshingComments = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      final updated = await ref
          .read(gatewayClientProvider)
          .toggleGalleryLike(_post['id'].toString());
      if (!mounted) return;
      setState(() => _post = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final updated = await ref
          .read(gatewayClientProvider)
          .toggleGalleryFavorite(_post['id'].toString());
      if (!mounted) return;
      setState(() => _post = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    if (!boolish(_post['can_download'])) {
      showCenterNotice(context, '评论后才可以下载');
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final saved = await saveImageWithUserFlow(
        context,
        ref,
        _post['image_url']?.toString() ?? '',
      );
      if (saved == null) return;
      final updated = await ref
          .read(gatewayClientProvider)
          .recordGalleryDownload(_post['id'].toString());
      if (!mounted) return;
      setState(() => _post = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await ref.read(gatewayClientProvider).deleteGalleryComment(commentId);
      if (!mounted) return;
      await _loadComments();
      setState(() {
        final next =
            (int.tryParse(_post['comment_count']?.toString() ?? '1') ?? 1) - 1;
        _post['comment_count'] = next < 0 ? 0 : next;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  Future<void> _unpublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除画廊作品'),
        content: const Text('删除后会从画廊移除该作品，并撤销该作品产生的积分。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(gatewayClientProvider)
          .deleteGalleryPost(_post['id'].toString());
      if (!mounted) return;
      showCenterNotice(context, '作品已删除');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSubmittingComment = true);
    try {
      await ref
          .read(gatewayClientProvider)
          .addGalleryComment(_post['id'].toString(), text);
      final updated = await ref
          .read(gatewayClientProvider)
          .getGalleryPost(_post['id'].toString());
      if (!mounted) return;
      _commentController.clear();
      setState(() => _post = updated);
      await _loadComments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _copyPrompt() async {
    final prompt = _post['prompt']?.toString() ?? '';
    if (prompt.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    showCenterNotice(context, '提示词已复制');
  }

  Future<void> _openImage() async {
    final url = _post['image_url']?.toString() ?? '';
    if (url.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          items: [
            PreviewImageEntry(
              url: url,
              title: _post['display_name']?.toString(),
              caption: _post['prompt']?.toString(),
            ),
          ],
          initialIndex: 0,
          showDownload: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final canViewPrompt = _canViewPrompt(_post);
    final currentUser = ref.read(authStateProvider);
    final isOwner =
        currentUser?['id']?.toString() == _post['user_id']?.toString();
    final canDelete = boolish(_post['can_delete']) || isOwner;
    final liked = boolish(_post['liked']);
    final favorited = boolish(_post['favorited']);
    return Scaffold(
      appBar: AppBar(
        title: Text(brand.galleryTitle),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: '删除作品',
              icon: const Icon(Icons.delete_outline),
              onPressed: _unpublish,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _openImage,
                  child: CachedGatewayImage(
                    url: _post['image_url']?.toString() ?? '',
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                    showDownload: false,
                    accentColor: brand.primaryColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _authorAvatar(
                            avatarUrl:
                                _post['author_avatar_url']?.toString() ?? '',
                            displayName:
                                _post['display_name']?.toString() ?? '-',
                            radius: 18,
                            fallback: '画',
                            brand: brand,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _post['display_name']?.toString() ?? '-',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                _levelBadge(_post['level_info'] as Map?),
                              ],
                            ),
                          ),
                          Text(
                            _post['action']?.toString() == 'generate'
                                ? brand.generateActionLabel
                                : brand.editActionLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(_post['created_at']?.toString()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (canViewPrompt)
                        _promptPanel(brand, _post['prompt']?.toString() ?? '')
                      else
                        _lockedPromptPanel(brand),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _actionButton(
                            icon:
                                liked ? Icons.favorite : Icons.favorite_border,
                            label: '${_post['like_count'] ?? 0}',
                            color: liked ? brand.warningColor : null,
                            onTap: _toggleLike,
                          ),
                          _actionButton(
                            icon: favorited
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: '${_post['favorite_count'] ?? 0}',
                            color: favorited ? brand.primaryColor : null,
                            onTap: _toggleFavorite,
                          ),
                          _actionButton(
                            icon: Icons.content_copy_outlined,
                            label: '复制提示词',
                            onTap: canViewPrompt ? _copyPrompt : null,
                          ),
                          _actionButton(
                            icon: Icons.download_outlined,
                            label: '下载 ${_post['download_count'] ?? 0}',
                            onTap: _isDownloading ? null : _downloadImage,
                            busy: _isDownloading,
                          ),
                          if (canDelete)
                            _actionButton(
                              icon: Icons.delete_outline,
                              label: '删除',
                              color: brand.warningColor,
                              onTap: _unpublish,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '评论',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (_isRefreshingComments)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '评论',
                      hintText: '发表评论后可查看提示词',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmittingComment ? null : _submitComment,
                      child: _isSubmittingComment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('发表评论'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: Text('还没有评论')),
                    )
                  else
                    ..._comments.map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _authorAvatar(
                              avatarUrl:
                                  comment['author_avatar_url']?.toString() ??
                                      '',
                              displayName:
                                  comment['display_name']?.toString() ?? '-',
                              radius: 18,
                              fallback: '评',
                              brand: brand,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              comment['display_name']
                                                      ?.toString() ??
                                                  '-',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            _levelBadge(
                                                comment['level_info'] as Map?),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatTime(
                                            comment['created_at']?.toString()),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      if (boolish(comment['can_delete']))
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: '删除评论',
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18),
                                          onPressed: () => _deleteComment(
                                              comment['id'].toString()),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(comment['content']?.toString() ?? ''),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canViewPrompt(Map<String, dynamic> item) {
    final currentUser = ref.read(authStateProvider);
    final currentUserId = currentUser?['id']?.toString();
    return boolish(item['viewer_has_commented']) ||
        item['user_id']?.toString() == currentUserId;
  }

  Widget _promptPanel(AppBrand brand, String prompt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        prompt,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _lockedPromptPanel(AppBrand brand) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.warningColor.withValues(alpha: 0.20)),
      ),
      child: Text(
        '发表评论后可查看并复制提示词。',
        style: TextStyle(color: brand.warningColor),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
    bool busy = false,
  }) {
    final activeColor = color;
    final foregroundColor = activeColor != null
        ? Colors.white
        : Theme.of(context).textTheme.bodySmall?.color;
    final surface = Theme.of(context).colorScheme.surface;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: activeColor != null
              ? activeColor
              : surface.withValues(alpha: 0.5),
          border: Border.all(
            color: activeColor != null ? activeColor : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: activeColor != null
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(
                icon,
                size: 16,
                color: foregroundColor,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelBadge(Map? levelInfo) {
    final label = levelInfo?['label']?.toString();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = _badgeColor(levelInfo?['badge_color']?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _authorAvatar({
    required String avatarUrl,
    required String displayName,
    required double radius,
    required String fallback,
    required AppBrand brand,
  }) {
    final normalizedUrl = avatarUrl.trim();
    final normalizedName = displayName.trim();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: brand.primaryColor.withValues(alpha: 0.14),
      backgroundImage:
          normalizedUrl.isNotEmpty ? NetworkImage(normalizedUrl) : null,
      child: normalizedUrl.isEmpty
          ? Text(
              normalizedName.isEmpty
                  ? fallback
                  : normalizedName.substring(0, 1),
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
    );
    if (normalizedUrl.isEmpty) return avatar;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _openAvatarPreview(normalizedUrl, normalizedName),
      child: avatar,
    );
  }

  void _openAvatarPreview(String avatarUrl, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          showDownload: false,
          items: [
            PreviewImageEntry(
              url: avatarUrl,
              title: title.isEmpty ? '头像' : '$title 的头像',
            ),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(String? value) {
    if (value == null || value.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.parse(normalized, radix: 16));
  }

  String _formatTime(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
