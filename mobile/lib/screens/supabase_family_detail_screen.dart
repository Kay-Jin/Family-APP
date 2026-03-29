import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/widgets/cloud_empty_placeholder.dart';
import 'package:family_mobile/screens/supabase_cloud_album_panel.dart';
import 'package:family_mobile/screens/supabase_family_care_panel.dart';
import 'package:family_mobile/supabase/cloud_daily_answer.dart';
import 'package:family_mobile/supabase/cloud_daily_question.dart';
import 'package:family_mobile/supabase/daily_repository.dart';
import 'package:family_mobile/supabase/family_row.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/util/date_time_display.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class SupabaseFamilyDetailScreen extends StatefulWidget {
  const SupabaseFamilyDetailScreen({super.key, required this.family});

  final FamilyRow family;

  @override
  State<SupabaseFamilyDetailScreen> createState() => _SupabaseFamilyDetailScreenState();
}

class _SupabaseFamilyDetailScreenState extends State<SupabaseFamilyDetailScreen> {
  final _dailyRepo = DailyRepository();
  final _dateController = TextEditingController();
  final _questionTextController = TextEditingController();
  final Map<String, TextEditingController> _answerControllers = {};
  final Map<String, Uint8List> _pendingAnswerImageBytes = {};
  final Map<String, String> _pendingAnswerImageExt = {};

  List<CloudDailyQuestion> _questions = [];
  final Map<String, List<CloudDailyAnswer>> _answers = {};
  final Map<String, String> _answerImageSignedUrlByPath = {};
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  String _t(String key) => AppStrings.of(context).text(key);

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _questionTextController.dispose();
    for (final c in _answerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _answerControllerFor(String questionId) {
    return _answerControllers.putIfAbsent(questionId, TextEditingController.new);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _dailyRepo.listQuestions(widget.family.id);
      setState(() => _questions = list);
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAnswers(String questionId) async {
    try {
      final list = await _dailyRepo.listAnswers(questionId);
      final paths = list.map((a) => a.imagePath).whereType<String>().where((p) => p.isNotEmpty);
      final signed = await _dailyRepo.signedAnswerImageUrls(paths);
      if (!mounted) return;
      setState(() {
        _answers[questionId] = list;
        for (final e in signed.entries) {
          _answerImageSignedUrlByPath[e.key] = e.value;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, _t))),
      );
    }
  }

  Future<void> _addQuestion() async {
    final date = _dateController.text.trim();
    final text = _questionTextController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = _t('question_text_required'));
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      setState(() => _error = _t('question_date_invalid'));
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await _dailyRepo.createQuestion(
        familyId: widget.family.id,
        questionDate: date,
        questionText: text,
      );
      _questionTextController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('snack_question_added'))),
        );
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickAnswerImage(String questionId) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('answer_image_web_hint'))),
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
      _pendingAnswerImageBytes[questionId] = bytes;
      _pendingAnswerImageExt[questionId] = ext;
    });
  }

  void _clearPendingImage(String questionId) {
    setState(() {
      _pendingAnswerImageBytes.remove(questionId);
      _pendingAnswerImageExt.remove(questionId);
    });
  }

  Future<void> _addAnswer(String questionId) async {
    final ctrl = _answerControllerFor(questionId);
    final text = ctrl.text.trim();
    final imgBytes = _pendingAnswerImageBytes[questionId];
    if (text.isEmpty && (imgBytes == null || imgBytes.isEmpty)) {
      setState(() => _error = _t('answer_text_or_image_required'));
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await _dailyRepo.createAnswer(
        familyId: widget.family.id,
        questionId: questionId,
        answerText: text,
        imageBytes: imgBytes,
        imageExtension: _pendingAnswerImageExt[questionId],
      );
      ctrl.clear();
      _clearPendingImage(questionId);
      await _loadAnswers(questionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('snack_answer_added'))),
        );
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.family.name),
          bottom: TabBar(
            tabs: [
              Tab(text: _t('daily_questions')),
              Tab(text: _t('photos_title')),
              Tab(text: _t('care_tab_title')),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '${_t('invite_code')}: ${widget.family.inviteCode}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(_t('daily_questions'), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _dateController,
                          decoration: InputDecoration(labelText: _t('question_date')),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _questionTextController,
                          decoration: InputDecoration(labelText: _t('question_text')),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _submitting ? null : _addQuestion,
                          child: Text(_t('add_question')),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],
                        const SizedBox(height: 20),
                        if (_loading)
                          const Center(
                              child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                        else if (_questions.isEmpty)
                          CloudEmptyPlaceholder(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: _t('no_questions'),
                            subtitle: _t('cloud_empty_questions_hint'),
                          )
                        else
                          ..._questions.map((q) => _buildQuestionCard(q)),
                      ],
                    ),
                  ),
                  SupabaseCloudAlbumPanel(familyId: widget.family.id),
                  Builder(
                    builder: (ctx) => SupabaseFamilyCarePanel(
                      familyId: widget.family.id,
                      onOpenPhotosTab: () => DefaultTabController.of(ctx).animateTo(1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(CloudDailyQuestion q) {
    final answers = _answers[q.id] ?? [];
    final pending = _pendingAnswerImageBytes[q.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded && !_answers.containsKey(q.id)) {
            _loadAnswers(q.id);
          }
        },
        title: Text(q.questionDate, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          q.questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(q.questionText, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(_t('answers'), style: Theme.of(context).textTheme.titleSmall),
                if (answers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t('no_answers'), style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text(
                          _t('cloud_empty_answers_hint'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6D5A51),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  ...answers.map((a) => _buildAnswerTile(a)),
                const SizedBox(height: 8),
                TextField(
                  controller: _answerControllerFor(q.id),
                  decoration: InputDecoration(
                    labelText: _t('your_answer'),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : () => _pickAnswerImage(q.id),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_t('attach_answer_image')),
                ),
                if (pending != null && pending.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          pending,
                          height: 72,
                          width: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_t('answer_image_ready'))),
                      IconButton(
                        onPressed: _submitting ? null : () => _clearPendingImage(q.id),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _submitting ? null : () => _addAnswer(q.id),
                    child: Text(_t('answer_question')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerTile(CloudDailyAnswer a) {
    final path = a.imagePath;
    final url = path != null && path.isNotEmpty ? _answerImageSignedUrlByPath[path] : null;
    final body = a.answerText.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (path != null && path.isNotEmpty && url != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_t('answer_image_failed'), style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            )
          else if (path != null && path.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_t('answer_image_failed'), style: Theme.of(context).textTheme.bodySmall),
            ),
          if (body.isNotEmpty) Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            '${a.userDisplayName} · ${formatIsoDateTimeLocal(context, a.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
