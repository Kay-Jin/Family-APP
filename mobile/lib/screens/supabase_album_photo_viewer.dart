import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/supabase/album_repository.dart';
import 'package:family_mobile/supabase/cloud_album_photo.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/util/date_time_display.dart';
import 'package:flutter/material.dart';

/// Full-screen cloud album photo with pinch-zoom; owner can edit caption.
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
  late CloudAlbumPhoto _photo;
  bool _didMutate = false;

  String _t(String key) => AppStrings.of(context).text(key);

  @override
  void initState() {
    super.initState();
    _photo = widget.photo;
  }

  void _pop() {
    Navigator.pop(context, _didMutate);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _didMutate);
      },
      child: Scaffold(
      backgroundColor: Colors.black,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                '${_photo.uploaderDisplayName} · ${formatIsoDateTimeLocal(context, _photo.createdAt)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
