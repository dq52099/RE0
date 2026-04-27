import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';

class GalleryDetailScreen extends ConsumerStatefulWidget {
  const GalleryDetailScreen({
    super.key,
    required this.initialPost,
  });

  final Map<String, dynamic> initialPost;

  @override
  ConsumerState<GalleryDetailScreen> createState() => _GalleryDetailScreenState();
}

class _GalleryDetailScreenState extends ConsumerState<GalleryDetailScreen> {
  late Map<String, dynamic> _post;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _isRefreshingComments = false;
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSubmittingComment = true);
    try {
      await ref
          .read(gatewayClientProvider)
          .addGalleryComment(_post['id'].toString(), text);
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _post['viewer_has_commented'] = true;
        _post['comment_count'] = (int.tryParse(_post['comment_count']?.toString() ?? '0') ?? 0) + 1;
      });
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('提示词已复制。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final canViewPrompt = _canViewPrompt(_post);
    return Scaffold(
      appBar: AppBar(
        title: Text(brand.galleryTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CachedGatewayImage(
                  url: _post['image_url']?.toString() ?? '',
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                  accentColor: brand.primaryColor,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _post['display_name']?.toString() ?? '-',
                              style: Theme.of(context).textTheme.titleMedium,
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
                      Row(
                        children: [
                          _actionButton(
                            icon: _post['liked'] == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            label: '${_post['like_count'] ?? 0}',
                            color: _post['liked'] == true ? brand.warningColor : null,
                            onTap: _toggleLike,
                          ),
                          const SizedBox(width: 8),
                          _actionButton(
                            icon: _post['favorited'] == true
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: '${_post['favorite_count'] ?? 0}',
                            color: _post['favorited'] == true ? brand.primaryColor : null,
                            onTap: _toggleFavorite,
                          ),
                          const SizedBox(width: 8),
                          _actionButton(
                            icon: Icons.content_copy_outlined,
                            label: '复制提示词',
                            onTap: canViewPrompt ? _copyPrompt : null,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    comment['display_name']?.toString() ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  _formatTime(comment['created_at']?.toString()),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(comment['content']?.toString() ?? ''),
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
    return item['viewer_has_commented'] == true ||
        item['user_id']?.toString() == currentUserId;
  }

  Widget _promptPanel(AppBrand brand, String prompt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brand.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.primaryColor.withOpacity(0.18)),
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
        color: brand.warningColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.warningColor.withOpacity(0.20)),
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
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
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
