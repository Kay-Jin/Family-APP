import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/models/family_brief.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

/// Parent-style quick reply + optional short voice (≤60s).
class FamilyBriefReplySheet extends StatefulWidget {
  const FamilyBriefReplySheet({super.key, required this.brief});

  final FamilyBrief brief;

  @override
  State<FamilyBriefReplySheet> createState() => _FamilyBriefReplySheetState();
}

class _FamilyBriefReplySheetState extends State<FamilyBriefReplySheet> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recordStart;
  String? _voicePath;
  int _voiceSeconds = 0;
  bool _uploading = false;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  String _t(String k) => AppStrings.of(context).text(k);

  List<String> _quickLines() => [
        _t('brief_quick_parent_1'),
        _t('brief_quick_parent_2'),
        _t('brief_quick_parent_3'),
        _t('brief_quick_parent_4'),
        _t('brief_quick_parent_5'),
      ];

  Future<void> _startRecording() async {
    if (kIsWeb) return;
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('microphone_permission_denied'))),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/brief_reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
      _voicePath = null;
      _voiceSeconds = 0;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    final secs = _recordStart == null ? 0 : DateTime.now().difference(_recordStart!).inSeconds;
    setState(() {
      _recording = false;
      _recordStart = null;
      _voicePath = path;
      _voiceSeconds = secs < 0 ? 0 : (secs > 60 ? 60 : secs);
    });
  }

  Future<void> _sendQuick(AppState app, String line) async {
    await app.replyFamilyBriefQuick(briefId: widget.brief.id, quickText: line);
    if (!mounted) return;
    if (app.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(app.error!, (k) => AppStrings.of(context).text(k)))),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _sendVoice(AppState app) async {
    final p = _voicePath;
    if (p == null || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('record_audio_first'))),
      );
      return;
    }
    setState(() => _uploading = true);
    await app.replyFamilyBriefVoice(
      briefId: widget.brief.id,
      filePath: p,
      durationSeconds: _voiceSeconds,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (app.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(app.error!, (k) => AppStrings.of(context).text(k)))),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final b = widget.brief;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_t('brief_reply_title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              b.authorDisplayName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              b.childStatusText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(_t('brief_reply_quick_heading'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickLines().map((line) {
                return FilledButton.tonal(
                  onPressed: (app.isBusy || _uploading) ? null : () => _sendQuick(app, line),
                  child: Text(line),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(_t('brief_reply_voice_heading'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (kIsWeb)
              Text(_t('voice_recording_not_web'), style: Theme.of(context).textTheme.bodySmall)
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _uploading || app.isBusy
                          ? null
                          : (_recording ? _stopRecording : _startRecording),
                      icon: Icon(_recording ? Icons.stop : Icons.mic_none),
                      label: Text(_recording ? _t('stop_recording') : _t('start_recording')),
                    ),
                  ),
                ],
              ),
            if (_voicePath != null) ...[
              const SizedBox(height: 6),
              Text('${_voiceSeconds}s', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _uploading || app.isBusy ? null : () => _sendVoice(app),
              child: Text(_uploading ? _t('uploading') : _t('brief_reply_send_voice')),
            ),
          ],
        ),
      ),
    );
  }
}
