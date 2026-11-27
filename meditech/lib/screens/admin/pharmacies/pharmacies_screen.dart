import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/osm_listing.dart';
import '../../../models/pharmacy_summary.dart';
import '../../../providers/admin_pharmacy_providers.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../listings/osm_listings_screen.dart';
import 'application_drawer.dart';
import 'pharmacy_admin_format.dart';

// Badge for a pharmacy's status (the drawer uses this too)
StatusBadge branchStatusBadge(String status) => switch (status) {
      'pending_approval' => const StatusBadge('Pending Approval', tone: BadgeTone.warning),
      'active' => const StatusBadge('Active', tone: BadgeTone.success),
      'rejected' => const StatusBadge('Rejected', tone: BadgeTone.danger),
      _ => const StatusBadge('Inactive'),
    };

enum _RegistryView { registered, listings }

// Admin pharmacies list with the application drawer (wireframes A-03, A-04)
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({
    super.key,
    this.showHeader = true,
    this.initialChip = 'all',
    this.initialRegistry = 'registered',
    this.drawerInShell = false,
  });

  final bool showHeader;
  final String initialChip;

  /// `registered` or `listings` (OpenStreetMap pharmacies not on MediTech).
  final String initialRegistry;

  /// When true, [AdminShellScreen] renders [ApplicationDrawer] in the frame's right panel.
  final bool drawerInShell;

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  static const _filterOptions = <(String, String)>[
    ('All statuses', 'all'),
    ('Pending Approval', 'pending_approval'),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
    ('Rejected', 'rejected'),
    ('LTO expiring in 60 days', 'lto_expiring'),
  ];

  final _search = TextEditingController();
  late String _filter = widget.initialChip;
  late _RegistryView _view = widget.initialRegistry == 'listings'
      ? _RegistryView.listings
      : _RegistryView.registered;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PharmacySummary> _filtered(List<PharmacySummary> all) {
    final today = DateTime.now();
    final q = _search.text.trim().toLowerCase();

    return all.where((p) {
      final filterOk = switch (_filter) {
        'all' => true,
        'lto_expiring' => isLtoExpiringSoon(p, today),
        _ => p.status == _filter,
      };
      if (!filterOk) return false;
      if (q.isEmpty) return true;
      return [
        p.pharmacyName,
        p.branchName,
        p.address,
        p.ownerName ?? '',
        p.ltoNumber,
        p.displayId,
      ].any((field) => field.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _openFilters() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            RadioGroup<String>(
              groupValue: _filter,
              onChanged: (v) {
                if (v != null) Navigator.pop(context, v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (label, value) in _filterOptions)
                    RadioListTile<String>(
                      value: value,
                      title: Text(label),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _filter = picked);
  }

  void _openRow(String id) {
    final useShell = widget.drawerInShell && MediaQuery.sizeOf(context).width >= 900;
    if (useShell) {
      ref.read(selectedPharmacyProvider.notifier).select(id);
      return;
    }
    _openAsSheet(id);
  }

  Future<void> _openAsSheet(String id) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 420,
          height: MediaQuery.sizeOf(context).height,
          child: ApplicationDrawer(branchId: id, onClose: () => Navigator.pop(context)),
        ),
      ),
    );
    ref.read(selectedPharmacyProvider.notifier).select(null);
  }

  int _shownListingsCount(List<OsmListing>? rows) =>
      rows?.where((l) => l.status == OsmListingStatus.shown).length ?? 0;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(pharmacyListProvider);
    final listings = ref.watch(adminOsmListingsProvider);
    final selected = ref.watch(selectedPharmacyProvider);
    final registeredCount = rows.asData?.value.length ?? 0;
    final listingsCount = _shownListingsCount(listings.asData?.value);
    final shellDrawerOpen =
        widget.drawerInShell && selected != null && MediaQuery.sizeOf(context).width >= 900;
    final compact = widget.drawerInShell ? shellDrawerOpen : selected != null;

    final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showHeader)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pharmacies', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppSpacing.xs),
                          if (_view == _RegistryView.registered)
                            AsyncView<List<PharmacySummary>>(
                              value: rows,
                              onRetry: () => ref.invalidate(pharmacyListProvider),
                              builder: (all) {
                                final n = _filtered(all).length;
                                return Text(
                                  '$n of ${all.length} pharmacies',
                                  style: const TextStyle(color: AppColors.textMuted),
                                );
                              },
                            )
                          else
                            Text(
                              '$listingsCount shown on the map (not registered)',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    if (_view == _RegistryView.registered)
                      OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.filter_list, size: 18),
                        label: Text(_filter == 'all' ? 'Filters' : 'Filters (1)'),
                        style: TabletControls.toolbarOutlined(
                          border: _filter == 'all' ? AppColors.border : AppColors.primary,
                          foreground: _filter == 'all' ? AppColors.text : AppColors.primary,
                          background: _filter == 'all' ? Colors.white : AppColors.primaryLight,
                        ),
                      ),
                    if (!widget.drawerInShell)
                      IconButton(
                        tooltip: 'Back to dashboard',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                  ],
                ),
              if (widget.showHeader) const SizedBox(height: AppSpacing.lg),

              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _RegistryTab(
                    label: 'Registered on MediTech ($registeredCount)',
                    selected: _view == _RegistryView.registered,
                    onTap: () => setState(() => _view = _RegistryView.registered),
                  ),
                  _RegistryTab(
                    label: 'Not on MediTech ($listingsCount)',
                    selected: _view == _RegistryView.listings,
                    onTap: () {
                      ref.read(selectedPharmacyProvider.notifier).select(null);
                      setState(() => _view = _RegistryView.listings);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (_view == _RegistryView.registered) ...[
                SizedBox(
                  height: TabletControls.toolbarHeight,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: TabletControls.searchDecoration(
                      hint: 'Name, branch, owner, or LTO',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _search.clear()),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: AsyncView<List<PharmacySummary>>(
                      value: rows,
                      onRetry: () => ref.invalidate(pharmacyListProvider),
                      builder: (all) {
                        final filtered = _filtered(all);

                        return Column(
                          children: [
                            _TableHeader(compact: compact),
                            Expanded(
                              child: filtered.isEmpty
                                  ? const StateMessage(
                                      icon: Icons.storefront_outlined,
                                      message: 'No pharmacies match these filters.',
                                    )
                                  : ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1),
                                      itemBuilder: (_, i) => _PharmacyRow(
                                        pharmacy: filtered[i],
                                        compact: compact,
                                        selected: filtered[i].id == selected,
                                        onView: () => _openRow(filtered[i].id),
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ] else
                const Expanded(child: OsmListingsScreen(showHeader: false, embedded: true)),
            ],
    );

    if (widget.drawerInShell) {
      return content;
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: content,
        ),
      ),
    );
  }
}

class _RegistryTab extends StatelessWidget {
  const _RegistryTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : AppColors.background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {int flex = 1}) => Expanded(
          flex: flex,
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        );

    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          if (!compact) cell('ID', flex: 2),
          cell('PHARMACY', flex: compact ? 6 : 4),
          if (!compact) cell('OWNER', flex: 3),
          if (!compact) cell('FDA LTO', flex: 3),
          cell('STATUS', flex: compact ? 3 : 2),
          const SizedBox(
            width: 48,
            child: Text('VIEW', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _PharmacyRow extends StatelessWidget {
  const _PharmacyRow({
    required this.pharmacy,
    required this.compact,
    required this.selected,
    required this.onView,
  });

  final PharmacySummary pharmacy;
  final bool compact;
  final bool selected;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final p = pharmacy;
    final today = DateTime.now();
    final date = DateFormat('MMM d, yyyy');
    final (ltoHint, ltoColor) = ltoExpiryHint(p, today);

    return Material(
      color: selected ? AppColors.primaryLight.withValues(alpha: 0.45) : Colors.transparent,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact)
                Expanded(
                  flex: 2,
                  child: Text(p.displayId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              Expanded(
                flex: compact ? 6 : 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.pharmacyName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${p.branchName} · ${p.address}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!compact)
                Expanded(
                  flex: 3,
                  child: Text(p.ownerName ?? '—', overflow: TextOverflow.ellipsis),
                ),
              if (!compact)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date.format(p.ltoExpiry)),
                      Text(ltoHint, style: TextStyle(color: ltoColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              Expanded(
                flex: compact ? 3 : 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(status: p.status),
                ),
              ),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    tooltip: 'View details',
                    onPressed: onView,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      backgroundColor: selected ? AppColors.primary : Colors.white,
                      foregroundColor: selected ? Colors.white : AppColors.textMuted,
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = statusLabel(status);
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}