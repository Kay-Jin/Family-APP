import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats an ISO-8601 timestamp from the API for display in the user's locale.
String formatIsoDateTimeLocal(BuildContext context, String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }
  final locale = Localizations.localeOf(context);
  final loc = locale.toString();
  final local = parsed.toLocal();
  return DateFormat.yMMMd(loc).add_jm().format(local);
}
