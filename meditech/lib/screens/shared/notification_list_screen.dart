import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../providers/notification_providers.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/theme/app_colors.dart';
import '../../widgets/theme/app_spacing.dart';

// The signed-in person's notifications, newest first
class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({
    super.key,
    this.onOpen,
    this.embedded = false,
  });

  // Customer app opens the linked reservation. Other apps only mark the row read.
  final void Function(AppNotification item)? onOpen;

  // True when rendered inside the Pharmacy tablet shell (sidebar + top header)
  final bool embedded;

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  static const _recentLimit = 4;
  bool _showAll = false;
  bool _bulkBusy = false;

  Future<void> _open(AppNotification item) async {
    if (item.isUnread) {
      await ref.read(notificationListProvider.notifier).markRead(item.id);
    }
    if (!mounted) return;
    widget.onOpen?.call(item);
  }

  Future<void> _markRead(String id) async {
    try {
      await ref.read(notificationListProvider.notifier).markRead(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(notificationListProvider.notifier).deleteNotification(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    try {
      await ref.read(notificationListProvider.notifier).markAllRead();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _clearAll() async {
    if (_bulkBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Clear notifications?',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A2E22),
          ),
        ),
        content: Text(
          'This removes all notifications from your list. This cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A2E22),
                side: const BorderSide(color: Color(0xFFD8E8DE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                'Clear all',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _bulkBusy = true);
    try {
      await ref.read(notificationListProvider.notifier).clearAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationListProvider);
    final unreadCount = list.maybeWhen(
      data: (items) => items.where((item) => item.isUnread).length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor:
          widget.embedded ? const Color(0xFFF4F6F3) : AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2E22),
                ),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
      body: AsyncView<List<AppNotification>>(
        value: list,
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No notifications yet.',
        onRetry: () => ref.invalidate(notificationListProvider),
        builder: (items) {
          final visible = _showAll ? items : items.take(_recentLimit).toList();
          final canExpand = items.length > _recentLimit;

          final compactPhone = !widget.embedded;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              compactPhone ? AppSpacing.lg : AppSpacing.xl,
              compactPhone ? AppSpacing.md : AppSpacing.xl,
              compactPhone ? AppSpacing.lg : AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              if (widget.embedded)
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2E22),
                    letterSpacing: -0.5,
                  ),
                ),
              if (!widget.embedded && unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    unreadCount == 1 ? '1 unread' : '$unreadCount unread',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: compactPhone ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  if (canExpand)
                    TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2E6B46),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        _showAll ? 'Show recent' : 'View all',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E6B46),
                        ),
                      ),
                    ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _bulkBusy ? null : _markAllRead,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2E6B46),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      child: _bulkBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Mark all as read',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2E6B46),
                              ),
                            ),
                    ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: _bulkBusy ? null : _clearAll,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC93B3B),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFC93B3B),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: compactPhone ? 14 : 18),
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _NotificationCard(
                  item: visible[i],
                  compact: compactPhone,
                  onTap: () => _open(visible[i]),
                  onMarkRead: visible[i].isUnread
                      ? () => _markRead(visible[i].id)
                      : null,
                  onDelete: () => _delete(visible[i].id),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTone {
  const _NotificationTone({
    required this.iconBackground,
    required this.iconForeground,
    required this.icon,
  });

  final Color iconBackground;
  final Color iconForeground;
  final IconData icon;
}

_NotificationTone _toneFor(String type) {
  switch (type) {
    case 'reservation_ready':
    case 'reservation_confirmed':
    case 'reservation_completed':
      return const _NotificationTone(
        iconBackground: Color(0xFFE6F4EA),
        iconForeground: Color(0xFF2E6B46),
        icon: Icons.check_circle_outline,
      );
    case 'new_reservation':
    case 'reservation_reminder':
      return const _NotificationTone(
        iconBackground: Color(0xFFFEF3D6),
        iconForeground: Color(0xFFD97706),
        icon: Icons.receipt_long_outlined,
      );
    case 'reservation_expired':
    case 'reservation_cancelled':
    case 'reservation_rejected':
      return const _NotificationTone(
        iconBackground: Color(0xFFF3F4F6),
        iconForeground: Color(0xFF6B7280),
        icon: Icons.cancel_outlined,
      );
    default:
      return const _NotificationTone(
        iconBackground: Color(0xFFFEF3D6),
        iconForeground: Color(0xFFD97706),
        icon: Icons.receipt_long_outlined,
      );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    this.onMarkRead,
    required this.onDelete,
    this.compact = false,
  });

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback onDelete;
  final bool compact;

  String _formatTime(DateTime createdAt) {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      return DateFormat('h:mm a').format(local);
    }
    return DateFormat('MMM d · h:mm a').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(item.type);
    final timeStr = _formatTime(item.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD8E8DE),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2E22),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20,
              vertical: compact ? 14 : 16,
            ),
            child: compact ? _compactCardContent(tone, timeStr) : _wideCardContent(tone, timeStr),
          ),
        ),
      ),
    );
  }

  Widget _iconBadge(_NotificationTone tone) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: tone.iconBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(tone.icon, size: 20, color: tone.iconForeground),
    );
  }

  Widget _titleText() {
    return Text(
      item.title,
      style: GoogleFonts.inter(
        fontWeight: item.isUnread ? FontWeight.w700 : FontWeight.w600,
        color: const Color(0xFF1A2E22),
        fontSize: 14.5,
        height: 1.25,
      ),
    );
  }

  Widget _bodyText({int maxLines = 2}) {
    if (item.body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        item.body,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF6B7280),
          height: 1.35,
        ),
      ),
    );
  }

  Widget _timeText(String timeStr) {
    return Text(
      timeStr,
      style: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }

  Widget _actionButtons({bool showLabels = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMarkRead != null)
          showLabels
              ? Tooltip(
                  message: 'Mark as read',
                  child: TextButton.icon(
                    onPressed: onMarkRead,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark read'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2E6B46),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Mark as read',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onMarkRead,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF2E6B46),
                    size: 19,
                  ),
                ),
        IconButton(
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onDelete,
          icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  /// Phone layout: icon + stacked title/body/time; actions on their own row.
  Widget _compactCardContent(_NotificationTone tone, String timeStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBadge(tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _titleText()),
                      if (item.isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE65100),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  _bodyText(maxLines: 4),
                  const SizedBox(height: 6),
                  _timeText(timeStr),
                ],
              ),
            ),
          ],
        ),
        if (onMarkRead != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _actionButtons(showLabels: true),
          ),
        ] else ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _actionButtons(),
          ),
        ],
      ],
    );
  }

  /// Tablet layout: single row with inline actions.
  Widget _wideCardContent(_NotificationTone tone, String timeStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _iconBadge(tone),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleText(),
              _bodyText(),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _timeText(timeStr),
        const SizedBox(width: 10),
        if (item.isUnread)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFE65100),
              shape: BoxShape.circle,
            ),
          ),
        _actionButtons(),
      ],
    );
  }
}
