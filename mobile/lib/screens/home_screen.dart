import 'package:family_mobile/screens/supabase_family_screen.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/util/api_error_message.dart';
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
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _hospitalsController = TextEditingController();
  final _medicalOtherController = TextEditingController();
  final _accompanimentNoteController = TextEditingController();
  bool _contactPrimary = true;
  bool _accompanimentRequested = false;
  bool _medicalPrefilled = false;
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
    _allergiesController.dispose();
    _medicationsController.dispose();
    _hospitalsController.dispose();
    _medicalOtherController.dispose();
    _accompanimentNoteController.dispose();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('voice_recording_not_web'))),
      );
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('microphone_permission_denied'))),
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
        SnackBar(content: Text(_t('unable_play_voice'))),
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
        SnackBar(content: Text(_t('activity_switched_questions'))),
      );
      return;
    }
    if (type == 'photo_comment') {
      _tabController.animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('activity_switched_photos'))),
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
      return _t('just_now');
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${_t('minutes_ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${_t('hours_ago')}';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ${_t('days_ago')}';
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
          decoration: InputDecoration(labelText: _t('new_family_name')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  final name = _familyNameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('family_name_required'))),
                    );
                    return;
                  }
                  appState.createFamily(name);
                },
          child: Text(_t('create_family')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inviteCodeController,
          decoration: InputDecoration(labelText: _t('invite_code')),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  final code = _inviteCodeController.text.trim();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('invite_code_required'))),
                    );
                    return;
                  }
                  appState.joinFamily(code);
                },
          child: Text(_t('join_family')),
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
          decoration: InputDecoration(labelText: _t('question_date')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _questionTextController,
          decoration: InputDecoration(labelText: _t('question_text')),
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
                      SnackBar(content: Text(_t('question_date_invalid'))),
                    );
                    return;
                  }
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('question_text_required'))),
                    );
                    return;
                  }
                  appState.addDailyQuestion(questionDate: date, questionText: text);
                },
          child: Text(_t('add_question')),
        ),
        const SizedBox(height: 16),
        Text(
          _t('daily_questions'),
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
                                        title: Text(_t('answer_question')),
                                        content: TextField(
                                          controller: _answerController,
                                          decoration: InputDecoration(labelText: _t('your_answer')),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(_t('cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              _answerController.text.trim(),
                                            ),
                                            child: Text(_t('submit')),
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
                          label: Text(_t('answer')),
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
                                                  _t('answers'),
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 12),
                                                if (answers.isEmpty)
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 24),
                                                    child: Center(child: Text(_t('no_answers_yet'))),
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
                          label: Text(_t('view_answers')),
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
                          _t('comments'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (comments.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(_t('no_comments_yet')),
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
          label: Text(_pickedImagePath == null ? _t('pick_image') : _t('change_image')),
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
          decoration: InputDecoration(labelText: _t('caption')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () {
                  if (_pickedImagePath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('pick_image_first'))),
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
          _t('photos_title'),
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
                      title: Text(p.caption.isEmpty ? '${_t('photos')} #${p.id}' : p.caption),
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
                                        return SizedBox(
                                          height: 240,
                                          child: Center(
                                            child: Text(_t('failed_load_image')),
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
                                child: Text(_t('image_unavailable')),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${_t('likes_count')}: ${p.likeCount}'),
                        const SizedBox(width: 12),
                        Text('${_t('comments_count')}: ${p.commentCount}'),
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
                          label: Text(p.hasLiked ? _t('unlike') : _t('like')),
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
                                        title: Text(_t('add_comment')),
                                        content: TextField(
                                          controller: _commentController,
                                          decoration: InputDecoration(labelText: _t('comment')),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(_t('cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              _commentController.text.trim(),
                                            ),
                                            child: Text(_t('submit')),
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
                          label: Text(_t('comment')),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy ? null : () => _openCommentsSheet(appState, p.id),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(_t('view')),
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
                                        title: Text(_t('edit_caption')),
                                        content: TextField(
                                          controller: _editCaptionController,
                                          decoration: InputDecoration(labelText: _t('caption')),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(_t('cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              context,
                                              _editCaptionController.text.trim(),
                                            ),
                                            child: Text(_t('save')),
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
                          label: Text(_t('edit')),
                        ),
                        TextButton.icon(
                          onPressed: appState.isBusy
                              ? null
                              : () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(_t('delete_photo')),
                                        content: Text(_t('delete_photo_confirm')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: Text(_t('cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(_t('delete_confirm')),
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
                          label: Text(_t('delete')),
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
          decoration: InputDecoration(labelText: _t('birthday')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notifyDaysController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: _t('notify_days_before')),
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
                      SnackBar(content: Text(_t('birthday_invalid'))),
                    );
                    return;
                  }
                  if (days == null || days < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('notify_days_invalid'))),
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
                '${_t('notify_days_before')}: ${r.notifyDaysBefore} · ${r.enabled ? _t('enabled') : _t('disabled')}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _t('edit_reminder_tooltip'),
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
                                      title: Text(_t('edit_birthday_reminder')),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: _editBirthdayController,
                                            decoration: InputDecoration(labelText: _t('birthday')),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _editNotifyDaysController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(labelText: _t('notify_days_before')),
                                          ),
                                          const SizedBox(height: 8),
                                          SwitchListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(_t('enabled')),
                                            value: enabled,
                                            onChanged: (v) => setDialogState(() => enabled = v),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(_t('cancel')),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context, {
                                              'birthday': _editBirthdayController.text.trim(),
                                              'days': _editNotifyDaysController.text.trim(),
                                              'enabled': enabled,
                                            });
                                          },
                                          child: Text(_t('save')),
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
                                SnackBar(content: Text(_t('birthday_invalid'))),
                              );
                              return;
                            }
                            if (days == null || days < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_t('notify_days_invalid'))),
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
                    tooltip: _t('delete_reminder_tooltip'),
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(_t('delete_reminder')),
                                  content: Text(_t('delete_reminder_confirm')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(_t('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(_t('delete_confirm')),
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
              title: Text(p.caption.isEmpty ? '${_t('photos')} #${p.id}' : p.caption),
              subtitle: Text('${_t('likes_count')} ${p.likeCount} · ${_t('comments_count')} ${p.commentCount}'),
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
                '${_t('notify_days_before')}: ${r.notifyDaysBefore} · ${r.enabled ? _t('enabled') : _t('disabled')}',
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
        Text(_t('family_status_card'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statusOptions
              .map(
                (s) => FilledButton.tonal(
                  onPressed: appState.isBusy
                      ? null
                      : () async {
                          setState(() => _selectedStatusCode = s.$1);
                          await appState.addStatusUpdate(
                            statusCode: s.$1,
                            note: _statusNoteController.text.trim(),
                          );
                        },
                  child: Text(s.$2),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedStatusCode,
          items: statusOptions
              .map((s) => DropdownMenuItem<String>(value: s.$1, child: Text(s.$2)))
              .toList(),
          onChanged: appState.isBusy ? null : (v) => setState(() => _selectedStatusCode = v ?? 'home_safe'),
          decoration: InputDecoration(labelText: _t('status')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _statusNoteController,
          decoration: InputDecoration(labelText: _t('note_optional')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () => appState.addStatusUpdate(
                    statusCode: _selectedStatusCode,
                    note: _statusNoteController.text.trim(),
                  ),
          child: Text(_t('publish_status')),
        ),
        const SizedBox(height: 10),
        ...appState.statusUpdates.take(5).map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s.userDisplayName} · ${s.statusCode}'),
              subtitle: Text('${s.note}\n${_formatRelativeTime(s.createdAt)}'),
              isThreeLine: true,
            )),
        const Divider(height: 28),
        Text(_t('voice_mailbox'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          _t('voice_permission_copy'),
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        if (appState.hasPendingVoiceUpload) ...[
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              title: Text(_t('last_voice_upload_failed')),
              subtitle: Text(appState.voiceUploadError ?? ''),
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
                            SnackBar(content: Text(_t('voice_upload_retry_succeeded'))),
                          );
                        }
                      },
                child: Text(_t('retry')),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _voiceTitleController,
          decoration: InputDecoration(labelText: _t('title')),
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
                label: Text(_isRecordingVoice ? _t('stop_recording') : _t('start_recording')),
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
                      SnackBar(content: Text(_t('voice_title_required'))),
                    );
                    return;
                  }
                  if (_recordedVoicePath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('record_audio_first'))),
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
                      SnackBar(content: Text(_t('voice_uploaded'))),
                    );
                  }
                },
          child: Text(_isUploadingVoice ? _t('uploading') : _t('upload_recorded_voice')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _voiceUrlController,
          decoration: InputDecoration(labelText: _t('manual_audio_url')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _voiceDurationController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: _t('duration_seconds_manual')),
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
          child: Text(_t('add_voice_by_url')),
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
                                  title: Text(_t('rename_voice')),
                                  content: TextField(
                                    controller: _editVoiceTitleController,
                                    decoration: InputDecoration(labelText: _t('title')),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(_t('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        _editVoiceTitleController.text.trim(),
                                      ),
                                      child: Text(_t('save')),
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
                                  title: Text(_t('delete_voice')),
                                  content: Text(_t('delete_voice_confirm')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(_t('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(_t('delete_confirm')),
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
        Text(_t('emergency_contact_card'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: _contactNameController, decoration: InputDecoration(labelText: _t('name'))),
        const SizedBox(height: 8),
        TextField(controller: _contactRelationController, decoration: InputDecoration(labelText: _t('relation'))),
        const SizedBox(height: 8),
        TextField(controller: _contactPhoneController, decoration: InputDecoration(labelText: _t('phone'))),
        const SizedBox(height: 8),
        TextField(controller: _contactCityController, decoration: InputDecoration(labelText: _t('city'))),
        const SizedBox(height: 8),
        TextField(
          controller: _contactMedicalController,
          decoration: InputDecoration(labelText: _t('medical_notes')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t('primary_contact')),
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
          child: Text(_t('save_emergency_contact')),
        ),
        const SizedBox(height: 10),
        ...appState.emergencyContacts.take(5).map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c.contactName} (${c.relation})'),
              subtitle: Text('${c.phone} · ${c.city}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.isPrimary) const Icon(Icons.star, color: Colors.amber),
                  IconButton(
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            _contactNameController.text = c.contactName;
                            _contactRelationController.text = c.relation;
                            _contactPhoneController.text = c.phone;
                            _contactCityController.text = c.city;
                            _contactMedicalController.text = c.medicalNotes;
                            setState(() => _contactPrimary = c.isPrimary);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_t('loaded_into_form'))),
                            );
                          },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            await appState.updateEmergencyContact(
                              contactId: c.id,
                              contactName: c.contactName,
                              relation: c.relation,
                              phone: c.phone,
                              city: c.city,
                              medicalNotes: c.medicalNotes,
                              isPrimary: true,
                            );
                          },
                    icon: const Icon(Icons.star_outline),
                  ),
                  IconButton(
                    onPressed: appState.isBusy
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(_t('delete_contact')),
                                  content: Text(_t('delete_contact_confirm')),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(_t('cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(_t('delete_confirm')),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (ok != true) return;
                            await appState.removeEmergencyContact(c.id);
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            )),
        const Divider(height: 28),
        Text(_t('medical_card'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final card = appState.medicalCard;
            if (!_medicalPrefilled && card != null) {
              _allergiesController.text = card.allergies;
              _medicationsController.text = card.medications;
              _hospitalsController.text = card.hospitals;
              _medicalOtherController.text = card.otherNotes;
              _accompanimentRequested = card.accompanimentRequested;
              _accompanimentNoteController.text = card.accompanimentNote;
              _medicalPrefilled = true;
            }
            return const SizedBox.shrink();
          },
        ),
        TextField(
          controller: _allergiesController,
          decoration: InputDecoration(labelText: _t('allergies')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _medicationsController,
          decoration: InputDecoration(labelText: _t('common_medications')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hospitalsController,
          decoration: InputDecoration(labelText: _t('common_hospitals')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _medicalOtherController,
          decoration: InputDecoration(labelText: _t('other_notes')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t('request_accompaniment')),
          value: _accompanimentRequested,
          onChanged: appState.isBusy ? null : (v) => setState(() => _accompanimentRequested = v),
        ),
        if (_accompanimentRequested) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _accompanimentNoteController,
            decoration: InputDecoration(labelText: _t('accompaniment_note')),
          ),
        ],
        OutlinedButton(
          onPressed: appState.isBusy
              ? null
              : () => appState.upsertMedicalCard(
                    allergies: _allergiesController.text.trim(),
                    medications: _medicationsController.text.trim(),
                    hospitals: _hospitalsController.text.trim(),
                    otherNotes: _medicalOtherController.text.trim(),
                    accompanimentRequested: _accompanimentRequested,
                    accompanimentNote: _accompanimentNoteController.text.trim(),
                  ),
          child: Text(_t('save_medical_card')),
        ),
        const Divider(height: 28),
        Text(_t('smart_care_reminders'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (appState.careReminders.isEmpty)
          Text(_t('no_care_reminders'))
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
              PopupMenuItem<String?>(
                value: 'en',
                child: Text(_t('language_en')),
              ),
              PopupMenuItem<String?>(
                value: 'zh',
                child: Text(_t('language_zh')),
              ),
              PopupMenuItem<String?>(
                value: 'ko',
                child: Text(_t('language_ko')),
              ),
            ],
          ),
          if (appState.hasSupabaseSession && !appState.hasFlaskSession)
            IconButton(
              tooltip: _t('open_cloud_families'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SupabaseFamilyScreen()),
                );
              },
              icon: const Icon(Icons.cloud_outlined),
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
                  apiErrorMessage(appState.error!, (k) => _t(k)),
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
