import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/supabase/album_repository.dart';
import 'package:family_mobile/supabase/cloud_album_comment.dart';
import 'package:family_mobile/supabase/cloud_album_photo.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/util/date_time_display.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Full-screen cloud album photo: zoom, caption edit (owner), likes, comments.
class SupabaseAlbumPhotoViewer extends StatefulWidget {
  const SupabaseAlbumPhotoViewer({
    super.key,
    required this.photo,
    required this.imageUrl,
    required this.canEditCaption,
  });

  final CloudAlbumPhoto photo;
  final String imageUrl;
  final bool canEditCaption;

  @override
  State<SupabaseAlbumPhotoViewer> createState() => _SupabaseAlbumPhotoViewerState();
}

class _SupabaseAlbumPhotoViewerState extends State<SupabaseAlbumPhotoViewer> {
  final _repo = AlbumRepository();
  final _commentController = TextEditingController();
  late CloudAlbumPhoto _photo;
  bool _didMutate = false;

  int _likeCount = 0;
  bool _likedByMe = false;
  bool _likeBusy = false;
  List<CloudAlbumComment> _comments = [];
  bool _engagementLoading = true;
  bool _sendingComment = false;

  String _t(String key) => AppStrings.of(context).text(key);

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
    _loadEngagement();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _pop() {
    Navigator.pop(context, _didMutate);
  }

  Future<void> _loadEngagement() async {
    setState(() => _engagementLoading = true);
    try {
      final likes = await _repo.getLikeState(_photo.id);
      final comments = await _repo.listComments(_photo.id);
      if (!mounted) return;
      setState(() {
        _likeCount = likes.count;
        _likedByMe = likes.likedByMe;
        _comments = comments;
        _engagementLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _engagementLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
    }
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      if (_likedByMe) {
        await _repo.unlikePhoto(_photo.id);
      } else {
        await _repo.likePhoto(_photo.id);
      }
      final next = await _repo.getLikeState(_photo.id);
      if (!mounted) return;
      setState(() {
        _likeCount = next.count;
        _likedByMe = next.likedByMe;
        _likeBusy = false;
        _didMutate = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _likeBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text;
    try {
      await _repo.addComment(_photo.id, text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
      return;
    }
    _commentController.clear();
    if (!mounted) return;
    setState(() => _didMutate = true);
    await _loadEngagement();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('snack_album_comment_posted'))),
      );
    }
  }

  Future<void> _deleteComment(CloudAlbumComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = AppStrings.of(ctx);
        return AlertDialog(
          title: Text(t.text('delete')),
          content: Text(t.text('delete_album_comment_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.text('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.text('delete_confirm'))),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _repo.deleteComment(c.id);
      if (!mounted) return;
      setState(() => _didMutate = true);
      await _loadEngagement();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('snack_album_comment_deleted'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
    }
  }

  Future<void> _editCaption() async {
    final controller = TextEditingController(text: _photo.caption);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = AppStrings.of(ctx);
        return AlertDialog(
          title: Text(t.text('edit_caption')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: t.text('caption')),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.text('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.text('save'))),
          ],
        );
      },
    );
    if (saved != true) {
      controller.dispose();
      return;
    }
    final text = controller.text.trim();
    controller.dispose();
    try {
      final updated = await _repo.updateCaption(photoId: _photo.id, caption: text);
      if (!mounted) return;
      setState(() {
        _photo = updated;
        _didMutate = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('snack_album_caption_updated'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _didMutate);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _pop,
          ),
          title: Text(
            _photo.caption.isNotEmpty ? _photo.caption : _t('photos_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (widget.canEditCaption)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _editCaption,
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 52,
              child: ColoredBox(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'cloud_album_${_photo.id}',
                      child: Image.network(
                        widget.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _t('answer_image_failed'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 48,
              child: ColoredBox(
                color: const Color(0xFF1A1A1A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${_photo.uploaderDisplayName} · ${formatIsoDateTimeLocal(context, _photo.createdAt)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            onPressed: _likeBusy ? null : _toggleLike,
                            icon: Icon(
                              _likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _likedByMe ? const Color(0xFFE6866A) : Colors.white70,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4, top: 10),
                            child: Text(
                              '$_likeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        _t('comments'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: _engagementLoading
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                              ),
                            )
                          : _comments.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      _t('no_comments_yet'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  itemCount: _comments.length,
                                  itemBuilder: (context, i) {
                                    final c = _comments[i];
                                    final mine = uid != null && uid == c.userId;
                                    return ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      title: Text(
                                        c.body,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${c.authorDisplayName} · ${formatIsoDateTimeLocal(context, c.createdAt)}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                      trailing: mine
                                          ? IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                                              onPressed: () => _deleteComment(c),
                                            )
                                          : null,
                                    );
                                  },
                                ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: _t('add_comment'),
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.08),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                minLines: 1,
                                maxLines: 4,
                                textCapitalization: TextCapitalization.sentences,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _sendingComment
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE6866A)),
                                    ),
                                  )
                                : IconButton(
                                    onPressed: () async {
                                      setState(() => _sendingComment = true);
                                      await _sendComment();
                                      if (mounted) setState(() => _sendingComment = false);
                                    },
                                    icon: const Icon(Icons.send_rounded, color: Color(0xFFE6866A)),
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
      ),
    );
  }
}
