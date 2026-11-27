import 'package:geolocator/geolocator.dart';

import '../providers/customer_location_provider.dart';

/// Location context sent to Medipal — does not request permission (read-only).
class AssistantLocationPayload {
  const AssistantLocationPayload({
    required this.status,
    this.latitude,
    this.longitude,
    this.label,
    required this.weekday,
    required this.minutesSinceMidnight,
  });

  final String status;
  final double? latitude;
  final double? longitude;
  final String? label;
  final int weekday;
  final int minutesSinceMidnight;

  Map<String, dynamic> toJson() => {
        'status': status,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (label != null && label!.isNotEmpty) 'label': label,
        'weekday': weekday,
        'minutes_since_midnight': minutesSinceMidnight,
      };
}

Future<AssistantLocationPayload> buildAssistantLocationPayload({
  CustomerPlace? cachedPlace,
  bool providerLoading = false,
}) async {
  final now = DateTime.now();
  final weekday = now.weekday % 7;
  final minutes = now.hour * 60 + now.minute;

  if (providerLoading) {
    return AssistantLocationPayload(
      status: 'loading',
      weekday: weekday,
      minutesSinceMidnight: minutes,
    );
  }

  try {
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) {
      return AssistantLocationPayload(
        status: 'services_disabled',
        weekday: weekday,
        minutesSinceMidnight: minutes,
      );
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return AssistantLocationPayload(
        status: 'denied_forever',
        weekday: weekday,
        minutesSinceMidnight: minutes,
      );
    }
    if (permission == LocationPermission.denied) {
      return AssistantLocationPayload(
        status: 'denied',
        weekday: weekday,
        minutesSinceMidnight: minutes,
      );
    }

    final lat = cachedPlace?.latitude;
    final lng = cachedPlace?.longitude;
    if (lat != null && lng != null) {
      return AssistantLocationPayload(
        status: 'granted',
        latitude: lat,
        longitude: lng,
        label: cachedPlace?.label,
        weekday: weekday,
        minutesSinceMidnight: minutes,
      );
    }

    return AssistantLocationPayload(
      status: 'unavailable',
      weekday: weekday,
      minutesSinceMidnight: minutes,
    );
  } catch (_) {
    return AssistantLocationPayload(
      status: 'unavailable',
      weekday: weekday,
      minutesSinceMidnight: minutes,
    );
  }
}