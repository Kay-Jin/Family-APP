import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/l10n/app_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _familyNameController = TextEditingController(text: 'Happy Family');
  final _inviteCodeController = TextEditingController();
  final _questionDateController = TextEditingController(text: '2026-03-24');
  final _questionTextController = TextEditingController(text: 'Today what made you smile?');
  final _photoCaptionController = TextEditingController(text: 'Family dinner');
  final _birthdayController = TextEditingController(text: '1990-08-15');
  final _notifyDaysController = TextEditingController(text: '1');
  final _editBirthdayController = TextEditingController();
  final _editNotifyDaysController = TextEditingController();
  final _commentController = TextEditingController();
  final _answerController = TextEditingController();
  final _editCaptionController = TextEditingController();
  final _questionSearchController = TextEditingController();
  final _photoSearchController = TextEditingController();
  final _statusNoteController = TextEditingController();
  final _voiceTitleController = TextEditingController(text: '晚安语音');
  final _editVoiceTitleController = TextEditingController();
  final _voiceUrlController = TextEditingController(text: 'https://example.com/voice.mp3');
  final _voiceDurationController = TextEditingController(text: '30');
  final _contactNameController = TextEditingController(text: '妈妈');
  final _contactRelationController = TextEditingController(text: '母亲');
  final _contactPhoneController = TextEditingController(text: '13800000000');
  final _contactCityController = TextEditingController(text: '上海');
  final _contactMedicalController = TextEditingController();
  bool _contactPrimary = true;
  String _selectedStatusCode = 'home_safe';
  final ImagePicker _imagePicker = ImagePicker();
  String? _pickedImagePath;
  String? _recordedVoicePath;
  int _recordedVoiceSeconds = 0;
  DateTime? _recordStartAt;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecordingVoice = false;
  bool _isUploadingVoice = false;
  int? _playingVoiceId;
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;
  bool _questionNewestFirst = true;
  bool _photoNewestFirst = true;
  late final TabController _tabController;
  int? _highlightQuestionId;
  int? _highlightPhotoId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed || !state.playing) {
        setState(() => _playingVoiceId = null);
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _voicePosition = position);
    });
    _audioPlayer.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _voiceDuration = duration ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _tabController.dispose();
    _familyNameController.dispose();
    _inviteCodeController.dispose();
    _questionDateController.dispose();
    _questionTextController.dispose();
    _photoCaptionController.dispose();
    _birthdayController.dispose();
    _notifyDaysController.dispose();
    _editBirthdayController.dispose();
    _editNotifyDaysController.dispose();
    _commentController.dispose();
    _answerController.dispose();
    _editCaptionController.dispose();
    _questionSearchController.dispose();
    _photoSearchController.dispose();
    _statusNoteController.dispose();
    _voiceTitleController.dispose();
    _editVoiceTitleController.dispose();
    _voiceUrlController.dispose();
    _voiceDurationController.dispose();
    _contactNameController.dispose();
    _contactRelationController.dispose();
    _contactPhoneController.dispose();
    _contactCityController.dispose();
    _contactMedicalController.dispose();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice recording is not configured for web in this demo.')),
      );
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final recordPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: recordPath,
    );
    setState(() {
      _isRecordingVoice = true;
      _recordStartAt = DateTime.now();
      _recordedVoicePath = null;
      _recordedVoiceSeconds = 0;
    });
  }

  Future<void> _stopVoiceRecording() async {
    final path = await _audioRecorder.stop();
    final seconds = _recordStartAt == null ? 0 : DateTime.now().difference(_recordStartAt!).inSeconds;
    setState(() {
      _isRecordingVoice = false;
      _recordStartAt = null;
      _recordedVoicePath = path;
      _recordedVoiceSeconds = seconds < 0 ? 0 : seconds;
      _voiceDurationController.text = _recordedVoiceSeconds.toString();
    });
  }

  Future<void> _toggleVoicePlayback({
    required int voiceId,
    required String audioUrl,
  }) async {
    try {
      if (_playingVoiceId == voiceId && _audioPlayer.playing) {
        await _audioPlayer.pause();
        if (!mounted) return;
        setState(() => _playingVoiceId = null);
        return;
      }
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() {
        _playingVoiceId = voiceId;
        _voicePosition = Duration.zero;
        _voiceDuration = _audioPlayer.duration ?? Duration.zero;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play this voice message')),
      );
    }
  }

  String _formatSeconds(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _formatDuration(Duration duration) {
    final total = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    return _formatSeconds(total);
  }

  void _focusActivity(String type, int activityId) {
    if (type == 'daily_question') {
      _tabController.animateTo(1);
      setState(() => _highlightQuestionId = activityId);
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _highlightQuestionId = null);
      });
      return;
    }
    if (type == 'photo') {
      _tabController.animateTo(2);
      setState(() => _highlightPhotoId = activityId);
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _highlightPhotoId = null);
      });
      return;
    }
    if (type == 'daily_answer') {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to Questions tab for answer activity')),
      );
      return;
    }
    if (type == 'photo_comment') {
      _tabController.animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to Photos tab for comment activity')),
      );
      return;
    }
  }

  bool _isValidDate(String text) {
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return dateRegex.hasMatch(text);
  }

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _formatRelativeTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return _formatDateTime(raw);
    }
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inSeconds < 60) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute(s) ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour(s) ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day(s) ago';
    }
    return _formatDateTime(raw);
  }

  String _t(String key) => AppStrings.of(context).text(key);

  Widget _buildFamilySetup(AppState appState) {
    return ListView(
      key: const PageStorageKey<String>('family_setup_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _familyNameController,
          decoration: const InputDecoration(labelText: 'New Family Name'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  final name = _familyNameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Family name is required')),
                    );
                    return;
                  }
                  appState.createFamily(name);
                },
          child: const Text('Create Family'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inviteCodeController,
          decoration: const InputDecoration(labelText: 'Invite Code'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  final code = _inviteCodeController.text.trim();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code is required')),
                    );
                    return;
                  }
                  appState.joinFamily(code);
                },
          child: const Text('Join Family'),
        ),
      ],
    );
  }

  Widget _buildQuestionsTab(AppState appState) {
    final searchText = _questionSearchController.text.trim().toLowerCase();
    final displayedQuestions = appState.dailyQuestions.where((q) {
      if (searchText.isEmpty) return true;
      return q.questionText.toLowerCase().contains(searchText) ||
          q.questionDate.toLowerCase().contains(searchText);
    }).toList()
      ..sort((a, b) => _questionNewestFirst ? b.id.compareTo(a.id) : a.id.compareTo(b.id));

    return ListView(
      key: const PageStorageKey<String>('questions_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _questionSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _t('search_questions'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _questionNewestFirst = !_questionNewestFirst),
            icon: Icon(_questionNewestFirst ? Icons.arrow_downward : Icons.arrow_upward),
            label: Text(_questionNewestFirst ? _t('newest_first') : _t('oldest_first')),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _questionDateController,
          decoration: const InputDecoration(labelText: 'Question Date (YYYY-MM-DD)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _questionTextController,
          decoration: const InputDecoration(labelText: 'Question Text'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  final date = _questionDateController.text.trim();
                  final text = _questionTextController.text.trim();
                  if (!_isValidDate(date)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Question date must be YYYY-MM-DD')),
                    );
                    return;
                  }
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Question text is required')),
                    );
                    return;
                  }
                  appState.addDailyQuestion(questionDate: date, questionText: text);
                },
          child: Text(_t('add_question')),
        ),
        const SizedBox(height: 16),
        Text(
          'Daily Questions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (displayedQuestions.isEmpty)
          Text(_t('no_questions'))
        else
          ...displayedQuestions.map(
            (q) => Card(
              color: _highlightQuestionId == q.id ? Colors.amber.shade100 : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(q.questionText),
                      subtitle: Text(q.questionDate),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () async {
                                  _answerController.clear();
                                  final answer = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Answer Question'),
                                        content: TextField(
                                          controller: _answerController,
                                          decoration: const InputDecoration(labelText: 'Your answer'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              _answerController.text.trim(),
                                            ),
                                            child: const Text('Submit'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (answer == null || answer.isEmpty) {
                                    return;
                                  }
                                  appState.addDailyAnswer(questionId: q.id, answerText: answer);
                                },
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Answer'),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () async {
                                  await appState.refreshDailyAnswers(q.id);
                                  if (!mounted) return;
                                  await showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) {
                                      final answers = appState.dailyAnswers[q.id] ?? [];
                                      return SafeArea(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: SizedBox(
                                            height: 420,
                                            child: ListView(
                                              children: [
                                                Text(
                                                  'Answers',
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 12),
                                                if (answers.isEmpty)
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 24),
                                                    child: Center(child: Text('No answers yet.')),
                                                  )
                                                else
                                                  ...answers.map(
                                                    (a) => Column(
                                                      children: [
                                                        ListTile(
                                                          contentPadding: EdgeInsets.zero,
                                                          title: Text(a.answerText),
                                                          subtitle: Text(
                                                            '${a.userDisplayName} · ${_formatRelativeTime(a.createdAt)}',
                                                          ),
                                                        ),
                                                        const Divider(height: 8),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Answers'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openCommentsSheet(AppState appState, int photoId) async {
    await appState.refreshPhotoComments(photoId);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final comments = appState.photoComments[photoId] ?? [];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 420,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await appState.refreshPhotoComments(photoId);
                      setModalState(() {});
                    },
                    child: ListView(
                      key: const PageStorageKey<String>('comments_sheet_list'),
                      children: [
                        Text(
                          'Comments',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No comments yet, be the first one.'),
                            ),
                          )
                        else
                          ...comments.map(
                            (c) => Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(c.content),
                                  subtitle: Text(
                                    '${c.userDisplayName} · ${_formatRelativeTime(c.createdAt)}',
                                  ),
                                ),
                                const Divider(height: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotosTab(AppState appState) {
    final searchText = _photoSearchController.text.trim().toLowerCase();
    final displayedPhotos = appState.photos.where((p) {
      if (searchText.isEmpty) return true;
      return p.caption.toLowerCase().contains(searchText) ||
          p.imageUrl.toLowerCase().contains(searchText);
    }).toList()
      ..sort((a, b) => _photoNewestFirst ? b.id.compareTo(a.id) : a.id.compareTo(b.id));

    return ListView(
      key: const PageStorageKey<String>('photos_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _photoSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _t('search_photos'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _photoNewestFirst = !_photoNewestFirst),
            icon: Icon(_photoNewestFirst ? Icons.arrow_downward : Icons.arrow_upward),
            label: Text(_photoNewestFirst ? _t('newest_first') : _t('oldest_first')),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: appState.isBusy
              ? null
              : () async {
                  final file = await _imagePicker.pickImage(source: ImageSource.gallery);
                  if (file == null) {
                    return;
                  }
                  setState(() {
                    _pickedImagePath = file.path;
                  });
                },
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(_pickedImagePath == null ? 'Pick Image From Gallery' : 'Change Picked Image'),
        ),
        if (_pickedImagePath != null) ...[
          const SizedBox(height: 8),
          Text(
            _pickedImagePath!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _photoCaptionController,
          decoration: const InputDecoration(labelText: 'Caption'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  if (_pickedImagePath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please pick an image first')),
                    );
                    return;
                  }
                  appState.addPhotoFromFile(
                    filePath: _pickedImagePath!,
                    caption: _photoCaptionController.text.trim(),
                  );
                  setState(() {
                    _pickedImagePath = null;
                  });
                },
          child: Text(_t('upload_photo')),
        ),
        const SizedBox(height: 16),
        Text(
          'Photos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (displayedPhotos.isEmpty)
          Text(_t('no_photos'))
        else
          ...displayedPhotos.map(
            (p) => Card(
              color: _highlightPhotoId == p.id ? Colors.lightBlue.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.caption.isEmpty ? 'Photo #${p.id}' : p.caption),
                      subtitle: Text(
                        p.imageUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              insetPadding: const EdgeInsets.all(12),
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    minScale: 0.8,
                                    maxScale: 4,
                                    child: Image.network(
                                      p.imageUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, _, __) {
                                        return const SizedBox(
                                          height: 240,
                                          child: Center(
                                            child: Text('Failed to load image'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: IconButton.filled(
                                      onPressed: () => Navigator.of(context).pop(),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, _, __) {
                              return Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Text('Image unavailable'),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Likes: ${p.likeCount}'),
                        const SizedBox(width: 12),
                        Text('Comments: ${p.commentCount}'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () => appState.togglePhotoLike(
                                    photoId: p.id,
                                    hasLiked: p.hasLiked,
                                  ),
                          icon: Icon(
                            p.hasLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                          ),
                          label: Text(p.hasLiked ? 'Unlike' : 'Like'),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () async {
                                  _commentController.clear();
                                  final content = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Add Comment'),
                                        content: TextField(
                                          controller: _commentController,
                                          decoration: const InputDecoration(labelText: 'Comment'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              _commentController.text.trim(),
                                            ),
                                            child: const Text('Submit'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (content == null || content.isEmpty) {
                                    return;
                                  }
                                  appState.commentPhoto(photoId: p.id, content: content);
                                },
                          icon: const Icon(Icons.comment_outlined),
                          label: const Text('Comment'),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy ? null : () => _openCommentsSheet(appState, p.id),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('View'),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () async {
                                  _editCaptionController.text = p.caption;
                                  final updatedCaption = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Edit Caption'),
                                        content: TextField(
                                          controller: _editCaptionController,
                                          decoration: const InputDecoration(labelText: 'Caption'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              _editCaptionController.text.trim(),
                                            ),
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (updatedCaption == null) {
                                    return;
                                  }
                                  await appState.updatePhotoCaption(
                                    photoId: p.id,
                                    caption: updatedCaption,
                                  );
                                },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Delete Photo'),
                                        content: const Text(
                                          'Are you sure you want to delete this photo? This cannot be undone.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (ok != true) {
                                    return;
                                  }
                                  appState.deletePhoto(p.id);
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBirthdayTab(AppState appState) {
    return ListView(
      key: const PageStorageKey<String>('birthdays_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _birthdayController,
          decoration: const InputDecoration(labelText: 'Birthday (YYYY-MM-DD)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notifyDaysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Notify Days Before'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  final birthday = _birthdayController.text.trim();
                  final days = int.tryParse(_notifyDaysController.text.trim());
                  if (!_isValidDate(birthday)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Birthday must be YYYY-MM-DD')),
                    );
                    return;
                  }
                  if (days == null || days < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notify days must be a non-negative number')),
                    );
                    return;
                  }
                  appState.addBirthdayReminder(
                    birthday: birthday,
                    notifyDaysBefore: days,
                  );
                },
          child: Text(_t('add_birthday_reminder')),
        ),
        const SizedBox(height: 8),
        if (appState.birthdayReminders.isEmpty)
          Text(_t('no_reminders'))
        else
          ...appState.birthdayReminders.map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.birthday),
              subtitle: Text(
                'Notify ${r.notifyDaysBefore} day(s) before · ${r.enabled ? 'Enabled' : 'Disabled'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit reminder',
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            _editBirthdayController.text = r.birthday;
                            _editNotifyDaysController.text = r.notifyDaysBefore.toString();
                            bool enabled = r.enabled;
                            final result = await showDialog<Map<String, dynamic>>(
                              context: context,
                              builder: (context) {
                                return StatefulBuilder(
                                  builder: (context, setDialogState) {
                                    return AlertDialog(
                                      title: const Text('Edit Birthday Reminder'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: _editBirthdayController,
                                            decoration: const InputDecoration(
                                              labelText: 'Birthday (YYYY-MM-DD)',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _editNotifyDaysController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Notify Days Before',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SwitchListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('Enabled'),
                                            value: enabled,
                                            onChanged: (v) => setDialogState(() => enabled = v),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context, {
                                              'birthday': _editBirthdayController.text.trim(),
                                              'days': _editNotifyDaysController.text.trim(),
                                              'enabled': enabled,
                                            });
                                          },
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                            if (result == null) return;
                            final birthday = (result['birthday'] as String?) ?? '';
                            final days = int.tryParse((result['days'] as String?) ?? '');
                            final enabledValue = (result['enabled'] as bool?) ?? true;
                            if (!_isValidDate(birthday)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Birthday must be YYYY-MM-DD')),
                              );
                              return;
                            }
                            if (days == null || days < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notify days must be a non-negative number'),
                                ),
                              );
                              return;
                            }
                            await appState.updateBirthdayReminder(
                              reminderId: r.id,
                              birthday: birthday,
                              notifyDaysBefore: days,
                              enabled: enabledValue,
                            );
                          },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete reminder',
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Reminder'),
                                  content: const Text('Delete this birthday reminder?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (ok != true) return;
                            await appState.deleteBirthdayReminder(r.id);
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewTab(AppState appState) {
    final latestQuestions = [...appState.dailyQuestions]..sort((a, b) => b.id.compareTo(a.id));
    final latestPhotos = [...appState.photos]..sort((a, b) => b.id.compareTo(a.id));
    final latestReminders = [...appState.birthdayReminders]..sort((a, b) => b.id.compareTo(a.id));

    return ListView(
      key: const PageStorageKey<String>('overview_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEADB), Color(0xFFFFF4EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFFFD9C7),
                child: Icon(Icons.favorite_rounded, color: Color(0xFFB45E48)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('family_overview_quote'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6E4D42),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildStatCard(_t('questions'), appState.dailyQuestions.length.toString(), Icons.quiz_outlined),
            _buildStatCard(_t('photos'), appState.photos.length.toString(), Icons.photo_library_outlined),
            _buildStatCard(_t('birthdays'), appState.birthdayReminders.length.toString(), Icons.cake_outlined),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(_t('recent_activity'), Icons.timeline),
        const SizedBox(height: 8),
        if (appState.activities.isEmpty)
          _warmEmptyCard(_t('no_activity'), Icons.timelapse_outlined)
        else
          ...appState.activities.take(8).map(
            (a) => ListTile(
              onTap: () => _focusActivity(a.activityType, a.activityId),
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFFEBDD),
                child: Text(
                  _initialOf(a.actorName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E4B36),
                  ),
                ),
              ),
              title: Text('${a.actorName} · ${_activityTypeLabel(a.activityType)}'),
              subtitle: Text('${a.content}\n${_formatRelativeTime(a.createdAt)}'),
              trailing: Icon(_activityIcon(a.activityType), size: 18),
              isThreeLine: true,
            ),
          ),
        const SizedBox(height: 20),
        _sectionTitle(_t('latest_questions'), Icons.quiz_outlined),
        const SizedBox(height: 8),
        if (latestQuestions.isEmpty)
          _warmEmptyCard(_t('no_questions'), Icons.help_outline)
        else
          ...latestQuestions.take(3).map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.quiz_outlined),
              title: Text(q.questionText),
              subtitle: Text(q.questionDate),
            ),
          ),
        const SizedBox(height: 16),
        _sectionTitle(_t('latest_photos'), Icons.photo_outlined),
        const SizedBox(height: 8),
        if (latestPhotos.isEmpty)
          _warmEmptyCard(_t('no_photos'), Icons.photo_size_select_actual_outlined)
        else
          ...latestPhotos.take(3).map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_outlined),
              title: Text(p.caption.isEmpty ? 'Photo #${p.id}' : p.caption),
              subtitle: Text('Likes ${p.likeCount} · Comments ${p.commentCount}'),
            ),
          ),
        const SizedBox(height: 16),
        _sectionTitle(_t('latest_reminders'), Icons.cake_outlined),
        const SizedBox(height: 8),
        if (latestReminders.isEmpty)
          _warmEmptyCard(_t('no_reminders'), Icons.event_busy_outlined)
        else
          ...latestReminders.take(3).map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(r.birthday),
              subtitle: Text(
                'Notify ${r.notifyDaysBefore} day(s) before · ${r.enabled ? 'Enabled' : 'Disabled'}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB45E48)),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _warmEmptyCard(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFB27B67)),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  String _initialOf(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  Widget _buildCareTab(AppState appState) {
    final statusOptions = const [
      ('home_safe', '已到家'),
      ('on_the_way', '在路上'),
      ('busy_today', '今天较忙'),
      ('need_talk', '想聊聊'),
    ];
    return ListView(
      key: const PageStorageKey<String>('care_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Family Status Card', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatusCode,
          items: statusOptions
              .map((s) => DropdownMenuItem<String>(value: s.$1, child: Text(s.$2)))
              .toList(),
          onChanged: appState.isBusy ? null : (v) => setState(() => _selectedStatusCode = v ?? 'home_safe'),
          decoration: const InputDecoration(labelText: 'Status'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _statusNoteController,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () => appState.addStatusUpdate(
                    statusCode: _selectedStatusCode,
                    note: _statusNoteController.text.trim(),
                  ),
          child: const Text('Publish Status'),
        ),
        const SizedBox(height: 10),
        ...appState.statusUpdates.take(5).map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s.userDisplayName} · ${s.statusCode}'),
              subtitle: Text('${s.note}\n${_formatRelativeTime(s.createdAt)}'),
              isThreeLine: true,
            )),
        const Divider(height: 28),
        Text('Voice Mailbox', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Only the sender can rename or delete a voice message.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        if (appState.hasPendingVoiceUpload) ...[
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              title: const Text('Last voice upload did not finish'),
              subtitle: Text(appState.voiceUploadError ?? 'Network is unstable, retry when ready.'),
              trailing: OutlinedButton(
                onPressed: appState.isBusy || _isUploadingVoice
                    ? null
                    : () async {
                        setState(() => _isUploadingVoice = true);
                        await appState.retryPendingVoiceUpload();
                        if (!mounted) return;
                        setState(() => _isUploadingVoice = false);
                        if (appState.error == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice upload retry succeeded')),
                          );
                        }
                      },
                child: const Text('Retry'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _voiceTitleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: appState.isBusy
                    ? null
                    : _isRecordingVoice
                        ? _stopVoiceRecording
                        : _startVoiceRecording,
                icon: Icon(_isRecordingVoice ? Icons.stop_circle_outlined : Icons.mic_none),
                label: Text(_isRecordingVoice ? 'Stop Recording' : 'Start Recording'),
              ),
            ),
          ],
        ),
        if (_recordedVoicePath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Recorded: $_recordedVoicePath',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy || _isUploadingVoice
              ? null
              : () async {
                  final title = _voiceTitleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice title is required')),
                    );
                    return;
                  }
                  if (_recordedVoicePath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please record audio first')),
                    );
                    return;
                  }
                  setState(() => _isUploadingVoice = true);
                  await appState.addVoiceMessageFromFile(
                    title: title,
                    filePath: _recordedVoicePath!,
                    durationSeconds: _recordedVoiceSeconds,
                  );
                  if (!mounted) return;
                  setState(() {
                    _isUploadingVoice = false;
                    _recordedVoicePath = null;
                    _recordedVoiceSeconds = 0;
                  });
                  if (appState.error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice uploaded')),
                    );
                  }
                },
          child: Text(_isUploadingVoice ? 'Uploading...' : 'Upload Recorded Voice'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _voiceUrlController,
          decoration: const InputDecoration(labelText: 'Or manual Audio URL'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _voiceDurationController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Duration Seconds (manual)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () => appState.addVoiceMessage(
                    title: _voiceTitleController.text.trim(),
                    audioUrl: _voiceUrlController.text.trim(),
                    durationSeconds: int.tryParse(_voiceDurationController.text.trim()) ?? 0,
                  ),
          child: const Text('Add Voice Message By URL'),
        ),
        const SizedBox(height: 10),
        ...appState.voiceMessages.take(5).map((v) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(v.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${v.senderDisplayName} · ${_formatSeconds(v.durationSeconds)} · ${_formatRelativeTime(v.createdAt)}',
                  ),
                  if (_playingVoiceId == v.id) ...[
                    const SizedBox(height: 6),
                    Slider(
                      value: _voicePosition.inMilliseconds
                          .toDouble()
                          .clamp(0, (_voiceDuration.inMilliseconds <= 0 ? 1 : _voiceDuration.inMilliseconds).toDouble()),
                      max: (_voiceDuration.inMilliseconds <= 0 ? 1 : _voiceDuration.inMilliseconds).toDouble(),
                      onChanged: (value) async {
                        final target = Duration(milliseconds: value.toInt());
                        await _audioPlayer.seek(target);
                      },
                    ),
                    Text(
                      '${_formatDuration(_voicePosition)} / ${_formatDuration(_voiceDuration)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: appState.isBusy
                        ? null
                        : () => _toggleVoicePlayback(
                              voiceId: v.id,
                              audioUrl: v.audioUrl,
                            ),
                    icon: Icon(
                      _playingVoiceId == v.id ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    ),
                  ),
                  IconButton(
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            _editVoiceTitleController.text = v.title;
                            final newTitle = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Rename Voice'),
                                  content: TextField(
                                    controller: _editVoiceTitleController,
                                    decoration: const InputDecoration(labelText: 'Title'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        _editVoiceTitleController.text.trim(),
                                      ),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (newTitle == null || newTitle.isEmpty) return;
                            await appState.renameVoiceMessage(messageId: v.id, title: newTitle);
                          },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Delete Voice'),
                                  content: const Text('Delete this voice message?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (ok != true) return;
                            await appState.removeVoiceMessage(v.id);
                            if (_playingVoiceId == v.id) {
                              await _audioPlayer.stop();
                              if (!mounted) return;
                              setState(() => _playingVoiceId = null);
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            )),
        const Divider(height: 28),
        Text('Emergency Contact Card', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _contactNameController, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 8),
        TextField(controller: _contactRelationController, decoration: const InputDecoration(labelText: 'Relation')),
        const SizedBox(height: 8),
        TextField(controller: _contactPhoneController, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 8),
        TextField(controller: _contactCityController, decoration: const InputDecoration(labelText: 'City')),
        const SizedBox(height: 8),
        TextField(
          controller: _contactMedicalController,
          decoration: const InputDecoration(labelText: 'Medical Notes'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Primary Contact'),
          value: _contactPrimary,
          onChanged: appState.isBusy ? null : (v) => setState(() => _contactPrimary = v),
        ),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () => appState.addEmergencyContact(
                    contactName: _contactNameController.text.trim(),
                    relation: _contactRelationController.text.trim(),
                    phone: _contactPhoneController.text.trim(),
                    city: _contactCityController.text.trim(),
                    medicalNotes: _contactMedicalController.text.trim(),
                    isPrimary: _contactPrimary,
                  ),
          child: const Text('Save Emergency Contact'),
        ),
        const SizedBox(height: 10),
        ...appState.emergencyContacts.take(5).map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c.contactName} (${c.relation})'),
              subtitle: Text('${c.phone} · ${c.city}'),
              trailing: c.isPrimary ? const Icon(Icons.star, color: Colors.amber) : null,
            )),
        const Divider(height: 28),
        Text('Smart Care Reminders', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (appState.careReminders.isEmpty)
          const Text('No reminders. Family connection is doing great!')
        else
          ...appState.careReminders.map((r) => Card(
                child: ListTile(
                  title: Text(r.title),
                  subtitle: Text(r.message),
                  leading: Icon(
                    r.severity == 'high'
                        ? Icons.priority_high
                        : r.severity == 'medium'
                            ? Icons.notification_important_outlined
                            : Icons.info_outline,
                    color: r.severity == 'high'
                        ? Colors.red
                        : r.severity == 'medium'
                            ? Colors.orange
                            : Colors.blueGrey,
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 110,
      child: Card(
        color: const Color(0xFFFFF4EC),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'daily_question':
        return Icons.quiz_outlined;
      case 'daily_answer':
        return Icons.edit_note;
      case 'photo':
        return Icons.photo_outlined;
      case 'photo_comment':
        return Icons.comment_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  String _activityTypeLabel(String type) {
    switch (type) {
      case 'daily_question':
        return 'posted a question';
      case 'daily_answer':
        return 'answered';
      case 'photo':
        return 'uploaded a photo';
      case 'photo_comment':
        return 'commented';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final family = appState.family;

    Widget body;
    if (family == null) {
      body = _buildFamilySetup(appState);
    } else {
      body = Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE4D8),
                child: Icon(Icons.groups_2_outlined, color: Color(0xFF9A4F36)),
              ),
              title: Text(
                family.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${_t('invite_code')}: ${family.inviteCode}'),
              trailing: IconButton(
                onPressed: appState.isBusy ? null : appState.refreshHomeData,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEE3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: const Color(0xFF8E4B36),
              unselectedLabelColor: const Color(0xFF8E6C5F),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: _t('overview')),
                Tab(text: _t('questions')),
                Tab(text: _t('photos')),
                Tab(text: _t('birthdays')),
                Tab(text: _t('care')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(appState),
                _buildQuestionsTab(appState),
                _buildPhotosTab(appState),
                _buildBirthdayTab(appState),
                _buildCareTab(appState),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, size: 20, color: Color(0xFFCC6B5A)),
            SizedBox(width: 8),
            Text(_t('family_home')),
          ],
        ),
        actions: [
          PopupMenuButton<String?>(
            tooltip: _t('language'),
            icon: const Icon(Icons.language),
            onSelected: (value) => appState.setLocaleCode(value),
            itemBuilder: (context) => [
              PopupMenuItem<String?>(
                value: null,
                child: Text(_t('system_default')),
              ),
              const PopupMenuItem<String?>(
                value: 'en',
                child: Text('English'),
              ),
              const PopupMenuItem<String?>(
                value: 'zh',
                child: Text('中文'),
              ),
              const PopupMenuItem<String?>(
                value: 'ko',
                child: Text('한국어'),
              ),
            ],
          ),
          IconButton(
            onPressed: appState.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFAF7), Color(0xFFFFF3EC)],
          ),
        ),
        child: Column(
          children: [
            if (appState.error != null)
              Container(
                width: double.infinity,
                color: Colors.red.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  appState.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: appState.refreshHomeData,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
