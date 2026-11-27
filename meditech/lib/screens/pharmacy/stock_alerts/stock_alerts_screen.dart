import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../models/inventory_item.dart';
import '../../../models/stock_alert_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/stock_alerts_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../inventory/edit_inventory_drawer.dart';

// Stock Alerts screen displaying 4 live alert categories (Ph-30 to Ph-32)
class StockAlertsScreen extends ConsumerStatefulWidget {
  const StockAlertsScreen({
    super.key,
    this.onEditStock,
    this.onBackInStock,
    this.onOpenInventory,
  });

  final ValueChanged<StockAlertItem>? onEditStock;
  final ValueChanged<StockAlertItem>? onBackInStock;
  final VoidCallback? onOpenInventory;

  @override
  ConsumerState<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends ConsumerState<StockAlertsScreen> {
  // Shortcut for 'Edit stock' action (Ph-30)
  Future<void> _handleEditStock(StockAlertItem item) async {
    if (widget.onEditStock != null) {
      widget.onEditStock!(item);
      return;
    }

    InventoryItem fullItem;
    try {
      final items = await ref.read(inventoryServiceProvider).loadInventory();
      fullItem = items.firstWhere(
        (it) => it.id == item.inventoryItemId,
        orElse: () => InventoryItem(
          id: item.inventoryItemId,
          displayId: 'INV-${item.id.padLeft(6, '0')}',
          medicineId: item.medicineId,
          brandName: item.brandName,
          genericName: item.genericName,
          strength: item.strength,
          dosageForm: item.dosageForm,
          unit: item.unit,
          isRx: false,
          stockQuantity: item.stockQuantity,
          heldQuantity: item.heldQuantity,
          pricePerUnit: 0,
          lowStockThreshold: item.lowStockThreshold,
          outOfStock: item.outOfStock,
          isActive: true,
          nearestExpiry: item.nearestExpiry,
          stockConfirmedAt: item.stockConfirmedAt ?? DateTime.now(),
        ),
      );
    } catch (_) {
      fullItem = InventoryItem(
        id: item.inventoryItemId,
        displayId: 'INV-000001',
        medicineId: item.medicineId,
        brandName: item.brandName,
        genericName: item.genericName,
        strength: item.strength,
        dosageForm: item.dosageForm,
        unit: item.unit,
        isRx: false,
        stockQuantity: item.stockQuantity,
        heldQuantity: item.heldQuantity,
        pricePerUnit: 0,
        lowStockThreshold: item.lowStockThreshold,
        outOfStock: item.outOfStock,
        isActive: true,
        nearestExpiry: item.nearestExpiry,
        stockConfirmedAt: item.stockConfirmedAt ?? DateTime.now(),
      );
    }

    if (!mounted) return;

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
              child: EditInventoryDrawer(item: fullItem),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: anim.drive(tween),
          child: child,
        );
      },
    );

    if (mounted) {
      ref.invalidate(stockAlertsProvider);
      ref.invalidate(inventoryProvider);
    }
  }

  // Shortcut for 'Back in stock' shelf-count dialog (Ph-32, Ph-25)
  Future<void> _handleBackInStock(StockAlertItem item) async {
    if (widget.onBackInStock != null) {
      widget.onBackInStock!(item);
      return;
    }

    final controller = TextEditingController(text: '${item.stockQuantity}');
    String? error;

    final newCount = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
              contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              title: const Text(
                'Mark back in stock',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter the current shelf count to mark this medicine back in stock.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: error != null
                                ? AppColors.danger
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.medicineDisplayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last recorded: ${item.stockQuantity} ${item.unit}s',
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
                                  width: 120,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity on shelf',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (error != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Are you sure you want to mark this medicine back in stock?',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    final val = int.tryParse(controller.text.trim());
                    if (val == null || val < 1) {
                      setDialogState(() => error = 'Enter at least 1');
                      return;
                    }
                    if (val < item.heldQuantity) {
                      setDialogState(() => error = 'Cannot be below ${item.heldQuantity} held');
                      return;
                    }
                    Navigator.pop(dialogCtx, val);
                  },
                  child: const Text('Save and show to patients'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (newCount == null) return;

    try {
      await ref.read(inventoryServiceProvider).backInStock({
        item.inventoryItemId: newCount,
      });
      ref.invalidate(stockAlertsProvider);
      ref.invalidate(inventoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.brandName} is now back in stock.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stock: $e')),
      );
    }
  }

  void _handleOpenInventory() {
    if (widget.onOpenInventory != null) {
      widget.onOpenInventory!();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/inventory');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please navigate to the Inventory tab from the sidebar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(stockAlertsProvider);
    final activeTab = ref.watch(selectedAlertTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AsyncView<Map<StockAlertType, List<StockAlertItem>>>(
        value: alertsAsync,
        onRetry: () => ref.refresh(stockAlertsProvider),
        builder: (data) {
          final lowStockList = data[StockAlertType.lowStock] ?? [];
          final outOfStockList = data[StockAlertType.outOfStock] ?? [];
          final expiringList = data[StockAlertType.expiringSoon] ?? [];
          final notUpdatedList = data[StockAlertType.notUpdated] ?? [];

          final currentList = data[activeTab] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Title Area (no white box or subtitle)
                Text(
                  'Stock Alerts',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.normal,
                    color: const Color(0xFF1A2E22),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Category Cards (Ph-30)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _AlertCategoryCard(
                          title: 'Low stock',
                          count: lowStockList.length,
                          subtitle: '1 up to your low-stock level available',
                          isSelected: activeTab == StockAlertType.lowStock,
                          badgeBg: const Color(0xFFFEF3C7),
                          badgeFg: const Color(0xFFB45309),
                          onTap: () => ref
                              .read(selectedAlertTabProvider.notifier)
                              .selectTab(StockAlertType.lowStock),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _AlertCategoryCard(
                          title: 'Out of stock',
                          count: outOfStockList.length,
                          subtitle: 'None available, or the switch is on',
                          isSelected: activeTab == StockAlertType.outOfStock,
                          badgeBg: const Color(0xFFFEE2E2),
                          badgeFg: const Color(0xFFDC2626),
                          onTap: () => ref
                              .read(selectedAlertTabProvider.notifier)
                              .selectTab(StockAlertType.outOfStock),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _AlertCategoryCard(
                          title: 'Expiring soon',
                          count: expiringList.length,
                          subtitle: 'Nearest expiry within 60 days',
                          isSelected: activeTab == StockAlertType.expiringSoon,
                          badgeBg: const Color(0xFFF1F5F9),
                          badgeFg: const Color(0xFF475569),
                          onTap: () => ref
                              .read(selectedAlertTabProvider.notifier)
                              .selectTab(StockAlertType.expiringSoon),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _AlertCategoryCard(
                          title: 'Not updated',
                          count: notUpdatedList.length,
                          subtitle: 'No stock update in 7 days',
                          isSelected: activeTab == StockAlertType.notUpdated,
                          badgeBg: const Color(0xFFDBEAFE),
                          badgeFg: const Color(0xFF2563EB),
                          onTap: () => ref
                              .read(selectedAlertTabProvider.notifier)
                              .selectTab(StockAlertType.notUpdated),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Table Content Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD8E8DE),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A1A2E22),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        child: _buildSectionSummaryHeader(activeTab),
                      ),
                      const Divider(height: 1, color: Color(0xFFE5EBE7)),

                      // Table header
                      _buildTableHeader(activeTab),
                      const Divider(height: 1, color: Color(0xFFE5EBE7)),

                      // List of alert items
                      if (currentList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              _emptyMessage(activeTab),
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: currentList.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Color(0xFFE5EBE7)),
                          itemBuilder: (context, index) {
                            return _buildRow(
                              context,
                              currentList[index],
                              activeTab,
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Explainer footer note (no white box, matching wireframe)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.normal,
                        color: const Color(0xFF4B5563),
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'How alerts work: ',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            color: const Color(0xFF1A2E22),
                          ),
                        ),
                        const TextSpan(
                          text:
                              'Low stock = 1 up to your low-stock level available · '
                              'Out of stock = none available, or the Out of Stock switch is on · '
                              'Expiring soon = nearest expiry within 60 days · '
                              'Not updated = no stock update in 7 days, so patients see Unconfirmed. '
                              'Alerts clear on their own once the stock is fixed.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionSummaryHeader(StockAlertType tab) {
    final (String title, String description) = switch (tab) {
      StockAlertType.lowStock => (
          'Low stock',
          'Available stock is from 1 up to the low-stock level',
        ),
      StockAlertType.outOfStock => (
          'Out of stock',
          'Available stock is 0, or the Out of Stock switch is on',
        ),
      StockAlertType.expiringSoon => (
          'Expiring soon',
          'Nearest expiry date is within 60 days',
        ),
      StockAlertType.notUpdated => (
          'Not updated',
          'Stock has not been confirmed or updated in 7 days',
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.normal,
            color: const Color(0xFF1A2E22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.normal,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  String _emptyMessage(StockAlertType tab) {
    return switch (tab) {
      StockAlertType.lowStock => 'No items currently at low stock level.',
      StockAlertType.outOfStock => 'No items currently marked out of stock.',
      StockAlertType.expiringSoon => 'No items expiring within 60 days.',
      StockAlertType.notUpdated =>
        'All item counts have been updated in the last 7 days.',
    };
  }

  Widget _buildTableHeader(StockAlertType tab) {
    return Container(
      color: const Color(0xFFFAFBF9),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      child: Row(
        children: [
          const Expanded(flex: 3, child: _ColText('MEDICINE')),
          const SizedBox(width: 90, child: _ColText('STOCK')),
          const SizedBox(width: 80, child: _ColText('HELD')),
          Expanded(
            flex: 2,
            child: _ColText(switch (tab) {
              StockAlertType.lowStock => 'LOW-STOCK LEVEL',
              StockAlertType.outOfStock => 'WHY',
              StockAlertType.expiringSoon => 'NEAREST EXPIRY',
              StockAlertType.notUpdated => 'LAST UPDATED',
            }),
          ),
          const SizedBox(width: 150, child: _ColText('LAST UPDATED')),
          const SizedBox(width: 140, child: _ColText('ACTION')),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    StockAlertItem item,
    StockAlertType tab,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 18,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A2E22),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.genericName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              '${item.stockQuantity}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A2E22),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${item.heldQuantity}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildConditionCell(item, tab),
          ),
          SizedBox(
            width: 150,
            child: Text(
              _formatUpdated(item.stockConfirmedAt),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildActionButton(context, item, tab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCell(StockAlertItem item, StockAlertType tab) {
    switch (tab) {
      case StockAlertType.lowStock:
        return Text(
          '${item.availableStock} available · level ${item.lowStockThreshold}',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFB45309),
          ),
        );
      case StockAlertType.outOfStock:
        return Text(
          item.outOfStock ? 'Switch is on' : 'Stock is 0',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.danger,
          ),
        );
      case StockAlertType.expiringSoon:
        final days = item.nearestExpiry != null
            ? item.nearestExpiry!.difference(DateTime.now()).inDays
            : 0;
        return Text(
          '${_formatExpiryDate(item.nearestExpiry)} ($days days)',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFB45309),
          ),
        );
      case StockAlertType.notUpdated:
        return Text(
          'Unconfirmed (${_formatUpdated(item.stockConfirmedAt)})',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        );
    }
  }

  Widget _buildActionButton(
    BuildContext context,
    StockAlertItem item,
    StockAlertType tab,
  ) {
    final (String label, VoidCallback onPressed) = switch (tab) {
      StockAlertType.lowStock || StockAlertType.notUpdated => (
          'Edit stock',
          () => _handleEditStock(item),
        ),
      StockAlertType.outOfStock => (
          'Back in stock',
          () => _handleBackInStock(item),
        ),
      StockAlertType.expiringSoon => (
          'Open in Inventory',
          _handleOpenInventory,
        ),
    };

    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          foregroundColor: const Color(0xFF2E6B46),
          backgroundColor: Colors.white,
          side: const BorderSide(
            color: Color(0xFF2E6B46),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2E6B46),
          ),
        ),
      ),
    );
  }

  String _formatUpdated(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return 'Today, ${DateFormat('h:mm a').format(local)}';
    }
    return DateFormat('MMM d, h:mm a').format(local);
  }

  String _formatExpiryDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _ColText extends StatelessWidget {
  const _ColText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.normal,
        color: const Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AlertCategoryCard extends StatelessWidget {
  const _AlertCategoryCard({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.isSelected,
    required this.badgeBg,
    required this.badgeFg,
    required this.onTap,
  });

  final String title;
  final int count;
  final String subtitle;
  final bool isSelected;
  final Color badgeBg;
  final Color badgeFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2E6B46)
                : const Color(0xFFD8E8DE),
            width: isSelected ? 2 : 1.5,
          ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.normal,
                height: 1.4,
                color: const Color(0xFF6B7280),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
