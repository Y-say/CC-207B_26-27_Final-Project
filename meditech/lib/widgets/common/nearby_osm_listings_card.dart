import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/osm_listing.dart';
import '../../providers/osm_listing_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Duplicate-check card shown during pharmacy registration Step 1
class NearbyOsmListingsCard extends ConsumerWidget {
  const NearbyOsmListingsCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.selectedListingId,
    required this.onSelectListing,
  });

  final double latitude;
  final double longitude;
  final String? selectedListingId;
  final ValueChanged<OsmListing?> onSelectListing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNearby = ref.watch(
      nearbyOsmListingsProvider((lat: latitude, lng: longitude)),
    );

    return asyncNearby.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (listings) {
        if (listings.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'We found a listing near your location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Is your pharmacy already listed on OpenStreetMap? Select it to replace the unverified map pin once approved.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...listings.map((item) {
                final isSelected = selectedListingId == item.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: InkWell(
                    onTap: () => onSelectListing(item),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _NearbyListingThumb(imageUrl: item.imageUrl),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.address,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.distanceMeters != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${item.distanceMeters} m',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              TextButton(
                onPressed: () => onSelectListing(null),
                child: Text(
                  selectedListingId == null
                      ? 'Selected: My pharmacy isn\'t listed here'
                      : 'My pharmacy isn\'t listed here',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NearbyListingThumb extends StatelessWidget {
  const _NearbyListingThumb({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.map_outlined,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}
