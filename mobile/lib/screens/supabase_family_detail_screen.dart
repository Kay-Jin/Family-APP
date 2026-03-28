import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/supabase/cloud_daily_answer.dart';
import 'package:family_mobile/supabase/cloud_daily_question.dart';
import 'package:family_mobile/supabase/daily_repository.dart';
import 'package:family_mobile/supabase/family_row.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  List<CloudDailyQuestion> _questions = [];
  final Map<String, List<CloudDailyAnswer>> _answers = {};
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAnswers(String questionId) async {
    try {
      final list = await _dailyRepo.listAnswers(questionId);
      if (mounted) setState(() => _answers[questionId] = list);
    } catch (_) {}
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
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addAnswer(String questionId) async {
    final ctrl = _answerControllerFor(questionId);
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await _dailyRepo.createAnswer(questionId: questionId, answerText: text);
      ctrl.clear();
      await _loadAnswers(questionId);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.family.name),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${_t('invite_code')}: ${widget.family.inviteCode}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
            ),
            const SizedBox(height: 16),
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
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_questions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_t('no_questions'), style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              ..._questions.map((q) => _buildQuestionCard(q)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(CloudDailyQuestion q) {
    final answers = _answers[q.id] ?? [];
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
                    child: Text(_t('no_answers'), style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ...answers.map(
                    (a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.answerText),
                      subtitle: Text('${a.userDisplayName} · ${a.createdAt}'),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _answerControllerFor(q.id),
                  decoration: InputDecoration(
                    labelText: _t('your_answer'),
                  ),
                  maxLines: 2,
                ),
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
}
