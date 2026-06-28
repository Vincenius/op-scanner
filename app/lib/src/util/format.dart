/// Formats a USD amount for display, e.g. 3.5 -> "$3.50", null -> "—".
String formatUsd(double? amount) {
  if (amount == null) return '—';
  return '\$${amount.toStringAsFixed(2)}';
}
