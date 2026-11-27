import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/pharmacy.dart';
import '../../../providers/pharmacy_providers.dart';
import '../../../providers/cart_actions.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/basket_bar.dart';
import '../../../widgets/common/customer_app_bar.dart';
import '../../../utils/public_media_urls.dart';
import '../../../widgets/common/medicine_card.dart';
import '../../../widgets/common/pharmacy_storefront_hero.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'customer_directions_navigation.dart';
import 'directions_screen.dart';

// Customer pharmacy branch details screen matching wireframe P-12
class PharmacyDetailsScreen extends ConsumerStatefulWidget {
  const PharmacyDetailsScreen({
    super.key,
    required this.branchId,
    this.initialTitle,
    this.isOffline = false,
    this.onAddInventoryItem,
  });

  final String branchId;
  final String? initialTitle;
  final bool isOffline;
  final void Function(PharmacyDetail branch, PharmacyInventoryItem item)?
  onAddInventoryItem;

  @override
  ConsumerState<PharmacyDetailsScreen> createState() =>
      _PharmacyDetailsScreenState();
}

class _PharmacyDetailsScreenState extends ConsumerState<PharmacyDetailsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(pharmacyInventoryQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ref.read(pharmacyInventoryQueryProvider.notifier).setQuery(value);
    });
  }

  void _openDirections(PharmacyDetail pharmacy) {
    pushCustomerDirections(
      context,
      DirectionsArgs(
        pharmacyName: pharmacy.pharmacyName,
        branchName: pharmacy.branchName,
        address: pharmacy.address,
        destination: LatLng(pharmacy.latitude, pharmacy.longitude),
      ),
    );
  }

  void _openCart() {
    if (GoRouter.maybeOf(context) != null) context.push('/cart');
  }

  String _availabilityCode(PharmacyInventoryItem item) {
    return item.availability.name == 'lowStock'
        ? 'low_stock'
        : item.availability.name;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(pharmacyDetailProvider(widget.branchId));
    final hoursAsync = ref.watch(pharmacyHoursProvider(widget.branchId));

    final title =
        detailAsync.value?.pharmacyName ??
        widget.initialTitle ??
        'Pharmacy Details';

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: CustomerLocationAppBarTitle(
          heading: title,
          icon: Icons.local_pharmacy_outlined,
          headingStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: CustomerBottomChrome(
        showBasket: true,
        onViewCart: _openCart,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isOffline) const OfflineBanner(),
          Expanded(
            child: AsyncView<PharmacyDetail?>(
              value: detailAsync,
              isEmpty: (branch) => branch == null,
              emptyMessage: 'This pharmacy is currently unavailable.',
              onRetry: () =>
                  ref.invalidate(pharmacyDetailProvider(widget.branchId)),
              builder: (branch) {
                final pharmacy = branch!;
                final hours = hoursAsync.value ?? const <PharmacyHours>[];

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(pharmacyDetailProvider(widget.branchId));
                    ref.invalidate(pharmacyInventoryProvider(widget.branchId));
                    await Future.wait([
                      ref.read(pharmacyDetailProvider(widget.branchId).future),
                      ref.read(pharmacyInventoryProvider(widget.branchId).future),
                    ]);
                  },
                  child: ListView(
                  controller: _scrollController,
                  key: const PageStorageKey<String>(
                    'customer-pharmacy-details',
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    customerBottomChromeScrollPadding(
                      context,
                      showBasket: true,
                    ),
                  ),
                  children: [
                    PharmacyStorefrontHero(storefrontPath: pharmacy.storefrontPath),
                    const SizedBox(height: AppSpacing.md),
                    // Branch header card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pharmacy.pharmacyName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pharmacy.branchName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    pharmacy.address,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  pharmacy.contactNumber,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: () => _openDirections(pharmacy),
                              icon: const Icon(Icons.directions_outlined),
                              label: const Text('Get directions'),
                            ),
                            if (hours.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Divider(),
                              ),
                              Builder(
                                builder: (context) {
                                  final today =
                                      pharmacyHoursForToday(hours);
                                  if (today == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Opening Hours',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            today.dayLabel,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          Text(
                                            today.scheduleLabel,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: today.isClosed
                                                  ? AppColors.danger
                                                  : AppColors.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Available medicines',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _searchController,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        hintText: 'Search in ${pharmacy.pharmacyName}',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _debounce?.cancel();
                                  _searchController.clear();
                                  setState(() {});
                                  ref
                                      .read(
                                        pharmacyInventoryQueryProvider.notifier,
                                      )
                                      .setQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PharmacyInventoryList(
                      branchId: widget.branchId,
                      pharmacy: pharmacy,
                      onAddInventoryItem: widget.onAddInventoryItem,
                      availabilityCode: _availabilityCode,
                    ),
                  ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacyInventoryList extends ConsumerWidget {
  const _PharmacyInventoryList({
    required this.branchId,
    required this.pharmacy,
    required this.availabilityCode,
    this.onAddInventoryItem,
  });

  final String branchId;
  final PharmacyDetail pharmacy;
  final String Function(PharmacyInventoryItem item) availabilityCode;
  final void Function(PharmacyDetail branch, PharmacyInventoryItem item)?
      onAddInventoryItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(pharmacyInventoryProvider(branchId));

    return AsyncView<List<PharmacyInventoryItem>>(
      value: inventoryAsync,
      isEmpty: (items) => items.isEmpty,
      emptyMessage: 'No matching medicines in this branch.',
      onRetry: () => ref.invalidate(pharmacyInventoryProvider(branchId)),
      builder: (items) {
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              MedicineCard(
                key: ValueKey(items[i].medicineId),
                name: items[i].brandName,
                genericName: items[i].genericName,
                strength: items[i].strength,
                dosageForm: items[i].dosageForm,
                requiresPrescription: items[i].isRx,
                availability: availabilityCode(items[i]),
                priceText: items[i].formattedPrice,
                stockConfirmedAt: items[i].stockConfirmedAt,
                imageUrl: medicineImagePublicUrl(items[i].imagePath),
                onTap: items[i].availability.canReserve
                    ? () {
                        if (onAddInventoryItem != null) {
                          onAddInventoryItem!(pharmacy, items[i]);
                          return;
                        }
                        addMedicineToCartWithBranchCheck(
                          context: context,
                          ref: ref,
                          branchId: pharmacy.branchId,
                          medicineId: items[i].medicineId,
                          medicineName: items[i].brandName,
                          pharmacyName: pharmacy.pharmacyName,
                        );
                      }
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }
}
