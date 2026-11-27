import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/assistant_branding.dart';
import '../../../providers/assistant_chat_provider.dart';
import '../../../providers/assistant_providers.dart';
import '../../../providers/customer_location_provider.dart';
import '../../../providers/session_providers.dart';
import '../../../utils/assistant_location_snapshot.dart';
import '../../../utils/assistant_reply_format.dart';
import '../../../screens/shared/sign_in_sheet.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// A customer asks a question and sees the assistant's reply
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _question = TextEditingController();
  final _scroll = ScrollController();
  var _busy = false;

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String? _lastUserQuestion(List<AssistantChatLine> lines) {
    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].fromCustomer) return lines[i].text;
    }
    return null;
  }

  Future<void> _send(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _busy) return;

    if (ref.read(sessionProvider) == null) {
      await showCustomerSignInSheet(context);
      if (!mounted || ref.read(sessionProvider) == null) return;
    }

    final chat = ref.read(assistantChatProvider.notifier);
    final priorLines = ref.read(assistantChatProvider);
    setState(() {
      _busy = true;
      chat.addCustomer(trimmed);
      _question.clear();
    });
    _scrollToEnd();

    try {
      final locationAsync = ref.read(customerLocationProvider);
      final place = locationAsync.asData?.value;
      final locationPayload = await buildAssistantLocationPayload(
        cachedPlace: place,
        providerLoading: locationAsync.isLoading,
      );
      final history = priorLines
          .map(
            (line) => {
              'role': line.fromCustomer ? 'user' : 'model',
              'text': line.text,
            },
          )
          .toList();
      final raw = await ref.read(assistantServiceProvider).ask(
            trimmed,
            history: history,
            location: locationPayload.toJson(),
          );
      final answer = polishAssistantReply(raw);
      ref.read(assistantChatProvider.notifier).addAssistant(answer);
    } on AppFailure catch (error) {
      ref.read(assistantChatProvider.notifier).addAssistant(error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToEnd();
      }
    }
  }

  void _useSuggestion(String text) {
    _send(text);
  }

  void _clearChat() {
    ref.read(assistantChatProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(assistantChatProvider);
    final empty = lines.isEmpty;
    final showFollowUps = !empty && !_busy;
    final lastUser = _lastUserQuestion(lines);
    final followUps = assistantFollowUpSuggestions(lastUser);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: const CustomerLocationAppBarTitle(
          heading: assistantDisplayName,
          icon: assistantIcon,
        ),
        actions: [
          if (lines.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: _clearChat,
              icon: const Icon(Icons.edit_square, size: 22),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              children: [
                if (empty && !_busy) ...[
                  _WelcomeCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _SuggestionSection(
                    title: 'Suggested prompts',
                    suggestions: assistantFollowUpSuggestions(null),
                    onTap: _useSuggestion,
                  ),
                ] else ...[
                  for (final line in lines)
                    _MessageRow(
                      fromCustomer: line.fromCustomer,
                      text: line.text,
                    ),
                  if (_busy) const _TypingRow(),
                  if (showFollowUps) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _SuggestionSection(
                      title: 'Suggested follow-ups',
                      suggestions: followUps,
                      onTap: _useSuggestion,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _Composer(
            controller: _question,
            busy: _busy,
            onSend: () => _send(_question.text),
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AssistantAvatar(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '$assistantDisplayName helps you find medicines and track reservations in MediTech. '
                  'Prices are in pesos (₱). I do not give medical advice.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'How can I help you today?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primaryLight,
      child: Icon(assistantIcon, size: 20, color: AppColors.primary),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.fromCustomer, required this.text});

  final bool fromCustomer;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (fromCustomer) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.neutralLight,
              child: Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AssistantAvatar(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.neutralLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          _AssistantAvatar(),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.neutralLight,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const SizedBox(
              width: 28,
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TypingDot(delay: 0),
                  _TypingDot(delay: 1),
                  _TypingDot(delay: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = (_controller.value + widget.delay * 0.2) % 1.0;
        final opacity = 0.35 + (phase < 0.5 ? phase * 1.3 : (1 - phase) * 1.3);
        return Opacity(
          opacity: opacity.clamp(0.35, 1.0),
          child: const Icon(Icons.circle, size: 6, color: AppColors.primary),
        );
      },
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  const _SuggestionSection({
    required this.title,
    required this.suggestions,
    required this.onTap,
  });

  final String title;
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                label: Text(
                  suggestion,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                onPressed: () => onTap(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final canSend = !busy && controller.text.trim().isNotEmpty;

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask Medipal',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: canSend ? onSend : null,
                style: IconButton.styleFrom(
                  backgroundColor: canSend ? AppColors.primary : AppColors.neutralLight,
                  foregroundColor: canSend ? Colors.white : AppColors.textMuted,
                  minimumSize: const Size(44, 44),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}