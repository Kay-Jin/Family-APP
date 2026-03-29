import 'dart:async';

import 'package:family_mobile/l10n/app_strings.dart';
import 'package:flutter/material.dart';

/// Low-friction "same five minutes" ritual: timer + ideas (no real-time sync).
class CompanionRoomScreen extends StatefulWidget {
  const CompanionRoomScreen({super.key});

  @override
  State<CompanionRoomScreen> createState() => _CompanionRoomScreenState();
}

class _CompanionRoomScreenState extends State<CompanionRoomScreen> {
  static const _fiveMin = Duration(minutes: 5);
  Timer? _timer;
  Duration _left = _fiveMin;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer t) {
    if (_left <= const Duration(seconds: 1)) {
      t.cancel();
      setState(() {
        _left = Duration.zero;
        _running = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).text('companion_timer_done'))),
      );
      return;
    }
    setState(() => _left -= const Duration(seconds: 1));
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _left = _fiveMin;
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  String _t(String key) => AppStrings.of(context).text(key);

  String _fmt(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('companion_room_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_t('companion_room_intro'), style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(
            '${_t('companion_timer_remaining')}: ${_fmt(_left)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _running ? null : _start,
            child: Text(_t('companion_timer_start')),
          ),
          const SizedBox(height: 28),
          Text(_t('companion_activity_photos'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(_t('companion_activity_song'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(_t('companion_activity_homework'), style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
