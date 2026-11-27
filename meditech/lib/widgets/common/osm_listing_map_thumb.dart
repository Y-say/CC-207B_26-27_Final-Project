import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Small map preview for OpenStreetMap listings when no photo URL is available.
class OsmListingMapThumb extends StatelessWidget {
  const OsmListingMapThumb({
    super.key,
    required this.latitude,
    required this.longitude,
    this.size = 64,
  });

  final double latitude;
  final double longitude;
  final double size;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 17,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.meditech.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 22,
                  height: 22,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}