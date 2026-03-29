import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/models/family_brief.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show AudioPlayer, ProcessingState;

/// Read-only brief + reply; optional voice playback.
class FamilyBriefDetailSheet extends StatefulWidget {
  const FamilyBriefDetailSheet({super.key, required this.brief});

  final FamilyBrief brief;

  @override
  State<FamilyBriefDetailSheet> createState() => _FamilyBriefDetailSheetState();
}

class _FamilyBriefDetailSheetState extends State<FamilyBriefDetailSheet> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _t(String k) => AppStrings.of(context).text(k);

  Future<void> _toggleVoice(String url) async {
    try {
      if (_playing) {
        await _player.stop();
        setState(() => _playing = false);
        return;
      }
      await _player.setUrl(url);
      await _player.play();
      setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('answer_image_failed'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.brief;
    final r = b.reply;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_t('brief_detail_title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${b.authorDisplayName} · ${b.createdAt}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (b.parentsOnly) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_t('brief_parents_only_badge')),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(_t('brief_detail_status'), style: Theme.of(context).textTheme.titleSmall),
            Text(b.childStatusText),
            if (b.contactNote != null && b.contactNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_t('brief_detail_contact'), style: Theme.of(context).textTheme.titleSmall),
              Text(b.contactNote!),
            ],
            const SizedBox(height: 12),
            Text(_t('brief_detail_question'), style: Theme.of(context).textTheme.titleSmall),
            Text(b.questionText),
            if (r != null) ...[
              const SizedBox(height: 16),
              Text(_t('brief_detail_reply'), style: Theme.of(context).textTheme.titleSmall),
              if (r.replyKind == 'voice' &&
                  r.audioUrl != null &&
                  r.audioUrl!.isNotEmpty) ...[
                Text(_t('brief_detail_voice')),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  onPressed: () => _toggleVoice(r.audioUrl!),
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(_playing ? _t('brief_stop_voice') : _t('brief_play_voice')),
                ),
                Text('${r.durationSeconds}s', style: Theme.of(context).textTheme.bodySmall),
              ] else
                Text(r.quickText ?? ''),
            ],
          ],
        );
      },
    );
  }
}
