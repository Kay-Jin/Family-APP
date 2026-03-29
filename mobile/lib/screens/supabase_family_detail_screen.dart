import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:family_mobile/theme/family_theme.dart';
import 'package:family_mobile/widgets/cloud_empty_placeholder.dart';
import 'package:family_mobile/screens/ledger_family_panel.dart';
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
import 'package:provider/provider.dart';
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
  final Map<String, Uint8List> _answerImageDecryptedBytes = {};
  bool _loading = true;
  String? _error;
  bool _submitting = false;
  int _detailTabIndex = 0;

  String _t(String key) => AppStrings.of(context).text(key);

  Widget _sectionQuickChip(int index, String label, IconData icon) {
    final selected = _detailTabIndex == index;
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? const Color(0xFF8E4B36) : null),
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _detailTabIndex = index),
    );
  }

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
      final list = await _dailyRepo.listAnswers(widget.family.id, questionId);
      final paths = list.map((a) => a.imagePath).whereType<String>().where((p) => p.isNotEmpty);
      final signed = await _dailyRepo.signedAnswerImageUrls(paths);
      final imgBytes = <String, Uint8List>{};
      await Future.wait(
        list.map((a) async {
          if (a.answerImageEncryptionVersion >= 1 && !a.answerImageLocked && a.imagePath != null) {
            final b = await _dailyRepo.loadDecryptedAnswerImageBytes(familyId: widget.family.id, answer: a);
            if (b != null) imgBytes[a.id] = b;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _answers[questionId] = list;
        for (final a in list) {
          _answerImageDecryptedBytes.remove(a.id);
        }
        _answerImageDecryptedBytes.addAll(imgBytes);
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.favorite_rounded, size: 20, color: Color(0xFFCC6B5A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.family.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: FamilyAppDecor.scaffoldGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Material(
                color: FamilyAppColors.chipBg,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF8E4B36)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_t('invite_code')}: ${widget.family.inviteCode}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6D5A51),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('cloud_detail_section_picker'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5C4A42),
                        ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sectionQuickChip(0, _t('photos_title'), Icons.photo_library_outlined),
                        const SizedBox(width: 8),
                        _sectionQuickChip(1, _t('nav_play'), Icons.celebration_outlined),
                        const SizedBox(width: 8),
                        _sectionQuickChip(2, _t('care_tab_title'), Icons.volunteer_activism_outlined),
                        const SizedBox(width: 8),
                        _sectionQuickChip(3, _t('ledger_tab_title'), Icons.account_balance_wallet_outlined),
                      ],
                    ),
                  ),
                  Consumer<AppState>(
                    builder: (context, appState, _) {
                      if (appState.hasFlaskSession) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _t('cloud_brief_flask_only'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6D5A51),
                                height: 1.35,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _detailTabIndex,
                children: [
                  SupabaseCloudAlbumPanel(familyId: widget.family.id),
                  _buildCloudQuestionsTab(),
                  SupabaseFamilyCarePanel(
                    familyId: widget.family.id,
                    onOpenPhotosTab: () => setState(() => _detailTabIndex = 0),
                  ),
                  LedgerFamilyPanel(familyId: widget.family.id),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _detailTabIndex,
        onDestinationSelected: (i) => setState(() => _detailTabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_library_outlined),
            selectedIcon: const Icon(Icons.photo_library_rounded),
            label: _t('photos_title'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.celebration_outlined),
            selectedIcon: const Icon(Icons.celebration_rounded),
            label: _t('nav_play'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.volunteer_activism_outlined),
            selectedIcon: const Icon(Icons.volunteer_activism_rounded),
            label: _t('care_tab_title'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: _t('ledger_tab_title'),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudQuestionsTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(_t('daily_questions'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.edit_note_rounded, color: Color(0xFFB45E48)),
                title: Text(_t('cloud_expand_add_question')),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
            )
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
    final decrypted = _answerImageDecryptedBytes[a.id];
    final bodyPlain = a.answerText.trim();
    final body = a.answerTextLocked ? _t('privacy_e2ee_locked_content') : bodyPlain;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (path != null && path.isNotEmpty && a.answerImageLocked)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_t('privacy_e2ee_locked_content'), style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            )
          else if (path != null && path.isNotEmpty && decrypted != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                decrypted,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (path != null && path.isNotEmpty && url != null)
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
