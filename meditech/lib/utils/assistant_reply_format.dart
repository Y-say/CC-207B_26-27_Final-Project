// Normalize MediPal replies: peso currency and plain text (no markdown asterisks).
String polishAssistantReply(String text) {
  var out = text.replaceAllMapped(
    RegExp(r'\$(\d+(?:\.\d{1,2})?)'),
    (match) => '₱${match.group(1)}',
  );
  out = out.replaceAll(RegExp(r'\bUSD\b', caseSensitive: false), 'PHP');
  out = out.replaceAll(RegExp(r'\bdollars?\b', caseSensitive: false), 'pesos');
  out = out.replaceAllMapped(RegExp(r'\*\*([^*\n]+)\*\*'), (m) => m.group(1)!);
  out = out.replaceAllMapped(
    RegExp(r'(?<!\w)\*([^*\n]+)\*(?!\w)'),
    (m) => m.group(1)!,
  );
  out = out.replaceAll(RegExp(r'^\s*[*•]\s+', multiLine: true), '- ');
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return out.trim();
}

@Deprecated('Use polishAssistantReply')
String normalizeAssistantCurrency(String text) => polishAssistantReply(text);

/// Short follow-up chips from the last user question.
List<String> assistantFollowUpSuggestions(String? lastUserMessage) {
  if (lastUserMessage == null || lastUserMessage.trim().isEmpty) {
    return const [
      'What pharmacies are open near me right now?',
      'What is the status of my reservation?',
      'Where can I find paracetamol 500mg?',
    ];
  }
  final q = lastUserMessage.toLowerCase();
  if (q.contains('reserv') || q.contains('order') || q.contains('pickup')) {
    return const [
      'Track my reservations',
      'When does my reservation expire?',
      'How do I cancel a pending reservation?',
    ];
  }
  if (q.contains('near') || q.contains('open') || q.contains('pharmac')) {
    return const [
      'How do I get directions to a pharmacy?',
      'Which pharmacy is closest?',
      'What pharmacies are open near me right now?',
    ];
  }
  if (q.contains('price') || q.contains('cheap') || q.contains('cost')) {
    return const [
      'Compare prices at another pharmacy',
      'Where can I find this medicine?',
      'How do I place a reservation?',
    ];
  }
  if (q.contains('medicine') ||
      q.contains('find') ||
      q.contains('paracetamol') ||
      q.contains('biogesic') ||
      q.contains('losartan')) {
    return const [
      'Where is the cheapest price?',
      'Recommend a pharmacy for this medicine',
      'How do I add it to my cart?',
    ];
  }
  return const [
    'What is the status of my reservation?',
    'What pharmacies are open near me right now?',
    'How do I place a reservation?',
  ];
}