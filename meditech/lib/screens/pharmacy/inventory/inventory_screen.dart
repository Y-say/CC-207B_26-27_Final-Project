
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'add_inventory_drawer.dart';
import 'edit_inventory_drawer.dart';
import 'import/inventory_import_upload_screen.dart';

import '../../../models/inventory_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/stock_alerts_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_data_table.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/tablet/tablet_filter_panel.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// The pharmacy's inventory list with search, filters and stock actions
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({
    super.key,
    this.onAddEntry,
    this.onEditItem,
    this.onImportTap,
  });

  final VoidCallback? onAddEntry;
  final ValueChanged<InventoryItem>? onEditItem;
  final VoidCallback? onImportTap;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  double _filterTop = 135;
  double _filterLeft = 400;
  String _search = '';
  String _listing = 'all';
  final Set<String> _availability = {};
  final Set<String> _selectedIds = {};
  bool _onlyOutOfStock = false;
  bool _onlyRx = false;
  bool _showFilters = false;
  bool _busy = false;
  InventoryItem? _editingItem;

  void _toggleFilters() {
    if (!_showFilters) {
      final renderBox =
          _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && stackBox != null && renderBox.hasSize) {
        final offset = renderBox.localToGlobal(Offset.zero, ancestor: stackBox);
        _filterTop = offset.dy + renderBox.size.height + 8;
        _filterLeft = offset.dx;
      }
    }
    setState(() => _showFilters = !_showFilters);
  }

  static const _availabilityLabels = {
    'available': 'Available',
    'low_stock': 'Low Stock',
    'unavailable': 'Unavailable',
    'unconfirmed': 'Unconfirmed',
  };

  // How many filters are switched on
  int get _activeFilterCount =>
      _availability.length +
      (_listing != 'all' ? 1 : 0) +
      (_onlyOutOfStock ? 1 : 0) +
      (_onlyRx ? 1 : 0);

  // Keep only the rows that match the search and the filters
  List<InventoryItem> _filtered(List<InventoryItem> all) {
    final query = _search.trim().toLowerCase();
    return all.where((item) {
      if (query.isNotEmpty &&
          !item.brandName.toLowerCase().contains(query) &&
          !item.genericName.toLowerCase().contains(query)) {
        return false;
      }
      if (_listing == 'active' && !item.isActive) return false;
      if (_listing == 'inactive' && item.isActive) return false;
      if (_availability.isNotEmpty &&
          !_availability.contains(item.availability)) {
        return false;
      }
      if (_onlyOutOfStock && !item.outOfStock) return false;
      if (_onlyRx && !item.isRx) return false;
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _listing = 'all';
      _availability.clear();
      _onlyOutOfStock = false;
      _onlyRx = false;
    });
  }

  // Today shows the time only; older dates show the day too
  String _formatUpdated(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay
        ? 'Today, ${DateFormat('h:mm a').format(local)}'
        : DateFormat('MMM d, h:mm a').format(local);
  }

  // Turns a database error into a short message for staff
  String _friendly(Object error) {
    try {
      final message = (error as dynamic).message;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Something went wrong. Please try again.';
  }

  // Runs one change, then reloads the list and tells the user what happened
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _selectedIds.clear();
      ref.invalidate(inventoryProvider);
      ref.invalidate(stockAlertsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inventory updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _names(List<InventoryItem> items) =>
      items.map((i) => '${i.brandName} ${i.strength}').join(', ');

  Future<void> _markOutOfStock(List<InventoryItem> items) async {
    final ok = await showTabletConfirmDialog(
      context: context,
      title: items.length == 1
          ? 'Mark 1 medicine out of stock?'
          : 'Mark ${items.length} medicines out of stock?',
      targetName: _names(items),
      consequences: const [
        'Patients see it as Unavailable right away and can\'t reserve it.',
        'Your recorded count is kept for history. It isn\'t changed to 0.',
        'Confirmed reservations keep their held units. Check them if the '
            'shelf is truly empty.',
        'CSV/Excel imports won\'t switch this off. Use Back in stock when '
            'the shelf is refilled.',
      ],
      confirmLabel: 'Mark out of stock',
      isDanger: true,
    );
    if (ok != true) return;
    await _run(
      () => ref.read(inventoryServiceProvider).setOutOfStock([
        for (final i in items) i.id,
      ]),
    );
  }

  Future<void> _backInStock(List<InventoryItem> items) async {
    final counts = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BackInStockDialog(items: items),
    );
    if (counts == null || counts.isEmpty) return;
    await _run(() => ref.read(inventoryServiceProvider).backInStock(counts));
  }

  Future<void> _setActive(List<InventoryItem> items, bool active) async {
    if (!active) {
      final ok = await showTabletConfirmDialog(
        context: context,
        title: items.length == 1
            ? 'Deactivate 1 listing?'
            : 'Deactivate ${items.length} listings?',
        targetName: _names(items),
        consequences: const [
          'Hidden from patients: not in search, on your pharmacy page, or in '
              'carts.',
          'New reservations are blocked. Reservations already made aren\'t '
              'affected.',
          'Stays in Inventory under the Inactive filter, with its stock and '
              'history.',
          'You can activate it again anytime.',
          'Still selling it and the shelf is just empty? Use Mark out of '
              'stock instead.',
        ],
        confirmLabel: 'Deactivate',
        isDanger: true,
      );
      if (ok != true) return;
    } else {
      final ok = await showTabletConfirmDialog(
        context: context,
        title: items.length == 1
            ? 'Activate 1 listing?'
            : 'Activate ${items.length} listings?',
        targetName: _names(items),
        consequences: const [
          'Patients can see it and reserve it again.',
          'The last recorded stock is shown. Edit it first if it changed.',
        ],
        confirmLabel: 'Activate',
      );
      if (ok != true) return;
    }
    await _run(
      () => ref.read(inventoryServiceProvider).setListingActive([
        for (final i in items) i.id,
      ], active),
    );
  }

  Future<void> _showEditDrawerOverlay(InventoryItem item) async {
    final screenSize = MediaQuery.of(context).size;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close edit inventory drawer',
      barrierColor: Colors.black54,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            color: AppColors.surface,
            child: SizedBox(
              width: screenSize.width < 420 ? screenSize.width : 420,
              height: screenSize.height,
              child: EditInventoryDrawer(item: item),
            ),
          ),
        );
      },
    );
  }

  // Opens the add inventory drawer while preserving an optional parent callback.
  Future<void> _openAddEntry() async {
    if (widget.onAddEntry != null) {
      widget.onAddEntry!();
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close add inventory drawer',
      barrierColor: Colors.black54,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            color: AppColors.surface,
            child: SizedBox(
              width: screenSize.width < 460 ? screenSize.width : 460,
              height: screenSize.height,
              child: const AddInventoryDrawer(),
            ),
          ),
        );
      },
    );
  }

  // Opens the import modal dialog while preserving an optional parent callback.
  void _openImport() {
    if (widget.onImportTap != null) {
      widget.onImportTap!();
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => InventoryImportUploadScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);

    return AsyncView<List<InventoryItem>>(
      value: inventory,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'No inventory entries yet. Add your first medicine.',
      onRetry: () => ref.invalidate(inventoryProvider),
      builder: (all) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildInventory(all)),
            if (_editingItem != null)
              Container(
                width: 420,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    left: BorderSide(color: AppColors.border),
                  ),
                ),
                child: EditInventoryDrawer(
                  item: _editingItem!,
                  onClose: () => setState(() => _editingItem = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventory(List<InventoryItem> all) {
    final shown = _filtered(all);
    final selectedItems = all
        .where((i) => _selectedIds.contains(i.id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final drawerOpen = _editingItem != null;
        final showExplainers = !drawerOpen && constraints.maxHeight >= 850;

        return Stack(
          key: _stackKey,
          children: [
            Positioned.fill(
              child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _inventoryHeader(
                    maxWidth: constraints.maxWidth,
                    drawerOpen: drawerOpen,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: TabletDataTable<InventoryItem>(
                        compactForDrawer: _editingItem != null,
                        filterButtonKey: _filterButtonKey,
                        searchHint: 'Search medicine',
                        onSearchChanged: (v) => setState(() => _search = v),
                        totalCount: all.length,
                        filteredCount: shown.length,
                        countLabel: 'medicines',
                        onFiltersTap: _toggleFilters,
                        activeFilterCount: _activeFilterCount,
                        selectable: true,
                        selectedIds: _selectedIds,
                        idGetter: (item) => item.id,
                        onSelectionChanged: (ids) => setState(() {
                          _selectedIds
                            ..clear()
                            ..addAll(ids);
                        }),
                        bulkActions: [
                          _bulkButton(
                            'Mark out of stock',
                            background: AppColors.dangerLight,
                            foreground: AppColors.danger,
                            onTap: _busy
                                ? null
                                : () => _markOutOfStock(selectedItems),
                          ),
                          const SizedBox(width: 8),
                          _bulkButton(
                            'Back in stock',
                            background: AppColors.primaryLight,
                            foreground: AppColors.primary,
                            onTap: _busy
                                ? null
                                : () => _backInStock(selectedItems),
                          ),
                          const SizedBox(width: 8),
                          _bulkButton(
                            'Deactivate',
                            background: Colors.transparent,
                            foreground: Colors.white,
                            outlined: true,
                            onTap: _busy
                                ? null
                                : () => _setActive(selectedItems, false),
                          ),
                        ],
                        columns: [
                          TabletColumn(
                            title: 'MEDICINE',
                            priority: TabletColumnPriority.high,
                            width: _editingItem != null ? 200 : 240,
                          ),
                          TabletColumn(
                            title: 'STRENGTH',
                            priority: TabletColumnPriority.medium,
                            width: 110,
                          ),
                          TabletColumn(
                            title: 'FORM',
                            priority: TabletColumnPriority.medium,
                            width: 130,
                          ),
                          TabletColumn(
                            title: 'UNIT',
                            priority: TabletColumnPriority.medium,
                            width: 100,
                          ),
                          TabletColumn(
                            title: 'STOCK',
                            priority: TabletColumnPriority.high,
                            width: 80,
                          ),
                          TabletColumn(
                            title: 'HELD',
                            priority: TabletColumnPriority.low,
                            width: 80,
                          ),
                          TabletColumn(
                            title: 'AVAILABILITY',
                            priority: TabletColumnPriority.high,
                            width: _editingItem != null ? 108 : 140,
                          ),
                          TabletColumn(
                            title: 'PRICE / UNIT',
                            priority: TabletColumnPriority.medium,
                            width: 120,
                          ),
                          TabletColumn(
                            title: 'LAST UPDATED',
                            priority: TabletColumnPriority.low,
                            width: 170,
                          ),
                          TabletColumn(
                            title: 'OUT OF STOCK',
                            priority: TabletColumnPriority.low,
                            width: 130,
                          ),
                          TabletColumn(
                            title: 'STATUS',
                            priority: TabletColumnPriority.medium,
                            width: 110,
                          ),
                          TabletColumn(
                            title: drawerOpen ? 'EDIT' : 'ACTIONS',
                            priority: TabletColumnPriority.high,
                            width: drawerOpen ? 72 : 120,
                            alignment: Alignment.center,
                          ),
                        ],
                        items: shown,
                        rowBuilder: (context, item, index) => [
                          _medicineCell(
                            item,
                            compact: drawerOpen,
                            editingSelected: item.id == _editingItem?.id,
                          ),
                          Text(item.strength),
                          Text(item.dosageForm),
                          Text(item.unit),
                          Text(
                            drawerOpen && item.heldQuantity > 0
                                ? '${item.stockQuantity} (${item.heldQuantity} held)'
                                : '${item.stockQuantity}',
                            maxLines: drawerOpen ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('${item.heldQuantity}'),
                          StatusBadge.availability(
                            item.availability,
                            compact: _editingItem != null,
                          ),
                          Text(
                            '₱${item.pricePerUnit.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _formatUpdated(item.stockConfirmedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          _outOfStockSwitch(item),
                          item.isActive
                              ? const StatusBadge(
                                  'Active',
                                  tone: BadgeTone.success,
                                )
                              : const StatusBadge('Inactive'),
                          _actionsCell(item),
                        ],
                        emptyState: const Center(
                          child: Text(
                            'No matching medicines found.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  if (showExplainers) ...[
                    const SizedBox(height: AppSpacing.md),
                    if (constraints.maxWidth < 900)
                      const Column(
                        children: [
                          _ExplainerCard(
                            title: 'Out of stock switch',
                            body:
                                'For an empty shelf. The medicine stays '
                                'listed but shows as Unavailable, and '
                                'patients can\'t reserve it. "Back in stock" '
                                'asks you to count the shelf and enter the '
                                'new quantity.',
                          ),
                          SizedBox(height: AppSpacing.md),
                          _ExplainerCard(
                            title: 'Deactivate',
                            body:
                                'For a medicine you stopped carrying. It\'s '
                                'hidden from patients completely, but it '
                                'stays here under the Inactive filter so you '
                                'can activate it again.',
                          ),
                        ],
                      )
                    else
                      const Row(
                        children: [
                          Expanded(
                            child: _ExplainerCard(
                              title: 'Out of stock switch',
                              body:
                                  'For an empty shelf. The medicine stays '
                                  'listed but shows as Unavailable, and '
                                  'patients can\'t reserve it. "Back in stock" '
                                  'asks you to count the shelf and enter the '
                                  'new quantity.',
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _ExplainerCard(
                              title: 'Deactivate',
                              body:
                                  'For a medicine you stopped carrying. It\'s '
                                  'hidden from patients completely, but it '
                                  'stays here under the Inactive filter so you '
                                  'can activate it again.',
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            ),
            if (_showFilters) ...[
              // Tapping outside closes the panel
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showFilters = false),
                ),
              ),
              Positioned(
                top: _filterTop,
                left: _filterLeft,
                child: TabletFilterPanel(
                  title: 'Filter inventory',
                  activeFilterCount: _activeFilterCount,
                  onReset: _resetFilters,
                  onApply: () => setState(() => _showFilters = false),
                  content: _filterContent(all),
                ),
              ),
            ],
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black12,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _inventoryHeader({
    required double maxWidth,
    required bool drawerOpen,
  }) {
    final stacked = drawerOpen || maxWidth < 720;
    final compactActions = drawerOpen || maxWidth < 560;

    final title = Text(
      'Inventory',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: drawerOpen ? 24 : 26,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A2E22),
        letterSpacing: -0.5,
      ),
    );

    final subtitle = drawerOpen
        ? 'Edit the selected medicine in the panel on the right.'
        : stacked
            ? 'Update stock here, or import a CSV or Excel file.'
            : 'MediTech isn\'t connected to your POS. '
                'Update stock here, or import a CSV or Excel file.';

    final subtitleWidget = Text(
      subtitle,
      maxLines: drawerOpen ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: drawerOpen ? 12 : 13,
        height: 1.35,
        color: AppColors.textMuted,
      ),
    );

    final buttonHeight = drawerOpen ? 42.0 : 44.0;
    final labelSize = drawerOpen ? 12.5 : 13.0;
    final horizontalPadding = compactActions ? 12.0 : 16.0;

    final importButton = SizedBox(
      height: buttonHeight,
      child: OutlinedButton.icon(
        onPressed: _openImport,
        icon: Icon(
          Icons.upload_outlined,
          size: drawerOpen ? 16 : 18,
          color: const Color(0xFF1A2E22),
        ),
        label: Text(
          compactActions ? 'Import' : 'Import CSV/Excel',
          style: GoogleFonts.inter(
            fontSize: labelSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A2E22),
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD8E8DE), width: 1.2),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    final addButton = SizedBox(
      height: buttonHeight,
      child: ElevatedButton.icon(
        onPressed: _openAddEntry,
        icon: Icon(Icons.add, size: drawerOpen ? 16 : 18, color: Colors.white),
        label: Text(
          compactActions ? 'Add' : 'Add inventory entry',
          style: GoogleFonts.inter(
            fontSize: labelSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E6B46),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [importButton, addButton],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 2),
          subtitleWidget,
          const SizedBox(height: 10),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 4),
              subtitleWidget,
            ],
          ),
        ),
        const SizedBox(width: 12),
        importButton,
        const SizedBox(width: 12),
        addButton,
      ],
    );
  }

  // A button for the dark bulk bar
  Widget _bulkButton(
    String label, {
    required Color background,
    required Color foreground,
    required VoidCallback? onTap,
    bool outlined = false,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: Colors.white38,
        side: outlined ? const BorderSide(color: Colors.white54) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openEdit(InventoryItem item) {
    if (widget.onEditItem != null) {
      widget.onEditItem!(item);
      return;
    }
    final useInline = MediaQuery.sizeOf(context).width >= 900;
    if (useInline) {
      setState(() => _editingItem = item);
    } else {
      _showEditDrawerOverlay(item);
    }
  }

  // Name with the generic name underneath, plus an Rx badge when needed
  Widget _medicineCell(
    InventoryItem item, {
    bool compact = false,
    bool editingSelected = false,
  }) {
  return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  compact ? '${item.brandName} · ${item.strength}' : item.brandName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: editingSelected
                        ? AppColors.primary
                        : null,
                  ),
                ),
              ),
              if (item.isRx) ...[
                const SizedBox(width: 4),
                const StatusBadge.rx(),
              ],
            ],
          ),
          if (!compact)
            Text(
              item.genericName,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  // On asks for confirmation; off asks staff to count the shelf
  Widget _outOfStockSwitch(InventoryItem item) {
    return Switch(
      value: item.outOfStock,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.danger
            : AppColors.border,
      ),
      onChanged: _busy
          ? null
          : (on) => on ? _markOutOfStock([item]) : _backInStock([item]),
    );
  }

  Widget _editIconButton(InventoryItem item, {required bool drawerOpen}) {
    final isEditing = item.id == _editingItem?.id;
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      tooltip: 'Edit medicine',
      onPressed: _busy ? null : () => _openEdit(item),
      icon: Icon(
        isEditing && drawerOpen ? Icons.edit : Icons.edit_outlined,
        size: 20,
        color: isEditing && drawerOpen
            ? AppColors.primary
            : AppColors.textMuted,
      ),
    );
  }

  // Edit icon; Deactivate/Activate text when the drawer is closed
  Widget _actionsCell(InventoryItem item) {
    final drawerOpen = _editingItem != null;
    if (drawerOpen) {
      return _editIconButton(item, drawerOpen: true);
    }

    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _editIconButton(item, drawerOpen: false),
        TextButton(
          onPressed: _busy ? null : () => _setActive([item], !item.isActive),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: item.isActive
                ? AppColors.danger
                : AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: Text(
            item.isActive ? 'Deactivate' : 'Activate',
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: buttons,
      ),
    );
  }

  // The pills and checkboxes inside the filter panel
  Widget _filterContent(List<InventoryItem> all) {
    // Count items per availability
    final availCounts = <String, int>{};
    for (final key in _availabilityLabels.keys) {
      availCounts[key] = all.where((i) => i.availability == key).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AVAILABILITY',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        for (final entry in _availabilityLabels.entries)
          InkWell(
            onTap: () {
              setState(() {
                if (_availability.contains(entry.key)) {
                  _availability.remove(entry.key);
                } else {
                  _availability.add(entry.key);
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
                      value: _availability.contains(entry.key),
                      activeColor: const Color(0xFF2E6B46),
                      side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _availability.add(entry.key);
                        } else {
                          _availability.remove(entry.key);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  Text(
                    '${availCounts[entry.key] ?? 0}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => _onlyOutOfStock = !_onlyOutOfStock),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _onlyOutOfStock,
                    activeColor: const Color(0xFF2E6B46),
                    side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (v) => setState(() => _onlyOutOfStock = v == true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Only medicines marked out of stock',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => setState(() => _onlyRx = !_onlyRx),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
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
                    onChanged: (v) => setState(() => _onlyRx = v == true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Only Rx medicines',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'LISTING STATUS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildListingPill('All', 'all'),
            const SizedBox(width: 8),
            _buildListingPill('Active', 'active'),
            const SizedBox(width: 8),
            _buildListingPill('Inactive', 'inactive'),
          ],
        ),
      ],
    );
  }

  Widget _buildListingPill(String label, String value) {
    final isSelected = _listing == value;
    return InkWell(
      onTap: () => setState(() => _listing = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E6B46) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E6B46) : const Color(0xFFD1D5DB),
            width: 1.2,
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

// Staff count the shelf; the new number replaces the recorded stock
class _BackInStockDialog extends StatefulWidget {
  const _BackInStockDialog({required this.items});

  final List<InventoryItem> items;

  @override
  State<_BackInStockDialog> createState() => _BackInStockDialogState();
}

class _BackInStockDialogState extends State<_BackInStockDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final item in widget.items)
      item.id: TextEditingController(text: '${item.stockQuantity}'),
  };
  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Whole number, at least 1, and not below the units held for reservations
  void _save() {
    final result = <String, int>{};
    final errors = <String, String?>{};
    for (final item in widget.items) {
      final value = int.tryParse(_controllers[item.id]!.text.trim());
      if (value == null || value < 1) {
        errors[item.id] = 'Enter a whole number of at least 1.';
      } else if (value < item.heldQuantity) {
        errors[item.id] = 'Not lower than the ${item.heldQuantity} units held.';
      } else {
        result[item.id] = value;
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark back in stock'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Count what\'s on the shelf and enter the quantity. MediTech '
                'isn\'t connected to your POS, so it doesn\'t restore an old '
                'count or calculate one. Your number replaces the recorded '
                'stock, and availability is worked out from it.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final item in widget.items)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (_errors[item.id] ?? '').isNotEmpty
                          ? AppColors.danger
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                                  '${item.brandName} ${item.strength}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last recorded: ${item.stockQuantity} '
                                  '${item.unit}s',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          SizedBox(
                            width: 170,
                            child: TextField(
                              controller: _controllers[item.id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity on shelf',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((_errors[item.id] ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _errors[item.id]!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const Text(
                'After saving: the Out of Stock switch turns off, Last '
                'updated becomes now, and patients can reserve it again.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save and show to patients'),
        ),
      ],
    );
  }
}

// Short note under the table explaining out of stock vs. deactivate
class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E8DE), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2E22),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2E22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
