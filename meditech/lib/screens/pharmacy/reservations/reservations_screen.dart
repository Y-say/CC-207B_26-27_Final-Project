import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'reservation_details_drawer.dart';

import '../../../models/branch_reservation.dart';
import '../../../providers/branch_reservation_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_data_table.dart';
import '../../../widgets/tablet/tablet_filter_panel.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

enum RequestedDateFilter {
  anyTime,
  today,
  last7Days,
}

// Tablet screen displaying reservations with filters, search, and view action (Ph-12 & Ph-13)
class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({
    super.key,
    this.onViewReservation,
  });

  final ValueChanged<BranchReservation>? onViewReservation;

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  String _searchQuery = '';
  final Set<String> _selectedStatuses = {};
  RequestedDateFilter _dateFilter = RequestedDateFilter.anyTime;
  bool _onlyRx = false;
  bool _showFilters = false;
  String? _routeOpenApplied;
  SelectedReservationIdNotifier? _reservationSelection;

  String? _openFromRoute() {
    final router = GoRouter.maybeOf(context);
    return router?.state.uri.queryParameters['open'];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final open = _openFromRoute();
    if (open != null && open.isNotEmpty && open != _routeOpenApplied) {
      _routeOpenApplied = open;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedReservationIdProvider.notifier).select(open);
      });
    }
  }

  void _closeDrawer() {
    ref.read(selectedReservationIdProvider.notifier).select(null);
    _routeOpenApplied = null;
    final hadOpenQuery = _openFromRoute() != null;
    if (hadOpenQuery && GoRouter.maybeOf(context) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/reservations');
      });
    }
  }

  static const _statusOptions = [
    'pending',
    'confirmed',
    'ready_for_pickup',
    'completed',
    'rejected',
    'cancelled',
    'expired',
  ];

  static const _statusLabels = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'ready_for_pickup': 'Ready for Pickup',
    'completed': 'Completed',
    'rejected': 'Rejected',
    'cancelled': 'Cancelled',
    'expired': 'Expired',
  };

  int get _activeFilterCount =>
      _selectedStatuses.length +
      (_dateFilter != RequestedDateFilter.anyTime ? 1 : 0) +
      (_onlyRx ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _reservationSelection = ref.read(selectedReservationIdProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(branchReservationsProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _reservationSelection?.select(null);
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedStatuses.clear();
      _dateFilter = RequestedDateFilter.anyTime;
      _onlyRx = false;
    });
  }

  bool _matchesDateFilter(DateTime submittedAt, RequestedDateFilter filter) {
    if (filter == RequestedDateFilter.anyTime) return true;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (filter == RequestedDateFilter.today) {
      return submittedAt.isAfter(todayStart);
    }
    if (filter == RequestedDateFilter.last7Days) {
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      return submittedAt.isAfter(sevenDaysAgo);
    }
    return true;
  }

  List<BranchReservation> _filterReservations(List<BranchReservation> all) {
    final query = _searchQuery.trim().toLowerCase();
    return all.where((res) {
      if (query.isNotEmpty) {
        final matchesRef = res.referenceNo.toLowerCase().contains(query);
        final matchesName = res.customerName.toLowerCase().contains(query);
        if (!matchesRef && !matchesName) return false;
      }

      if (_selectedStatuses.isNotEmpty &&
          !_selectedStatuses.contains(res.status)) {
        return false;
      }

      if (!_matchesDateFilter(res.submittedAt, _dateFilter)) {
        return false;
      }

      if (_onlyRx && !res.hasRx) {
        return false;
      }

      return true;
    }).toList();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('h:mm a').format(dt);
    if (isToday) {
      return 'Today, $timeStr';
    }
    return '${DateFormat('MMM d').format(dt)}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(branchReservationsProvider);
    final selectedId = ref.watch(selectedReservationIdProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                AsyncView<List<BranchReservation>>(
                  value: reservationsAsync,
                  onRetry: () => ref.read(branchReservationsProvider.notifier).refresh(),
                  builder: (allReservations) {
                    final filtered = _filterReservations(allReservations);

                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header row: Title & Count on left, Search Bar & Filters button on right (matching Figma)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow = constraints.maxWidth < 650;
                              final searchAndFilter = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Search Bar (oval rounded input)
                                  SizedBox(
                                    width: isNarrow ? 200 : (constraints.maxWidth < 800 ? 240 : 340),
                                    height: 42,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.2),
                                      ),
                                      child: TextField(
                                        onChanged: (q) => setState(() => _searchQuery = q),
                                        decoration: const InputDecoration(
                                          hintText: 'References or patient name',
                                          hintStyle: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search,
                                            size: 18,
                                            color: Color(0xFF6B7280),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Filter Button (dark green pill with filter icon)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        setState(() => _showFilters = !_showFilters),
                                    icon: const Icon(
                                      Icons.filter_alt_outlined,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      _activeFilterCount > 0
                                          ? 'Filters ($_activeFilterCount)'
                                          : 'Filters',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E6B46),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 42),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reservations',
                                      style: GoogleFonts.inter(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A2E22),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${filtered.length} of ${allReservations.length} reservations',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    searchAndFilter,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Reservations',
                                        style: GoogleFonts.inter(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1A2E22),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${filtered.length} of ${allReservations.length} reservations',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  searchAndFilter,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Table
                          Expanded(
                            child: TabletDataTable<BranchReservation>(
                              compactForDrawer: selectedId != null,
                              showControls: false,
                              searchHint: 'References or patient name',
                              searchQuery: _searchQuery,
                              onSearchChanged: (q) => setState(() => _searchQuery = q),
                              totalCount: allReservations.length,
                              filteredCount: filtered.length,
                              countLabel: 'reservations',
                              activeFilterCount: _activeFilterCount,
                              onFiltersTap: () =>
                                  setState(() => _showFilters = !_showFilters),
                              items: filtered,
                              columns: const [
                                TabletColumn(
                                  title: 'RESERVATION',
                                  priority: TabletColumnPriority.high,
                                  width: 220,
                                ),
                                TabletColumn(
                                  title: 'MEDICINES',
                                  priority: TabletColumnPriority.medium,
                                  width: 220,
                                ),
                                TabletColumn(
                                  title: 'REQUESTED',
                                  priority: TabletColumnPriority.medium,
                                  width: 170,
                                ),
                                TabletColumn(
                                  title: 'STATUS',
                                  priority: TabletColumnPriority.high,
                                  width: 120,
                                ),
                                TabletColumn(
                                  title: 'VIEW',
                                  priority: TabletColumnPriority.high,
                                  width: 72,
                                  alignment: Alignment.center,
                                ),
                              ],
                              rowBuilder: (context, item, index) {
                                final isSelected = item.id == selectedId;
                                final compact = selectedId != null;
                                return [
                                  SizedBox(
                                    width: double.infinity,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${item.referenceNo} · ${item.customerName}',
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : const Color(0xFF1A2E22),
                                            ),
                                          ),
                                        ),
                                        if (item.hasRx) ...[
                                          const SizedBox(width: AppSpacing.xs),
                                          const StatusBadge.rx(),
                                        ],
                                      ],
                                    ),
                                  ),

                                  Text(
                                    item.medicinesSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),

                                  Text(
                                    _formatTimestamp(item.submittedAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),

                                  StatusBadge.reservation(
                                    item.status,
                                    compact: compact,
                                  ),

                                  // View action button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: Icon(
                                      isSelected
                                          ? Icons.visibility
                                          : Icons.visibility_outlined,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    tooltip: 'View details',
                                    onPressed: () {
                                      ref
                                          .read(selectedReservationIdProvider.notifier)
                                          .select(item.id);
                                      widget.onViewReservation?.call(item);
                                    },
                                  ),
                                ];
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Filters popover panel (Ph-13)
                if (_showFilters)
                  Positioned(
                    top: 80,
                    right: AppSpacing.lg,
                    child: _buildFiltersPanel(reservationsAsync.value ?? []),
                  ),
              ],
            ),
          ),

          // Slide-in right drawer when reservation is selected (Ph-14, Ph-17, Ph-18, Ph-37)
          if (selectedId != null)
            ReservationDetailsDrawer(
              reservationId: selectedId,
              onClose: _closeDrawer,
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(List<BranchReservation> allReservations) {
    // Count occurrences per status for display in filter panel
    final statusCounts = <String, int>{};
    for (final opt in _statusOptions) {
      statusCounts[opt] =
          allReservations.where((r) => r.status == opt).length;
    }

    return TabletFilterPanel(
      title: 'Filter reservations',
      activeFilterCount: _activeFilterCount,
      onReset: _resetFilters,
      onApply: () => setState(() => _showFilters = false),
      onClose: () => setState(() => _showFilters = false),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STATUS',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),

          // Status Checkboxes with counts (Ph-13)
          ..._statusOptions.map((statusKey) {
            final isChecked = _selectedStatuses.contains(statusKey);
            final count = statusCounts[statusKey] ?? 0;
            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _selectedStatuses.remove(statusKey);
                  } else {
                    _selectedStatuses.add(statusKey);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: const Color(0xFF2E6B46),
                        side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedStatuses.add(statusKey);
                            } else {
                              _selectedStatuses.remove(statusKey);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusLabels[statusKey] ?? statusKey,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          Text(
            'REQUESTED',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),

          // Requested date filter pills matching Figma
          Row(
            children: [
              _buildDatePill('Any time', RequestedDateFilter.anyTime),
              const SizedBox(width: 8),
              _buildDatePill('Today', RequestedDateFilter.today),
              const SizedBox(width: 8),
              _buildDatePill('Last 7 days', RequestedDateFilter.last7Days),
            ],
          ),

          const SizedBox(height: 18),
          // Only reservations with Rx medicines toggle
          InkWell(
            onTap: () => setState(() => _onlyRx = !_onlyRx),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _onlyRx,
                      activeColor: const Color(0xFF2E6B46),
                      side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) =>
                          setState(() => _onlyRx = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only reservations with Rx medicines',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill(String label, RequestedDateFilter filter) {
    final isSelected = _dateFilter == filter;
    return InkWell(
      onTap: () => setState(() => _dateFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E6B46) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E6B46) : const Color(0xFFD1D5DB),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
