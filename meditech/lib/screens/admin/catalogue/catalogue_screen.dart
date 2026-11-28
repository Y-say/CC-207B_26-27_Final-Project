import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/catalogue_medicine.dart';
import '../../../providers/catalogue_providers.dart';
import '../../../widgets/common/app_chip.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'medicine_drawer.dart';

// Catalogue statuses as the admin sees them. 'draft' entries are waiting for an
// FDA check and approval, so they read as "Pending review".
const medicineStatuses = <String, (String, BadgeTone)>{
  'draft': ('Pending review', BadgeTone.warning),
  'active': ('Active', BadgeTone.success),
  'inactive': ('Inactive', BadgeTone.danger),
};

// Badge for a catalogue entry's status
StatusBadge medicineStatusBadge(String status) {
  final (label, tone) = medicineStatuses[status] ?? ('Inactive', BadgeTone.danger);
  return StatusBadge(label, tone: tone);
}

// Plain-language drug classification
String medicineClassification(bool isRx) =>
    isRx ? 'Prescription Drug (Rx)' : 'Over-the-Counter (OTC) Drug';

// Admin medicine catalogue (wireframes A-12, A-14, A-15)
class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key, this.drawerInShell = false});

  /// When true, [AdminShellScreen] renders the medicine drawer in the right panel.
  final bool drawerInShell;

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  // Search as the admin types, after a short pause
  void _onSearchChanged(String text) {
    setState(() {}); // show or hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250),
        () => ref.read(catalogueFilterProvider.notifier).setSearch(text));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    ref.read(catalogueFilterProvider.notifier).setSearch('');
  }

  void _openMedicine(String id) {
    final useShell = widget.drawerInShell && MediaQuery.sizeOf(context).width >= 900;
    if (useShell) {
      ref.read(selectedMedicineProvider.notifier).select(id);
      return;
    }
    _openMedicineSheet(id);
  }

  Future<void> _openMedicineSheet(String id) async {
    final rows = ref.read(catalogueListProvider).asData?.value;
    final medicine = id == 'new' ? null : rows?.where((m) => m.id == id).firstOrNull;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 460,
          height: MediaQuery.sizeOf(context).height,
          child: MedicineDrawer(
            key: ValueKey(id),
            medicine: medicine,
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
    ref.read(selectedMedicineProvider.notifier).select(null);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(catalogueFilterProvider);
    final selected = ref.watch(selectedMedicineProvider);
    final rows = ref.watch(catalogueListProvider);
    final view = rows.whenData((all) => CatalogueView.of(all, filter));

    final total = rows.value?.length;
    final shellDrawerOpen = widget.drawerInShell &&
        selected != null &&
        MediaQuery.sizeOf(context).width >= 900;
    final compact = shellDrawerOpen;

    final content = Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medicine catalogue',
                        style: TextStyle(
                          fontSize: compact ? 22 : 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          total == null ? 'Loading…' : '$total medicines in the catalogue',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openMedicine('new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(compact ? 'Add' : 'Add medicine'),
                  style: TabletControls.actionFilled(),
                ),
              ],
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            _StatusChips(
              all: rows.value,
              status: filter.status,
              counts: view.value?.statusCounts,
              compact: compact,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            _Toolbar(
              search: _search,
              onSearchChanged: _onSearchChanged,
              onClearSearch: _clearSearch,
              filter: filter,
              compact: compact,
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AsyncView<CatalogueView>(
                      value: view,
                      onRetry: () => ref.invalidate(catalogueListProvider),
                      isEmpty: (v) => v.matching == 0,
                      emptyMessage: 'No medicines match these filters.',
                      builder: (v) => Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                              child: _ListBar(view: v, filter: filter, compact: compact),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: _Table(
                                rows: v.rows,
                                selectedId: selected,
                                filter: filter,
                                compact: compact,
                                onOpen: _openMedicine,
                              ),
                            ),
                          ],
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

    if (widget.drawerInShell) return content;

    return Scaffold(body: content);
  }
}

// Status filter chips (counts when available)
class _StatusChips extends ConsumerWidget {
  const _StatusChips({
    required this.all,
    required this.status,
    required this.counts,
    this.compact = false,
  });

  final List<CatalogueMedicine>? all;
  final String? status;
  final Map<String?, int>? counts;
  final bool compact;

  static const _tabs = <(String, String?)>[
    ('All', null),
    ('Pending review', 'draft'),
    ('Active', 'active'),
    ('Inactive', 'inactive'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setStatus = ref.read(catalogueFilterProvider.notifier).setStatus;
    int countFor(String? value) {
      if (counts != null) return counts![value] ?? 0;
      if (all == null) return 0;
      return all!.where((m) => value == null || m.status == value).length;
    }

    final chips = [
      for (final (label, value) in _tabs)
        AppChip(
          label: compact
              ? (status == value
                  ? (all == null && counts == null ? label : '$label (${countFor(value)})')
                  : label)
              : (all == null && counts == null ? label : '$label (${countFor(value)})'),
          selected: status == value,
          onSelected: (_) => setStatus(value),
        ),
    ];

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              chips[i],
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: chips,
    );
  }
}

// Search and extra filters
class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.search,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.filter,
    this.compact = false,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final CatalogueFilter filter;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final field = SizedBox(
      height: TabletControls.toolbarHeight,
      child: TextField(
        controller: search,
        onChanged: onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: TabletControls.searchDecoration(
          hint: compact
              ? 'Search medicines'
              : 'Brand, generic name, or registration number',
          suffixIcon: search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClearSearch,
                ),
        ),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _MoreFilters(filter: filter, compact: true),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: AppSpacing.sm),
        _MoreFilters(filter: filter),
      ],
    );
  }
}

// Classification and FDA check filters
class _MoreFilters extends ConsumerWidget {
  const _MoreFilters({required this.filter, this.compact = false});

  final CatalogueFilter filter;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogueFilterProvider.notifier);
    final active = filter.extraFilterCount;

    PopupMenuEntry<String> heading(String text) => PopupMenuItem<String>(
          enabled: false,
          height: 32,
          child: Text(text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        );
    PopupMenuEntry<String> option(String value, String label, bool checked) =>
        CheckedPopupMenuItem<String>(value: value, checked: checked, child: Text(label));

    final buttonStyle = TabletControls.toolbarOutlined(
      border: active > 0 ? AppColors.primary : AppColors.border,
      foreground: active > 0 ? AppColors.primary : AppColors.text,
      background: active > 0 ? AppColors.primaryLight : Colors.white,
    );

    return PopupMenuButton<String>(
      tooltip: 'More filters',
      position: PopupMenuPosition.under,
      onSelected: (v) => switch (v) {
        'rx:any' => notifier.setRx(null),
        'rx:yes' => notifier.setRx(true),
        'rx:no' => notifier.setRx(false),
        'fda:any' => notifier.setFdaMatched(null),
        'fda:yes' => notifier.setFdaMatched(true),
        'fda:no' => notifier.setFdaMatched(false),
        _ => notifier.clearExtraFilters(),
      },
      itemBuilder: (_) => [
        heading('CLASSIFICATION'),
        option('rx:any', 'Any classification', filter.isRx == null),
        option('rx:yes', 'Prescription Drug (Rx)', filter.isRx == true),
        option('rx:no', 'Over-the-Counter (OTC) Drug', filter.isRx == false),
        const PopupMenuDivider(),
        heading('FDA CHECK'),
        option('fda:any', 'Any result', filter.fdaMatched == null),
        option('fda:yes', 'Matched and valid', filter.fdaMatched == true),
        option('fda:no', 'Not matched yet', filter.fdaMatched == false),
        if (active > 0) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'clear', child: Text('Clear filters')),
        ],
      ],
      child: OutlinedButton.icon(
        onPressed: () {},
        style: buttonStyle,
        icon: const Icon(Icons.filter_list, size: 18),
        label: Text(
          compact
              ? (active > 0 ? 'Filters ($active)' : 'Filters')
              : (active > 0 ? 'More filters ($active)' : 'More filters'),
        ),
      ),
    );
  }
}

// "Showing 1–10 of 128", sort, items per page, and page numbers
class _ListBar extends ConsumerWidget {
  const _ListBar({required this.view, required this.filter, this.compact = false});

  final CatalogueView view;
  final CatalogueFilter filter;
  final bool compact;

  static const _sortLabels = {
    CatalogueSort.generic: 'Generic name',
    CatalogueSort.brand: 'Brand name',
    CatalogueSort.registration: 'Registration no.',
  };

  static const _sortLabelsCompact = {
    CatalogueSort.generic: 'Generic',
    CatalogueSort.brand: 'Brand',
    CatalogueSort.registration: 'Reg. no.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(catalogueFilterProvider.notifier);
    const muted = TextStyle(color: AppColors.textMuted);
    final sortItems = compact ? _sortLabelsCompact : _sortLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          compact
              ? '${view.firstShown}–${view.lastShown} of ${view.matching}'
              : 'Showing ${view.firstShown}–${view.lastShown} of ${view.matching} '
                  '${view.matching == 1 ? 'medicine' : 'medicines'}',
          style: muted,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (!compact) const Text('Sort by:', style: muted),
            _Select<CatalogueSort>(
              value: filter.sort,
              items: {for (final e in sortItems.entries) e.key: e.value},
              onChanged: (s) => notifier.setSort(s, ascending: filter.ascending),
            ),
            IconButton(
              tooltip: filter.ascending ? 'A to Z' : 'Z to A',
              visualDensity: VisualDensity.compact,
              onPressed: () => notifier.toggleSort(filter.sort),
              icon: Icon(filter.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
            ),
            if (!compact) const Text('Items per page:', style: muted),
            if (!compact)
              _Select<int>(
                value: filter.perPage,
                items: const {10: '10', 25: '25', 50: '50'},
                onChanged: notifier.setPerPage,
              ),
          ],
        ),
        if (view.pageCount > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _Pager(
              page: view.page,
              pageCount: view.pageCount,
              onPage: notifier.setPage,
              compact: compact,
            ),
          ),
        ],
      ],
    );
  }
}

// A small bordered drop-down
class _Select<T> extends StatelessWidget {
  const _Select({required this.value, required this.items, required this.onChanged});

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// Previous, page numbers (with gaps when there are many), next
class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.onPage,
    this.compact = false,
  });

  final int page; // zero-based
  final int pageCount;
  final ValueChanged<int> onPage;
  final bool compact;

  // Pages to show, zero-based; null marks a gap
  List<int?> get _numbers {
    if (pageCount <= 7) return [for (var i = 0; i < pageCount; i++) i];
    final around = {0, page - 1, page, page + 1, pageCount - 1}.where((i) => i >= 0 && i < pageCount).toList()
      ..sort();
    final out = <int?>[];
    for (final i in around) {
      if (out.isNotEmpty && out.last != null && i - out.last! > 1) out.add(null);
      out.add(i);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    Widget box({required Widget child, VoidCallback? onTap, bool selected = false, String? tooltip}) {
      final tile = Material(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 34, height: 34, child: Center(child: child)),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: tooltip == null ? tile : Tooltip(message: tooltip, child: tile),
      );
    }

    final first = page == 0, last = page >= pageCount - 1;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          box(
            tooltip: 'Previous page',
            onTap: first ? null : () => onPage(page - 1),
            child: Icon(Icons.chevron_left, size: 20, color: first ? AppColors.border : AppColors.text),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '${page + 1} / $pageCount',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
          ),
          box(
            tooltip: 'Next page',
            onTap: last ? null : () => onPage(page + 1),
            child: Icon(Icons.chevron_right, size: 20, color: last ? AppColors.border : AppColors.text),
          ),
        ],
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      box(
        tooltip: 'Previous page',
        onTap: first ? null : () => onPage(page - 1),
        child: Icon(Icons.chevron_left, size: 20, color: first ? AppColors.border : AppColors.text),
      ),
      for (final n in _numbers)
        n == null
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('…', style: TextStyle(color: AppColors.textMuted)),
              )
            : box(
                selected: n == page,
                onTap: n == page ? null : () => onPage(n),
                child: Text('${n + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: n == page ? Colors.white : AppColors.text,
                    )),
              ),
      box(
        tooltip: 'Next page',
        onTap: last ? null : () => onPage(page + 1),
        child: Icon(Icons.chevron_right, size: 20, color: last ? AppColors.border : AppColors.text),
      ),
    ]);
  }
}

// The catalogue table: registration, generic, brand, strength and form,
// classification, status, and actions
class _Table extends ConsumerWidget {
  const _Table({
    required this.rows,
    required this.selectedId,
    required this.filter,
    required this.compact,
    required this.onOpen,
  });

  final List<CatalogueMedicine> rows;
  final String? selectedId;
  final CatalogueFilter filter;
  final bool compact;
  final void Function(String id) onOpen;

  static const _sortColumns = [CatalogueSort.registration, CatalogueSort.generic, CatalogueSort.brand];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CatalogueTableHeader(compact: true),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final m = rows[index];
                return _CatalogueRow(
                  medicine: m,
                  compact: true,
                  selected: m.id == selectedId,
                  onOpen: () => onOpen(m.id),
                );
              },
            ),
          ),
        ],
      );
    }

    final notifier = ref.read(catalogueFilterProvider.notifier);

    DataCell cell(String text, double maxWidth, {TextStyle? style}) => DataCell(ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
        ));

    DataColumn sortable(String label, CatalogueSort sort) =>
        DataColumn(label: Text(label), onSort: (_, _) => notifier.toggleSort(sort));

    Future<void> copy(String number) async {
      await Clipboard.setData(ClipboardData(text: number));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Registration number copied.')));
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: AppSpacing.xl,
            horizontalMargin: AppSpacing.lg,
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 68,
            headingRowColor: const WidgetStatePropertyAll(AppColors.background),
            headingTextStyle:
                const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 13),
            sortColumnIndex: _sortColumns.indexOf(filter.sort),
            sortAscending: filter.ascending,
            columns: [
              sortable('Registration No.', CatalogueSort.registration),
              sortable('Generic Name', CatalogueSort.generic),
              sortable('Brand Name', CatalogueSort.brand),
              const DataColumn(label: Text('Dosage Strength and Form')),
              const DataColumn(label: Text('Classification')),
              const DataColumn(label: Text('Status')),
              const DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final m in rows)
                DataRow(
                  selected: m.id == selectedId,
                  onSelectChanged: (_) => onOpen(m.id),
                  cells: [
                    m.registrationNumber == null
                        ? const DataCell(Text('—', style: TextStyle(color: AppColors.textMuted)))
                        : cell(m.registrationNumber!, 150),
                    cell(m.genericName, 220),
                    cell(m.brandName, 180, style: const TextStyle(fontWeight: FontWeight.w700)),
                    cell('${m.strength} ${m.dosageForm}', 220),
                    cell(medicineClassification(m.isRx), 170),
                    DataCell(medicineStatusBadge(m.status)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'View medicine',
                        onPressed: () => onOpen(m.id),
                        icon: Icon(
                          m.id == selectedId ? Icons.visibility : Icons.visibility_outlined,
                          size: 20,
                          color: m.id == selectedId ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More actions',
                        icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                        onSelected: (v) => v == 'copy' ? copy(m.registrationNumber!) : onOpen(m.id),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'open', child: Text('Open details')),
                          if (m.registrationNumber != null)
                            const PopupMenuItem(value: 'copy', child: Text('Copy registration number')),
                        ],
                      ),
                    ])),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _CatalogueTableHeader extends StatelessWidget {
  const _CatalogueTableHeader({required this.compact});

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
          cell('MEDICINE', flex: 6),
          cell('STATUS', flex: 3),
          const SizedBox(
            width: 48,
            child: Text('VIEW', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _CatalogueRow extends StatelessWidget {
  const _CatalogueRow({
    required this.medicine,
    required this.compact,
    required this.selected,
    required this.onOpen,
  });

  final CatalogueMedicine medicine;
  final bool compact;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    final title = compact
        ? '${m.brandName} · ${m.genericName}'
        : m.brandName;
    final subtitle = compact
        ? [
            if (m.registrationNumber != null) m.registrationNumber!,
            '${m.strength} ${m.dosageForm}',
          ].join(' · ')
        : null;

    return Material(
      color: selected ? AppColors.primaryLight.withValues(alpha: 0.45) : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : 15,
                        color: selected ? AppColors.primary : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: medicineStatusBadge(m.status),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    tooltip: 'View medicine',
                    onPressed: onOpen,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      backgroundColor: selected ? AppColors.primary : Colors.white,
                      foregroundColor: selected ? Colors.white : AppColors.textMuted,
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: Icon(selected ? Icons.visibility : Icons.visibility_outlined, size: 20),
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

