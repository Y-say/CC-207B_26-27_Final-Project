import 'package:flutter/material.dart';

// Displays a confirmation dialog matching MediTech tablet wireframes
Future<bool?> showTabletConfirmDialog({
  required BuildContext context,
  required String title,
  String? targetName,
  List<String>? items,
  String? itemsLabel,
  String? message,
  List<String> consequences = const [],
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Go back',
  bool isDanger = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 16,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDanger ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: isDanger ? const Color(0xFFD32F2F) : const Color(0xFF1E6B3E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),

              if (targetName != null) ...[
                const SizedBox(height: 12),
                Text(
                  targetName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],

              if (items != null && items.length > 1) ...[
                const SizedBox(height: 16),
                _SelectedItemsDropdown(items: items, label: itemsLabel),
              ],

              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],

              if (consequences.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'WHAT WILL HAPPEN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in consequences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // Dialog Buttons
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                        ),
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDanger ? const Color(0xFFD32F2F) : const Color(0xFF1E6B3E),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Displays a reason dialog (5 to 200 characters) for reject/cancel/deactivate actions
Future<String?> showTabletReasonDialog({
  required BuildContext context,
  required String title,
  required String explanation,
  String placeholder = 'Enter your reason here...',
  String actionLabel = 'Submit',
  String cancelLabel = 'Go back',
  bool isDanger = true,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final text = controller.text.trim();
          final isValid = text.length >= 5 && text.length <= 200;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    explanation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Required, 5–200 characters.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text area
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    maxLength: 200,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      counterText: '${controller.text.length}/200',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDanger ? const Color(0xFFD32F2F) : const Color(0xFF1E6B3E),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 44,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            child: Text(
                              cancelLabel,
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isValid
                                ? () => Navigator.of(context).pop(controller.text.trim())
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDanger ? const Color(0xFFD32F2F) : const Color(0xFF1E6B3E),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFE5E7EB),
                              disabledForegroundColor: const Color(0xFF9CA3AF),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// Informational modal (errors, policy) — same chrome as confirmation dialogs
Future<void> showTabletMessageDialog({
  required BuildContext context,
  required String title,
  String? message,
  List<String> bullets = const [],
  bool isWarning = true,
  String buttonLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 16,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isWarning
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: isWarning ? const Color(0xFFD32F2F) : const Color(0xFF1E6B3E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
              ],
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                for (final item in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF374151),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6B3E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Zoomable preview for an uploaded photo (LTO scan, storefront, etc.)
Future<void> showTabletImageViewer({
  required BuildContext context,
  required String imageUrl,
  String title = 'Document preview',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final maxW = (size.width * 0.88).clamp(360.0, 760.0);
      final maxDialogH = (size.height - 48).clamp(320.0, 720.0);

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: maxW,
            height: maxDialogH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ColoredBox(
                    color: const Color(0xFFF3F4F6),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Could not load this image.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Collapsible dropdown for showing multiple selected items without cramping the dialog
class _SelectedItemsDropdown extends StatefulWidget {
  const _SelectedItemsDropdown({required this.items, this.label});

  final List<String> items;
  final String? label;

  @override
  State<_SelectedItemsDropdown> createState() => _SelectedItemsDropdownState();
}

class _SelectedItemsDropdownState extends State<_SelectedItemsDropdown> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label ?? '${widget.items.length} selected medicines',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, index) => Text(
                  '•  ${widget.items[index]}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
