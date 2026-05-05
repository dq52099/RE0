import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/compact_save_notice.dart';
import '../../core/image_save_flow.dart';
import '../../core/local_time_format.dart';
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
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmittingComment = false;
  bool _isRefreshingComments = false;
  bool _isDownloading = false;
  bool _isCommentComposerExpanded = false;
  String? _replyingToName;
  String? _replyingToCommentId;
  String? _replyingToSnippet;
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
    _commentFocusNode.dispose();
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
      await ref.read(gatewayClientProvider).addGalleryComment(
            _post['id'].toString(),
            text,
            parentCommentId: _replyingToCommentId,
          );
      final updated = await ref
          .read(gatewayClientProvider)
          .getGalleryPost(_post['id'].toString());
      if (!mounted) return;
      _commentController.clear();
      _replyingToName = null;
      _replyingToCommentId = null;
      _replyingToSnippet = null;
      setState(() {
        _post = updated;
        _isCommentComposerExpanded = false;
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
    showCenterNotice(context, '提示词已复制');
  }

  void _replyToComment(Map<String, dynamic> comment) {
    final displayName = comment['display_name']?.toString().trim() ?? '';
    final username = comment['username']?.toString().trim() ?? '';
    final name = displayName.isNotEmpty ? displayName : username;
    if (name.isEmpty) return;
    final prefix = '@$name ';
    setState(() {
      _replyingToName = name;
      _replyingToCommentId = comment['id']?.toString();
      _replyingToSnippet = comment['content']?.toString();
      _isCommentComposerExpanded = true;
    });
    if (!_commentController.text.startsWith(prefix)) {
      _commentController.text = prefix;
      _commentController.selection = TextSelection.collapsed(
        offset: _commentController.text.length,
      );
    }
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToName = null;
      _replyingToCommentId = null;
      _replyingToSnippet = null;
    });
    _commentController.clear();
  }

  void _openCommentComposer() {
    setState(() => _isCommentComposerExpanded = true);
    _commentFocusNode.requestFocus();
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
    final action = _post['action']?.toString() == 'edit' ? 'edit' : 'generate';
    final actionColor =
        action == 'edit' ? brand.warningColor : brand.primaryColor;
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
      bottomNavigationBar: _commentComposer(brand),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: actionColor.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
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
                            radius: 22,
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
                          _actionPill(
                            label: action == 'generate'
                                ? brand.generateActionLabel
                                : brand.editActionLabel,
                            color: actionColor,
                            icon: action == 'generate'
                                ? Icons.auto_awesome_outlined
                                : Icons.brush_outlined,
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
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: Text('还没有评论')),
                    )
                  else
                    ..._comments.map((comment) => _commentTile(brand, comment)),
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

  Widget _commentComposer(AppBrand brand) {
    final surface = Theme.of(context).colorScheme.surface;
    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.96),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _isCommentComposerExpanded
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingToName != null) ...[
                    _replyTargetBanner(brand),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _replyingToName == null
                                ? '发表评论后可查看提示词'
                                : '回复 $_replyingToName',
                            isDense: true,
                            suffixIcon: _replyingToName == null
                                ? null
                                : IconButton(
                                    tooltip: '取消回复',
                                    icon: const Icon(Icons.close),
                                    onPressed: _cancelReply,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
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
                            : const Text('发送'),
                      ),
                    ],
                  ),
                ],
              )
            : InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _openCommentComposer,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mode_comment_outlined,
                          size: 18, color: brand.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '写评论',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_up),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _replyTargetBanner(AppBrand brand) {
    final snippet = (_replyingToSnippet ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: brand.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.reply_outlined, size: 16, color: brand.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              snippet.isEmpty
                  ? '正在回复 $_replyingToName'
                  : '正在回复 $_replyingToName：$snippet',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(AppBrand brand, Map<String, dynamic> comment) {
    final replyName = _replyTargetName(comment);
    final replySnippet = _replyTargetSnippet(comment);
    final hasReplyTarget = replyName.isNotEmpty || replySnippet.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: hasReplyTarget ? 18 : 0,
        bottom: 14,
      ),
      child: Container(
        decoration: hasReplyTarget
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: brand.primaryColor.withValues(alpha: 0.24),
                    width: 3,
                  ),
                ),
              )
            : null,
        padding: EdgeInsets.only(left: hasReplyTarget ? 10 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _authorAvatar(
              avatarUrl: comment['author_avatar_url']?.toString() ?? '',
              displayName: comment['display_name']?.toString() ?? '-',
              radius: 20,
              fallback: '评',
              brand: brand,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              comment['display_name']?.toString() ?? '-',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            _levelBadge(comment['level_info'] as Map?),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(comment['created_at']?.toString()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (boolish(comment['can_delete']))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '删除评论',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () =>
                              _deleteComment(comment['id'].toString()),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: '回复',
                        icon: const Icon(Icons.reply_outlined, size: 18),
                        onPressed: () => _replyToComment(comment),
                      ),
                    ],
                  ),
                  if (hasReplyTarget) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        replySnippet.isEmpty
                            ? '回复 $replyName'
                            : '回复 $replyName：$replySnippet',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(_visibleCommentContent(comment, replyName)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _replyTargetName(Map<String, dynamic> comment) {
    final value = comment['parent_display_name']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
    final content = comment['content']?.toString().trim() ?? '';
    final match = RegExp(r'^@([^\s]+)\s+').firstMatch(content);
    return match?.group(1) ?? '';
  }

  String _replyTargetSnippet(Map<String, dynamic> comment) {
    final value = comment['parent_content']?.toString().trim();
    return value ?? '';
  }

  String _visibleCommentContent(
    Map<String, dynamic> comment,
    String replyName,
  ) {
    final content = comment['content']?.toString() ?? '';
    if (replyName.isEmpty) return content;
    final prefix = '@$replyName ';
    if (content.startsWith(prefix)) {
      return content.substring(prefix.length);
    }
    return content;
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

  Widget _actionPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
    return formatLocalTime(raw, fallback: '');
  }
}
