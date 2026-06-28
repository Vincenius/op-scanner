/// Formats a USD amount for display, e.g. 3.5 -> "$3.50", null -> "—".
String formatUsd(double? amount) {
  if (amount == null) return '—';
  return '\$${amount.toStringAsFixed(2)}';
}

/// Short relative time, e.g. "just now", "5m ago", "3h ago", "2d ago".
String formatRelative(DateTime? when) {
  if (when == null) return 'never';
  final d = DateTime.now().difference(when.toLocal());
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  final m = when.toLocal();
  return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
}

/// YYYY-MM-DD for a date.
String formatDate(DateTime when) {
  final m = when.toLocal();
  return '${m.year}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
}
