import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One line in the Medipal thread (kept when leaving and re-opening the screen).
class AssistantChatLine {
  const AssistantChatLine({required this.fromCustomer, required this.text});

  final bool fromCustomer;
  final String text;
}

class AssistantChatNotifier extends Notifier<List<AssistantChatLine>> {
  @override
  List<AssistantChatLine> build() => [];

  void addCustomer(String text) {
    state = [...state, AssistantChatLine(fromCustomer: true, text: text)];
  }

  void addAssistant(String text) {
    state = [...state, AssistantChatLine(fromCustomer: false, text: text)];
  }

  void clear() {
    state = [];
  }
}

final assistantChatProvider =
    NotifierProvider<AssistantChatNotifier, List<AssistantChatLine>>(
  AssistantChatNotifier.new,
);