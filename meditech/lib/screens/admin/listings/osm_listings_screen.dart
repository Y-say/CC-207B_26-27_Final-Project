import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/osm_listing.dart';
import '../../../providers/osm_listing_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/dialogs/reason_dialog.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Admin screen for managing OpenStreetMap "Not on MediTech" pharmacy listings
class OsmListingsScreen extends ConsumerStatefulWidget {
  const OsmListingsScreen({
    super.key,
    this.showHeader = true,
    this.embedded = false,
  });

  final bool showHeader;

  /// Inside [PharmaciesScreen] — no [Scaffold], no extra padding.
  final bool embedded;

  @override
  ConsumerState<OsmListingsScreen> createState() => _OsmListingsScreenState();
}

class _OsmListingsScreenState extends ConsumerState<OsmListingsScreen> {
  final _search = TextEditingController();
  String _statusFilter = 'all';
  bool _syncing = false;
  String? _busyId;
  int _page = 0;
  int _perPage = 25;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  StatusBadge _statusBadge(OsmListing listing) => switch (listing.status) {
    OsmListingStatus.shown => const StatusBadge(
      'Shown',
      tone: BadgeTone.success,
    ),
    OsmListingStatus.replaced => const StatusBadge(
      'Replaced',
      tone: BadgeTone.info,
    ),
    OsmListingStatus.hidden => const StatusBadge(
      'Hidden',
      tone: BadgeTone.neutral,
    ),
  };

  int _countByStatus(List<OsmListing> all, OsmListingStatus status) =>
      all.where((item) => item.status == status).length;

  List<OsmListing> _filtered(List<OsmListing> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((item) {
      final statusMatches = switch (_statusFilter) {
        'shown' => item.status == OsmListingStatus.shown,
        'replaced' => item.status == OsmListingStatus.replaced,
        'hidden' => item.status == OsmListingStatus.hidden,
        _ => true,
      };
      if (!statusMatches) return false;
      if (q.isEmpty) return true;
      return item.name.toLowerCase().contains(q) ||
          item.address.toLowerCase().contains(q) ||
          item.osmId.toLowerCase().contains(q);
    }).toList();
  }

  void _resetPage() => _page = 0;

  ({int page, int pageCount, List<OsmListing> slice, int firstShown, int lastShown})
  _pagedSlice(List<OsmListing> filtered) {
    if (filtered.isEmpty) {
      return (page: 0, pageCount: 0, slice: const [], firstShown: 0, lastShown: 0);
    }
    final pageCount = (filtered.length / _perPage).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _perPage;
    final end = (start + _perPage).clamp(0, filtered.length);
    return (
      page: page,
      pageCount: pageCount,
      slice: filtered.sublist(start, end),
      firstShown: start + 1,
      lastShown: end,
    );
  }

  Future<void> _onSync() async {
    setState(() => _syncing = true);
    try {
      final count = await ref
          .read(adminOsmListingsProvider.notifier)
          .syncFromOpenStreetMap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced $count OpenStreetMap listings for Iloilo.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _onHide(OsmListing listing) async {
    final reason = await showReasonDialog(
      context,
      title: 'Hide "${listing.name}"?',
      description: 'Patients will no longer see this OpenStreetMap listing. Tell other admins why it is being hidden.',
      actionLabel: 'Hide listing',
      hint: 'e.g., Duplicate pin or wrong barangay',
    );
    if (reason == null || !mounted) return;

    setState(() => _busyId = listing.id);
    try {
      await ref
          .read(adminOsmListingsProvider.notifier)
          .hideListing(listingId: listing.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${listing.name} is now hidden from patients.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not hide listing: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _onShowAgain(OsmListing listing) async {
    setState(() => _busyId = listing.id);
    try {
      await ref
          .read(adminOsmListingsProvider.notifier)
          .showListingAgain(listingId: listing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${listing.name} is shown to patients again.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not restore listing: $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncListings = ref.watch(adminOsmListingsProvider);

    final body = AsyncView<List<OsmListing>>(
      value: asyncListings,
      onRetry: () => ref.invalidate(adminOsmListingsProvider),
      builder: (listings) {
        final filtered = _filtered(listings);
        final paged = _pagedSlice(filtered);

        return Padding(
          padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showHeader) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not on MediTech listings',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pharmacies pulled from OpenStreetMap for Iloilo. Replaced automatically when a pharmacy registers and is approved.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _syncing ? null : _onSync,
                        style: TabletControls.toolbarOutlined(),
                        icon: _syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(_syncing ? 'Syncing…' : 'Sync OSM'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: TabletControls.toolbarHeight,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(_resetPage),
                        decoration: TabletControls.searchDecoration(
                          hint: 'Name, address, or OSM ID',
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _resetPage();
                                  }),
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.embedded) ...[
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _syncing ? null : _onSync,
                      style: TabletControls.toolbarOutlined(),
                      icon: _syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(_syncing ? 'Syncing…' : 'Sync OSM'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChip(
                      label: 'All (${listings.length})',
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() {
                        _statusFilter = 'all';
                        _resetPage();
                      }),
                    ),
                    AppChip(
                      label: 'Shown (${_countByStatus(listings, OsmListingStatus.shown)})',
                      selected: _statusFilter == 'shown',
                      onSelected: (_) => setState(() {
                        _statusFilter = 'shown';
                        _resetPage();
                      }),
                    ),
                    AppChip(
                      label:
                          'Replaced (${_countByStatus(listings, OsmListingStatus.replaced)})',
                      selected: _statusFilter == 'replaced',
                      onSelected: (_) => setState(() {
                        _statusFilter = 'replaced';
                        _resetPage();
                      }),
                    ),
                    AppChip(
                      label: 'Hidden (${_countByStatus(listings, OsmListingStatus.hidden)})',
                      selected: _statusFilter == 'hidden',
                      onSelected: (_) => setState(() {
                        _statusFilter = 'hidden';
                        _resetPage();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const _OsmTableHeader(),
                        Expanded(
                          child: filtered.isEmpty
                              ? StateMessage(
                                  icon: Icons.map_outlined,
                                  message: _search.text.trim().isEmpty
                                      ? 'No OpenStreetMap listings match the current filter.'
                                      : 'No listings match your search. Try another name, address, or OSM ID.',
                                )
                              : ListView.separated(
                                  itemCount: paged.slice.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, index) => _OsmListingRow(
                                    listing: paged.slice[index],
                                    statusBadge: _statusBadge(paged.slice[index]),
                                    busy: _busyId == paged.slice[index].id,
                                    onHide: () => _onHide(paged.slice[index]),
                                    onShowAgain: () => _onShowAgain(paged.slice[index]),
                                  ),
                                ),
                        ),
                        if (filtered.isNotEmpty)
                          _OsmListingsPaginationBar(
                            firstShown: paged.firstShown,
                            lastShown: paged.lastShown,
                            total: filtered.length,
                            perPage: _perPage,
                            page: paged.page,
                            pageCount: paged.pageCount,
                            onPerPage: (value) => setState(() {
                              _perPage = value;
                              _resetPage();
                            }),
                            onPage: (page) => setState(() => _page = page),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
    );

    if (widget.embedded) return body;

    return Scaffold(backgroundColor: AppColors.background, body: body);
  }
}

class _OsmListingsPaginationBar extends StatelessWidget {
  const _OsmListingsPaginationBar({
    required this.firstShown,
    required this.lastShown,
    required this.total,
    required this.perPage,
    required this.page,
    required this.pageCount,
    required this.onPerPage,
    required this.onPage,
  });

  final int firstShown;
  final int lastShown;
  final int total;
  final int perPage;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPerPage;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: AppColors.textMuted, fontSize: 13);

    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              'Showing $firstShown–$lastShown of $total '
              '${total == 1 ? 'listing' : 'listings'}',
              style: muted,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Rows per page: ', style: muted),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: perPage,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (value) {
                      if (value != null) onPerPage(value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _OsmListingsPager(
                  page: page,
                  pageCount: pageCount,
                  onPage: onPage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OsmListingsPager extends StatelessWidget {
  const _OsmListingsPager({
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final first = page == 0;
    final last = page >= pageCount - 1;

    Widget navButton({
      required IconData icon,
      required String tooltip,
      VoidCallback? onTap,
      bool enabled = true,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 22),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        navButton(
          icon: Icons.chevron_left,
          tooltip: 'Previous page',
          enabled: !first,
          onTap: () => onPage(page - 1),
        ),
        Text(
          'Page ${page + 1} of $pageCount',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.text,
          ),
        ),
        navButton(
          icon: Icons.chevron_right,
          tooltip: 'Next page',
          enabled: !last,
          onTap: () => onPage(page + 1),
        ),
      ],
    );
  }
}

class _OsmTableHeader extends StatelessWidget {
  const _OsmTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('PHARMACY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 4, child: Text('ADDRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 2, child: Text('LAST EDITED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 3, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Expanded(flex: 2, child: Text('ACTION', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }
}

class _OsmListingRow extends StatelessWidget {
  const _OsmListingRow({
    required this.listing,
    required this.statusBadge,
    required this.busy,
    required this.onHide,
    required this.onShowAgain,
  });

  final OsmListing listing;
  final StatusBadge statusBadge;
  final bool busy;
  final VoidCallback onHide;
  final VoidCallback onShowAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        listing.osmId,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              listing.address,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(listing.lastEditedThere ?? '—', style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusBadge,
                if (listing.status == OsmListingStatus.replaced &&
                    listing.replacedByPharmacyName != null)
                  Text(
                    'Replaced by ${listing.replacedByPharmacyName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (listing.status == OsmListingStatus.hidden && listing.hiddenReason != null)
                  Text(
                    listing.hiddenReason!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: switch (listing.status) {
                OsmListingStatus.shown => OutlinedButton(
                    onPressed: busy ? null : onHide,
                    style: TabletControls.toolbarOutlined(),
                    child: const Text('Hide'),
                  ),
                OsmListingStatus.hidden => OutlinedButton(
                    onPressed: busy ? null : onShowAgain,
                    style: TabletControls.toolbarOutlined(),
                    child: const Text('Show again'),
                  ),
                OsmListingStatus.replaced => const Text('—', style: TextStyle(color: AppColors.textMuted)),
              },
            ),
          ),
        ],
      ),
    );
  }
}
