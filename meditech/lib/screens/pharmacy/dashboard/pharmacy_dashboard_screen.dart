import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/pharmacy_dashboard_service.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

/// Pharmacy dashboard (Ph-11) — layout matched to MediTech pharmacy wireframe.
class PharmacyDashboardScreen extends StatefulWidget {
  PharmacyDashboardScreen({
    super.key,
    PharmacyDashboardService? service,
    this.staffDisplayName,
    this.staffRoleLabel = 'Staff',
    this.onGoToInventory,
    this.onOpenReservations,
    this.onPendingReservationTap,
  }) : service = service ?? PharmacyDashboardService();

  final PharmacyDashboardService service;
  final String? staffDisplayName;
  final String staffRoleLabel;
  final VoidCallback? onGoToInventory;
  final VoidCallback? onOpenReservations;
  final ValueChanged<String>? onPendingReservationTap;

  @override
  State<PharmacyDashboardScreen> createState() =>
      _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.service.loadDashboard();
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = widget.service.loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _DashboardError(
            message: snapshot.error?.toString() ??
                'No dashboard data available.',
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        final reservationCounts =
            Map<String, int>.from(data['reservation_counts'] as Map);
        final subtitles = Map<String, String>.from(
          (data['reservation_subtitles'] as Map?) ?? const {},
        );
        final oldestPending =
            List<Map<String, dynamic>>.from(data['oldest_pending'] as List);
        final inventorySnapshot =
            Map<String, int>.from(data['inventory_snapshot'] as Map);

        return _DashboardContent(
          staffDisplayName: widget.staffDisplayName,
          staffRoleLabel: widget.staffRoleLabel,
          reservationCounts: reservationCounts,
          reservationSubtitles: subtitles,
          oldestPending: oldestPending,
          inventorySnapshot: inventorySnapshot,
          onRefresh: _refresh,
          onGoToInventory: widget.onGoToInventory,
          onOpenReservations: widget.onOpenReservations,
          onPendingReservationTap: widget.onPendingReservationTap,
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.staffDisplayName,
    required this.staffRoleLabel,
    required this.reservationCounts,
    required this.reservationSubtitles,
    required this.oldestPending,
    required this.inventorySnapshot,
    required this.onRefresh,
    this.onGoToInventory,
    this.onOpenReservations,
    this.onPendingReservationTap,
  });

  final String? staffDisplayName;
  final String staffRoleLabel;
  final Map<String, int> reservationCounts;
  final Map<String, String> reservationSubtitles;
  final List<Map<String, dynamic>> oldestPending;
  final Map<String, int> inventorySnapshot;
  final VoidCallback onRefresh;
  final VoidCallback? onGoToInventory;
  final VoidCallback? onOpenReservations;
  final ValueChanged<String>? onPendingReservationTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d, y').format(now);
    final name = staffDisplayName?.trim();
    final welcome = name == null || name.isEmpty
        ? 'Welcome, $staffRoleLabel'
        : 'Welcome, $name';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      welcome,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final stats = _StatCardGrid(
                cards: [
                  _StatCardData(
                    title: 'Pending reservations',
                    value: reservationCounts['pending'] ?? 0,
                    subtitle:
                        reservationSubtitles['pending'] ?? 'Needs attention',
                    accent: const Color(0xFF6B7280),
                    icon: Icons.access_time_rounded,
                  ),
                  _StatCardData(
                    title: 'Confirmed reservations',
                    value: reservationCounts['confirmed'] ?? 0,
                    subtitle: reservationSubtitles['confirmed'] ??
                        '+4 from yesterday',
                    accent: const Color(0xFF6B7280),
                    icon: Icons.inventory_2_outlined,
                  ),
                  _StatCardData(
                    title: 'Ready for pickup',
                    value: reservationCounts['ready_for_pickup'] ?? 0,
                    subtitle:
                        reservationSubtitles['ready_for_pickup'] ?? '2 nearing deadline',
                    accent: const Color(0xFF6B7280),
                    icon: Icons.check_box_outlined,
                  ),
                  _StatCardData(
                    title: 'Completed reservations',
                    value: reservationCounts['completed'] ?? 0,
                    subtitle:
                        reservationSubtitles['completed'] ?? '90% fulfillment',
                    accent: const Color(0xFF6B7280),
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              );

              final pendingPanel = _PendingRequestsPanel(
                reservations: oldestPending,
                onOpenAll: onOpenReservations,
                onTap: onPendingReservationTap,
              );

              final inventoryPanel = _InventorySnapshotPanel(
                snapshot: inventorySnapshot,
                onGoToInventory: onGoToInventory,
              );

              if (wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stats,
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: pendingPanel),
                        const SizedBox(width: AppSpacing.xl),
                        Expanded(flex: 2, child: inventoryPanel),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stats,
                  const SizedBox(height: AppSpacing.xl),
                  pendingPanel,
                  const SizedBox(height: AppSpacing.xl),
                  inventoryPanel,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    this.icon,
  });

  final String title;
  final int value;
  final String subtitle;
  final Color accent;
  final IconData? icon;
}

class _StatCardGrid extends StatelessWidget {
  const _StatCardGrid({required this.cards});

  final List<_StatCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 720 ? 4 : 2;
        final gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _StatCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    final valueText =
        data.value < 10 ? data.value.toString().padLeft(2, '0') : '${data.value}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A1A2E22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (data.icon != null) ...[
                Icon(
                  data.icon,
                  size: 16,
                  color: const Color(0xFF306C42),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            valueText,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w400,
              height: 1,
              color: const Color(0xFF1A2E22),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: data.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestsPanel extends StatelessWidget {
  const _PendingRequestsPanel({
    required this.reservations,
    this.onOpenAll,
    this.onTap,
  });

  final List<Map<String, dynamic>> reservations;
  final VoidCallback? onOpenAll;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A1A2E22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pending requests',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: Color(0xFFD8E8DE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Oldest first',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (reservations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'No pending reservations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            for (var i = 0; i < reservations.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _PendingRequestRow(
                reservation: reservations[i],
                onTap: onTap,
              ),
            ],
          if (onOpenAll != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpenAll,
                child: const Text('View all reservations'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingRequestRow extends StatelessWidget {
  const _PendingRequestRow({
    required this.reservation,
    this.onTap,
  });

  final Map<String, dynamic> reservation;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final reference = reservation['reference_no']?.toString() ?? '—';
    final customer = reservation['customer_name']?.toString() ?? 'Customer';
    final line = reservation['line_summary']?.toString() ?? 'Items pending';
    final hasRx = reservation['has_rx'] == true;
    final submittedAt =
        DateTime.tryParse(reservation['submitted_at']?.toString() ?? '');
    final timeLabel = submittedAt == null
        ? '—'
        : DateFormat('MMM d, h:mm a').format(submittedAt.toLocal());
    final id = reservation['id']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0x081A2E22),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: id.isEmpty ? null : () => onTap?.call(id),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 18,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          reference,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: const Color(0xFF1A2E22),
                          ),
                        ),
                        if (hasRx)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Rx',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$customer • $line',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventorySnapshotPanel extends StatelessWidget {
  const _InventorySnapshotPanel({
    required this.snapshot,
    this.onGoToInventory,
  });

  final Map<String, int> snapshot;
  final VoidCallback? onGoToInventory;

  static const _rows = [
    (key: 'active_listings', label: 'Active listings'),
    (key: 'low_stock', label: 'Low stock'),
    (key: 'marked_out_of_stock', label: 'Marked out of stock'),
    (key: 'unavailable', label: 'Unavailable'),
    (key: 'unconfirmed', label: 'Unconfirmed (not updated in 7 days)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A1A2E22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inventory snapshot',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final row in _rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${snapshot[row.key] ?? 0}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (row != _rows.last)
              const Divider(height: 1, color: AppColors.border),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onGoToInventory,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF306C42),
              side: const BorderSide(color: Color(0xFF306C42)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Go to Inventory',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load the dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}