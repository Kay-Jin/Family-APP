import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/screens/supabase_album_photo_viewer.dart';
import 'package:family_mobile/supabase/album_repository.dart';
import 'package:family_mobile/supabase/cloud_album_photo.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/util/date_time_display.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloud family album: grid + upload (Supabase `family_photos` + `family_album_images`).
class SupabaseCloudAlbumPanel extends StatefulWidget {
  const SupabaseCloudAlbumPanel({super.key, required this.familyId});

  final String familyId;

  @override
  State<SupabaseCloudAlbumPanel> createState() => _SupabaseCloudAlbumPanelState();
}

class _SupabaseCloudAlbumPanelState extends State<SupabaseCloudAlbumPanel> {
  final _repo = AlbumRepository();
  final _captionController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<CloudAlbumPhoto> _photos = [];
  Map<String, String> _signedUrlByPath = {};
  bool _uploading = false;
  Uint8List? _pendingBytes;
  String _pendingExt = 'jpg';

  String _t(String key) => AppStrings.of(context).text(key);

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listPhotos(widget.familyId);
      final urls = await _repo.signedAlbumImageUrls(list.map((p) => p.imagePath));
      if (mounted) {
        setState(() {
          _photos = list;
          _signedUrlByPath = urls;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('album_image_web_hint'))),
      );
      return;
    }
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final extDot = p.extension(x.path);
    final ext = extDot.isNotEmpty ? extDot.substring(1).toLowerCase() : 'jpg';
    if (!mounted) return;
    setState(() {
      _pendingBytes = bytes;
      _pendingExt = ext;
    });
  }

  Future<void> _upload() async {
    final bytes = _pendingBytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = _t('album_pick_image_first'));
      return;
    }
    setState(() {
      _error = null;
      _uploading = true;
    });
    try {
      await _repo.uploadPhoto(
        familyId: widget.familyId,
        bytes: bytes,
        imageExtension: _pendingExt,
        caption: _captionController.text,
      );
      _captionController.clear();
      setState(() => _pendingBytes = null);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('snack_album_photo_added'))),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openViewer(CloudAlbumPhoto photo, bool mine) async {
    String? url = _signedUrlByPath[photo.imagePath];
    try {
      url ??= await _repo.signedAlbumImageUrl(photo.imagePath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _signedUrlByPath[photo.imagePath] = url!);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (ctx) => SupabaseAlbumPhotoViewer(
          photo: photo,
          imageUrl: url!,
          canEditCaption: mine,
        ),
      ),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _confirmDelete(CloudAlbumPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = AppStrings.of(ctx);
        return AlertDialog(
          title: Text(t.text('delete_photo')),
          content: Text(t.text('delete_photo_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.text('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.text('delete_confirm'))),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await _repo.deletePhoto(photo);
      await _refresh();
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(labelText: _t('caption')),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_t('pick_image')),
                  ),
                  if (_pendingBytes != null && _pendingBytes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _pendingBytes!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_uploading ? _t('uploading') : _t('upload_photo')),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          if (_loading && _photos.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_photos.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(_t('no_photos'), style: Theme.of(context).textTheme.bodyLarge)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final photo = _photos[index];
                    final url = _signedUrlByPath[photo.imagePath];
                    final mine = uid != null && uid == photo.userId;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Material(
                                  color: Colors.grey.shade200,
                                  child: InkWell(
                                    onTap: url != null ? () => _openViewer(photo, mine) : null,
                                    child: Hero(
                                      tag: 'cloud_album_${photo.id}',
                                      child: url == null
                                          ? Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text(
                                                  _t('answer_image_failed'),
                                                  textAlign: TextAlign.center,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ),
                                            )
                                          : Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Text(_t('answer_image_failed'), textAlign: TextAlign.center),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                if (mine)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                        onPressed: () => _confirmDelete(photo),
                                      ),
                                    ),
                                  ),
                                if (photo.likeCount > 0 || photo.commentCount > 0)
                                  Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.favorite_rounded, size: 11, color: Color(0xFFFFB4A8)),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${photo.likeCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.chat_bubble_outline_rounded, size: 10, color: Colors.white70),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${photo.commentCount}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (photo.caption.isNotEmpty)
                                  Text(
                                    photo.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                Text(
                                  '${photo.uploaderDisplayName} · ${formatIsoDateTimeLocal(context, photo.createdAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF6D5A51)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: _photos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
