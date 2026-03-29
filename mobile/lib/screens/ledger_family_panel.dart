import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/supabase/ledger_book_row.dart';
import 'package:family_mobile/supabase/ledger_repository.dart';
import 'package:family_mobile/supabase/ledger_transaction_row.dart';
import 'package:family_mobile/util/api_error_message.dart';
import 'package:family_mobile/widgets/cloud_empty_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class _AddEntryResult {
  const _AddEntryResult({
    required this.isExpense,
    required this.amount,
    required this.occurredOn,
    required this.category,
    this.note,
  });

  final bool isExpense;
  final double amount;
  final String occurredOn;
  final String category;
  final String? note;

  double get signedAmount => isExpense ? -amount : amount;
}

/// Cloud household ledger: create books, add income/expense lines (Supabase `ledger_*` tables).
class LedgerFamilyPanel extends StatefulWidget {
  const LedgerFamilyPanel({super.key, required this.familyId});

  final String familyId;

  @override
  State<LedgerFamilyPanel> createState() => _LedgerFamilyPanelState();
}

class _LedgerFamilyPanelState extends State<LedgerFamilyPanel> {
  final _repo = LedgerRepository();
  final _newBookController = TextEditingController();

  List<LedgerBookRow> _books = [];
  LedgerBookRow? _selected;
  List<LedgerTransactionRow> _transactions = [];
  String? _myRole;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _showArchived = false;

  static const _categorySlugs = [
    'food',
    'transport',
    'shopping',
    'bills',
    'medical',
    'entertainment',
    'salary',
    'other',
  ];

  @override
  void dispose() {
    _newBookController.dispose();
    super.dispose();
  }

  String _t(String k) => AppStrings.of(context).text(k);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => _reloadAll();

  Future<void> _reloadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await _repo.listBooks(familyId: widget.familyId, includeArchived: _showArchived);
      var sel = _selected;
      if (sel != null) {
        final keepId = sel.id;
        if (!books.any((b) => b.id == keepId)) {
          sel = null;
        }
      }
      sel ??= books.isEmpty ? null : books.first;

      if (sel == null) {
        if (!mounted) return;
        setState(() {
          _books = books;
          _selected = null;
          _myRole = null;
          _transactions = [];
          _loading = false;
        });
        return;
      }

      final role = await _repo.myRoleForLedger(sel.id);
      final txs = await _repo.listTransactions(sel.id);
      if (!mounted) return;
      setState(() {
        _books = books;
        _selected = sel;
        _myRole = role;
        _transactions = txs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, _t);
        _loading = false;
      });
    }
  }

  Future<void> _reloadSelectedLedger() async {
    final sel = _selected;
    if (sel == null) return;
    setState(() => _busy = true);
    try {
      final role = await _repo.myRoleForLedger(sel.id);
      final txs = await _repo.listTransactions(sel.id);
      if (!mounted) return;
      setState(() {
        _myRole = role;
        _transactions = txs;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, _t);
        _busy = false;
      });
    }
  }

  bool get _isOwner => _myRole == 'owner';

  double _monthNet() {
    final now = DateTime.now();
    final p = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _transactions.where((t) => t.occurredOn.startsWith(p)).fold<double>(0, (s, e) => s + e.amount);
  }

  Future<void> _createBook() async {
    final name = _newBookController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('ledger_book_name'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final b = await _repo.createBook(familyId: widget.familyId, name: name);
      _newBookController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('ledger_snack_book_created'))));
      setState(() => _selected = b);
      await _reloadAll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, _t));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addEntry() async {
    final book = _selected;
    if (book == null || !_isOwner) return;
    final res = await showModalBottomSheet<_AddEntryResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddLedgerEntrySheet(
        categorySlugs: _categorySlugs,
        strings: AppStrings.of(ctx),
      ),
    );
    if (res == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.createTransaction(
        ledgerId: book.id,
        signedAmount: res.signedAmount,
        occurredOn: res.occurredOn,
        category: res.category,
        note: res.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('ledger_snack_entry_added'))));
      await _reloadSelectedLedger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEntry(LedgerTransactionRow row) async {
    if (!_isOwner) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('ledger_delete_entry_title')),
        content: Text(_t('ledger_delete_entry_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('delete_confirm'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteTransaction(row.id);
      await _reloadSelectedLedger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archiveBook({required bool archive}) async {
    final book = _selected;
    if (book == null || !_isOwner) return;
    setState(() => _busy = true);
    try {
      await _repo.setBookArchived(ledgerId: book.id, archived: archive);
      if (!mounted) return;
      await _reloadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeleteBook() async {
    final book = _selected;
    if (book == null || !_isOwner) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('ledger_delete_book_title')),
        content: Text(_t('ledger_delete_book_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('delete_confirm'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteBook(book.id);
      if (!mounted) return;
      setState(() => _selected = null);
      await _reloadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, _t))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }

    LedgerBookRow? dropdownValue;
    if (_selected != null) {
      for (final b in _books) {
        if (b.id == _selected!.id) {
          dropdownValue = b;
          break;
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFFFFF4EC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFB45E48)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t('ledger_intro'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6D5A51),
                            height: 1.35,
                          ),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('ledger_show_archived')),
            value: _showArchived,
            onChanged: _busy
                ? null
                : (v) async {
                    setState(() => _showArchived = v);
                    await _refresh();
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newBookController,
            decoration: InputDecoration(labelText: _t('ledger_book_name')),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _createBook(),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _createBook,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(_t('ledger_create_book')),
          ),
          if (_books.isEmpty) ...[
            const SizedBox(height: 24),
            CloudEmptyPlaceholder(
              icon: Icons.receipt_long_outlined,
              title: _t('ledger_empty'),
              subtitle: _t('ledger_empty_hint'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<LedgerBookRow>(
                    value: dropdownValue,
                    decoration: InputDecoration(labelText: _t('ledger_transactions')),
                    items: _books
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              b.isArchived ? '${b.name} (${_t('ledger_archived')})' : b.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (b) async {
                            if (b == null) return;
                            setState(() => _selected = b);
                            await _reloadSelectedLedger();
                          },
                  ),
                ),
                if (_selected != null && _isOwner)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'archive') await _archiveBook(archive: true);
                      if (v == 'unarchive') await _archiveBook(archive: false);
                      if (v == 'delete') await _confirmDeleteBook();
                    },
                    itemBuilder: (ctx) => [
                      if (_selected!.isArchived)
                        PopupMenuItem(value: 'unarchive', child: Text(_t('ledger_unarchive')))
                      else
                        PopupMenuItem(value: 'archive', child: Text(_t('ledger_archive'))),
                      PopupMenuItem(value: 'delete', child: Text(_t('ledger_delete_book'))),
                    ],
                  ),
              ],
            ),
            if (_selected != null && !_isOwner) ...[
              const SizedBox(height: 8),
              Text(
                _t('ledger_viewer_read_only'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6D5A51)),
              ),
            ],
            if (_selected != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFFB45E48)),
                      const SizedBox(width: 10),
                      Text(
                        _t('ledger_this_month'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        NumberFormat.currency(symbol: '').format(_monthNet()),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isOwner)
                FilledButton.icon(
                  onPressed: _busy ? null : _addEntry,
                  icon: const Icon(Icons.add_chart_rounded),
                  label: Text(_t('ledger_add_entry')),
                ),
              const SizedBox(height: 12),
              if (_transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(_t('ledger_no_transactions'))),
                )
              else
                ..._transactions.map(
                  (tx) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        tx.isExpense ? Icons.south_west_rounded : Icons.north_east_rounded,
                        color: tx.isExpense ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                      title: Text(
                        '${tx.isExpense ? '' : '+'}${NumberFormat.currency(symbol: '').format(tx.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tx.isExpense ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                      subtitle: Text(
                        '${tx.occurredOn} · ${_t('ledger_cat_${tx.category}')}${tx.note != null && tx.note!.isNotEmpty ? '\n${tx.note}' : ''}',
                      ),
                      isThreeLine: tx.note != null && tx.note!.isNotEmpty,
                      trailing: _isOwner
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy ? null : () => _deleteEntry(tx),
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AddLedgerEntrySheet extends StatefulWidget {
  const _AddLedgerEntrySheet({
    required this.categorySlugs,
    required this.strings,
  });

  final List<String> categorySlugs;
  final AppStrings strings;

  @override
  State<_AddLedgerEntrySheet> createState() => _AddLedgerEntrySheetState();
}

class _AddLedgerEntrySheetState extends State<_AddLedgerEntrySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _expense = true;
  String _category = 'other';
  DateTime _date = DateTime.now();

  String _t(String k) => widget.strings.text(k);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _amount.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('ledger_invalid_amount'))));
      return;
    }
    final y = _date.year;
    final m = _date.month.toString().padLeft(2, '0');
    final d = _date.day.toString().padLeft(2, '0');
    Navigator.pop(
      context,
      _AddEntryResult(
        isExpense: _expense,
        amount: v,
        occurredOn: '$y-$m-$d',
        category: _category,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('ledger_add_entry'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(_t('ledger_expense')), icon: const Icon(Icons.remove_circle_outline)),
              ButtonSegment(value: false, label: Text(_t('ledger_income')), icon: const Icon(Icons.add_circle_outline)),
            ],
            selected: {_expense},
            onSelectionChanged: (s) => setState(() => _expense = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            decoration: InputDecoration(labelText: _t('ledger_amount')),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('ledger_date')),
            subtitle: Text(DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(labelText: _t('ledger_category')),
            items: widget.categorySlugs
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(widget.strings.text('ledger_cat_$s')),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'other'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: _t('other_notes')),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: Text(_t('save'))),
        ],
      ),
    );
  }
}
