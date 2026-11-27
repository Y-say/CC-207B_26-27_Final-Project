import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/route_service.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Values passed into /directions so every Get directions button opens this screen
class DirectionsArgs {
  const DirectionsArgs({
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.destination,
    this.fromOsmDirectory = false,
  });

  final String pharmacyName;
  final String branchName;
  final String address;
  final LatLng destination;
  final bool fromOsmDirectory;

  /// Route location with query params so directions still work if [extra] is dropped.
  String get routeLocation {
    final query = <String, String>{
      'lat': destination.latitude.toString(),
      'lng': destination.longitude.toString(),
      'name': pharmacyName,
      'address': address,
      if (branchName.isNotEmpty) 'branch': branchName,
      if (fromOsmDirectory) 'osm': '1',
    };
    return Uri(path: '/directions', queryParameters: query).toString();
  }
}

DirectionsArgs? directionsArgsFromQuery(Map<String, String> query) {
  final lat = double.tryParse(query['lat'] ?? '');
  final lng = double.tryParse(query['lng'] ?? '');
  if (lat == null || lng == null) return null;
  return DirectionsArgs(
    pharmacyName: query['name'] ?? 'Pharmacy',
    branchName: query['branch'] ?? '',
    address: query['address'] ?? '',
    destination: LatLng(lat, lng),
    fromOsmDirectory: query['osm'] == '1',
  );
}

enum _TravelMode { vehicle, commute, walk }

extension on _TravelMode {
  String get label => switch (this) {
        _TravelMode.vehicle => 'Vehicle',
        _TravelMode.commute => 'Commute',
        _TravelMode.walk => 'Walk',
      };

  String get profile => switch (this) {
        _TravelMode.vehicle => 'driving-car',
        _TravelMode.commute => 'cycling-regular',
        _TravelMode.walk => 'foot-walking',
      };

  String get paceNote => switch (this) {
        _TravelMode.vehicle => 'Typical city traffic',
        _TravelMode.commute => 'Cycling pace',
        _TravelMode.walk => 'Pedestrian pace',
      };

  String get routeBlurb => switch (this) {
        _TravelMode.vehicle =>
          'Fastest driving route along major roads where available.',
        _TravelMode.commute =>
          'Bike-friendly route along city streets where available.',
        _TravelMode.walk =>
          'Continuous pedestrian route along city streets (~4.8 km/h pace).',
      };
}

// Screen showing route, distance, and estimated travel time to a pharmacy
class DirectionsScreen extends StatefulWidget {
  const DirectionsScreen({
    super.key,
    required this.pharmacyName,
    required this.branchName,
    required this.address,
    required this.destination,
    this.fromOsmDirectory = false,
    this.routeService,
  });

  final String pharmacyName;
  final String branchName;
  final String address;
  final LatLng destination;
  final bool fromOsmDirectory;
  final RouteService? routeService;

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  late final RouteService _routeService;
  final _mapController = MapController();

  static const _defaultOrigin = LatLng(10.7202, 122.5621);
  LatLng _origin = _defaultOrigin;
  String _originLabel = 'Iloilo City Center';

  bool _loading = false;
  bool _permissionDenied = false;
  RouteResult? _routeResult;
  _TravelMode _mode = _TravelMode.walk;
  bool _navigating = false;
  LatLng? _liveLocation;
  int _currentStepIndex = 0;
  int? _remainingMeters;
  StreamSubscription<Position>? _positionSub;
  bool _fitRouteOnNextLoad = true;

  LatLng get _userOnMap => _liveLocation ?? _origin;

  bool get _insecureWebGeolocation {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    if (uri.scheme == 'https') return false;
    final host = uri.host.toLowerCase();
    return host != 'localhost' && host != '127.0.0.1';
  }

  String get _locationDeniedMessage {
    if (_insecureWebGeolocation) {
      return 'GPS is blocked on plain HTTP (Not secure in the browser). '
          'Tap the map to set where you are, use Change start, or open the app '
          'over HTTPS / localhost for live GPS.';
    }
    return 'Location denied. Allow location for this site in browser settings, '
        'tap the map to set where you are, or use Change start.';
  }

  void _setStartFromMap(LatLng point) {
    if (_navigating) _stopNavigation();
    setState(() {
      _origin = point;
      _liveLocation = point;
      _originLabel = 'Dropped pin on map';
      _permissionDenied = false;
    });
    _fitRouteOnNextLoad = true;
    _fetchRoute();
  }

  void _fitRouteOverview(List<LatLng> points) {
    if (points.length < 2) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(72),
        maxZoom: 14,
        minZoom: 12,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _routeService = widget.routeService ?? RouteService();
    _initStartingLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  int get _straightLineMeters => const Distance()
      .as(LengthUnit.Meter, _origin, widget.destination)
      .round();

  String get _straightLineLabel {
    final meters = _straightLineMeters;
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _initStartingLocation() async {
    setState(() => _loading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _permissionDenied = true;
          _originLabel = 'Iloilo City Center (GPS off)';
        });
        await _fetchRoute();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _permissionDenied = true;
          _originLabel = 'Iloilo City Center (Location denied)';
        });
        await _fetchRoute();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: kIsWeb ? 15 : 8),
        ),
      );

      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _originLabel = 'Current Location';
        _permissionDenied = false;
      });
    } catch (_) {
      setState(() {
        _permissionDenied = true;
        _originLabel = 'Iloilo City Center (Default)';
      });
    }

    await _fetchRoute();
  }

  Future<void> _retryLocationPermission() async {
    if (_insecureWebGeolocation) {
      _showChangeOriginDialog();
      return;
    }
    setState(() => _loading = true);
    final allowed = await _ensureLocationPermission();
    if (!allowed) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionDenied = true;
      });
      final opened = await Geolocator.openAppSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_locationDeniedMessage)),
        );
      }
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _liveLocation = _origin;
        _originLabel = 'Your location';
        _permissionDenied = false;
      });
      _fitRouteOnNextLoad = true;
      await _fetchRoute();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still could not read GPS. Try Change.')),
        );
      }
    }
  }

  Future<void> _fetchRoute() async {
    setState(() => _loading = true);
    try {
      final result = await _routeService.getDirections(
        start: _origin,
        end: widget.destination,
        profile: _mode.profile,
      );

      if (mounted) {
        setState(() {
          _routeResult = result;
          _loading = false;
        });

        if (_fitRouteOnNextLoad) {
          final points = [_origin, widget.destination, ...result.points];
          _fitRouteOverview(points);
          _fitRouteOnNextLoad = false;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onModeSelected(_TravelMode mode) {
    if (_mode == mode) return;
    if (_navigating) _stopNavigation();
    setState(() => _mode = mode);
    _fetchRoute();
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final live = LatLng(position.latitude, position.longitude);
    setState(() {
      _liveLocation = live;
      _origin = live;
      _originLabel = 'Your location';
      _permissionDenied = false;
    });
    _syncTurnByTurnProgress(live);
    if (_navigating) {
      final zoom = _mapController.camera.zoom.clamp(14.0, 17.0);
      _mapController.move(live, zoom);
    }
  }

  void _syncTurnByTurnProgress(LatLng live) {
    final route = _routeResult;
    final steps = route?.steps ?? const <RouteStep>[];
    final remaining =
        const Distance().as(LengthUnit.Meter, live, widget.destination).round();
    setState(() => _remainingMeters = remaining);

    if (steps.isEmpty || route == null || route.points.length < 2) return;

    if (remaining <= 35) {
      setState(() => _currentStepIndex = steps.length - 1);
      return;
    }

    final points = route.points;
    var closestIdx = 0;
    var closestDist = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = const Distance().as(LengthUnit.Meter, live, points[i]);
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }
    final progress = closestIdx / (points.length - 1);
    final stepIdx =
        (progress * steps.length).floor().clamp(0, steps.length - 1);
    if (stepIdx != _currentStepIndex) {
      setState(() => _currentStepIndex = stepIdx);
    }
  }

  Future<void> _toggleTurnByTurn() async {
    if (_navigating) {
      _stopNavigation();
      return;
    }

    final allowed = await _ensureLocationPermission();
    if (!allowed) {
      if (!mounted) return;
      setState(() => _permissionDenied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turn on location access to use in-app navigation.'),
        ),
      );
      return;
    }

    await _positionSub?.cancel();
    setState(() {
      _navigating = true;
      _currentStepIndex = 0;
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate, onError: (_) {});

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      _onPositionUpdate(position);
      await _fetchRoute();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read GPS. Try again outdoors.')),
        );
      }
    }
  }

  void _stopNavigation() {
    _positionSub?.cancel();
    _positionSub = null;
    setState(() => _navigating = false);
  }

  void _showChangeOriginDialog() {
    final presets = <String, LatLng>{
      'Iloilo City Hall': const LatLng(10.6929, 122.5694),
      'Jaro Plaza': const LatLng(10.7248, 122.5562),
      'SM City Iloilo': const LatLng(10.7145, 122.5492),
      'Central Philippine University': const LatLng(10.7303, 122.5487),
      'La Paz Plaza': const LatLng(10.7100, 122.5714),
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg + bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Starting Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Choose where you are departing from:',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...presets.entries.map((entry) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _origin = entry.value;
                          _originLabel = entry.key;
                          _permissionDenied = false;
                        });
                        _fitRouteOnNextLoad = true;
                        _fetchRoute();
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  @override
  Widget build(BuildContext context) {
    final polylinePoints = _routeResult?.points.isNotEmpty == true
        ? _routeResult!.points
        : [_origin, widget.destination];
    final useSideBySide = MediaQuery.sizeOf(context).width >= 900;
    final displayName = widget.pharmacyName.isNotEmpty
        ? widget.pharmacyName
        : widget.branchName;
    final steps = _routeResult?.steps ?? const <RouteStep>[];
    final nextInstruction = steps.isEmpty
        ? null
        : steps[_currentStepIndex.clamp(0, steps.length - 1)].instruction;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Material(
                elevation: 6,
                shadowColor: Colors.black26,
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _DirectionsHeader(
                      name: displayName,
                      address: widget.address,
                      fromOsmDirectory: widget.fromOsmDirectory,
                      onClose: () {
                        _stopNavigation();
                        Navigator.of(context).maybePop();
                      },
                    ),
                    Expanded(
                      child: useSideBySide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _DirectionsMap(
                                    mapController: _mapController,
                                    origin: _userOnMap,
                                    destination: widget.destination,
                                    polylinePoints: polylinePoints,
                                    loading: _loading,
                                    navigating: _navigating,
                                    nextInstruction: _navigating
                                        ? nextInstruction
                                        : null,
                                    remainingMeters: _navigating
                                        ? _remainingMeters
                                        : null,
                                    allowPickStart: _permissionDenied,
                                    onPickStart: _setStartFromMap,
                                    onZoomIn: () => _zoomBy(1),
                                    onZoomOut: () => _zoomBy(-1),
                                  ),
                                ),
                                SizedBox(
                                  width: 420,
                                  child: _DirectionsPanel(
                                    showLeftDivider: true,
                                    mode: _mode,
                                    loading: _loading,
                                    route: _routeResult,
                                    straightLineLabel: _straightLineLabel,
                                    originLabel: _originLabel,
                                    permissionDenied: _permissionDenied,
                                    locationDeniedMessage:
                                        _locationDeniedMessage,
                                    destination: widget.destination,
                                    navigating: _navigating,
                                    currentStepIndex: _currentStepIndex,
                                    remainingMeters: _remainingMeters,
                                    onModeSelected: _onModeSelected,
                                    onChangeOrigin: _showChangeOriginDialog,
                                    onRetryLocation: _retryLocationPermission,
                                    onToggleNavigation: _toggleTurnByTurn,
                                    onRefresh: _loading ? null : _fetchRoute,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: 320,
                                  child: _DirectionsMap(
                                    mapController: _mapController,
                                    origin: _userOnMap,
                                    destination: widget.destination,
                                    polylinePoints: polylinePoints,
                                    loading: _loading,
                                    navigating: _navigating,
                                    nextInstruction: _navigating
                                        ? nextInstruction
                                        : null,
                                    remainingMeters: _navigating
                                        ? _remainingMeters
                                        : null,
                                    allowPickStart: _permissionDenied,
                                    onPickStart: _setStartFromMap,
                                    onZoomIn: () => _zoomBy(1),
                                    onZoomOut: () => _zoomBy(-1),
                                  ),
                                ),
                                Expanded(
                                  child: _DirectionsPanel(
                                    showLeftDivider: false,
                                    mode: _mode,
                                    loading: _loading,
                                    route: _routeResult,
                                    straightLineLabel: _straightLineLabel,
                                    originLabel: _originLabel,
                                    permissionDenied: _permissionDenied,
                                    locationDeniedMessage:
                                        _locationDeniedMessage,
                                    destination: widget.destination,
                                    navigating: _navigating,
                                    currentStepIndex: _currentStepIndex,
                                    remainingMeters: _remainingMeters,
                                    onModeSelected: _onModeSelected,
                                    onChangeOrigin: _showChangeOriginDialog,
                                    onRetryLocation: _retryLocationPermission,
                                    onToggleNavigation: _toggleTurnByTurn,
                                    onRefresh: _loading ? null : _fetchRoute,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionsHeader extends StatelessWidget {
  const _DirectionsHeader({
    required this.name,
    required this.address,
    required this.fromOsmDirectory,
    required this.onClose,
  });

  final String name;
  final String address;
  final bool fromOsmDirectory;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (fromOsmDirectory)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'OpenStreetMap Directory',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _DirectionsMap extends StatelessWidget {
  const _DirectionsMap({
    required this.mapController,
    required this.origin,
    required this.destination,
    required this.polylinePoints,
    required this.loading,
    required this.navigating,
    this.nextInstruction,
    this.remainingMeters,
    required this.allowPickStart,
    required this.onPickStart,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final MapController mapController;
  final LatLng origin;
  final LatLng destination;
  final List<LatLng> polylinePoints;
  final bool loading;
  final bool navigating;
  final String? nextInstruction;
  final int? remainingMeters;
  final bool allowPickStart;
  final void Function(LatLng point) onPickStart;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    const routeBlue = Color(0xFF2563EB);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: origin,
            initialZoom: 14,
            onTap: allowPickStart
                ? (_, point) => onPickStart(point)
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.meditech',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: polylinePoints,
                  strokeWidth: 5,
                  color: routeBlue,
                  pattern: StrokePattern.dashed(segments: [14, 10]),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: origin,
                  width: navigating ? 40 : 34,
                  height: navigating ? 40 : 34,
                  alignment: Alignment.center,
                  child: Icon(
                    navigating ? Icons.navigation : Icons.my_location,
                    color: routeBlue,
                    size: navigating ? 36 : 30,
                  ),
                ),
                Marker(
                  point: destination,
                  width: 40,
                  height: 40,
                  alignment: Alignment.bottomCenter,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: _MapZoomControls(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
          ),
        ),
        if (allowPickStart)
          Positioned(
            top: 52,
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFEFF6FF),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'Tap the map to set your location for road directions.',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        if (nextInstruction != null)
          Positioned(
            top: AppSpacing.sm,
            left: 52,
            right: AppSpacing.sm,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextInstruction!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (remainingMeters != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$remainingMeters m to pharmacy',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: _MapLegend(),
        ),
        if (loading)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onZoomIn,
            icon: const Icon(Icons.add, size: 20),
          ),
          const Divider(height: 1),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendRow(const Color(0xFF2563EB), 'You'),
            const SizedBox(height: 4),
            _legendRow(AppColors.primary, 'Pharmacy', label: 'P'),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: CustomPaint(
                    painter: _DashedLinePainter(),
                    size: const Size(28, 8),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Road Route',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String text, {String? label}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: label == null
              ? null
              : Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DirectionsPanel extends StatelessWidget {
  const _DirectionsPanel({
    required this.showLeftDivider,
    required this.mode,
    required this.loading,
    required this.route,
    required this.straightLineLabel,
    required this.originLabel,
    required this.permissionDenied,
    required this.locationDeniedMessage,
    required this.destination,
    required this.onModeSelected,
    required this.onChangeOrigin,
    required this.onRetryLocation,
    required this.onToggleNavigation,
    required this.onRefresh,
    required this.navigating,
    required this.currentStepIndex,
    this.remainingMeters,
  });

  final bool showLeftDivider;
  final _TravelMode mode;
  final bool loading;
  final RouteResult? route;
  final String straightLineLabel;
  final String originLabel;
  final bool permissionDenied;
  final String locationDeniedMessage;
  final LatLng destination;
  final bool navigating;
  final int currentStepIndex;
  final int? remainingMeters;
  final ValueChanged<_TravelMode> onModeSelected;
  final VoidCallback onChangeOrigin;
  final VoidCallback onRetryLocation;
  final VoidCallback onToggleNavigation;
  final VoidCallback? onRefresh;

  String get _stepsSourceLabel {
    final provider = route?.provider;
    return switch (provider) {
      'openrouteservice' => 'OpenRouteService',
      'osrm' => 'OSRM Roads',
      'local_fallback' => 'Estimate only',
      _ => 'OSRM Roads',
    };
  }

  @override
  Widget build(BuildContext context) {
    final steps = route?.steps ?? const <RouteStep>[];

    return Container(
      decoration: BoxDecoration(
        border: showLeftDivider
            ? const Border(left: BorderSide(color: AppColors.border))
            : const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (permissionDenied)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              color: AppColors.warningLight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_off,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            locationDeniedMessage,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        TextButton(
                          onPressed: onRetryLocation,
                          child: const Text('Try GPS again'),
                        ),
                        TextButton(
                          onPressed: onChangeOrigin,
                          child: const Text('Change start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (route?.provider == 'local_fallback')
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              color: const Color(0xFFFFF7ED),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text(
                        'Road routing is unavailable. Pull to refresh or '
                        'check your internet connection.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: _TravelMode.values.map((value) {
              final selected = value == mode;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: value != _TravelMode.walk ? AppSpacing.sm : 0,
                  ),
                  child: OutlinedButton(
                    onPressed: loading ? null : () => onModeSelected(value),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: selected
                          ? AppColors.primary
                          : AppColors.textMuted,
                      backgroundColor:
                          selected ? AppColors.primaryLight : Colors.white,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      value.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onChangeOrigin,
            child: Text(
              'From: $originLabel',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'ROAD DISTANCE',
                  value: route?.formattedDistance ?? '...',
                  subtitle: 'Straight-line: $straightLineLabel',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: 'EST. TIME',
                  value: route?.formattedDuration ?? '...',
                  subtitle: mode.paceNote,
                  valueColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            mode.routeBlurb,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Road Route Steps',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _stepsSourceLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Recalculate',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (steps.isEmpty && !loading)
            const Text(
              'No step-by-step directions yet.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final active = navigating && index == currentStepIndex;
              final passed = navigating && index < currentStepIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: active
                      ? const EdgeInsets.all(AppSpacing.sm)
                      : EdgeInsets.zero,
                  decoration: active
                      ? BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: passed
                              ? AppColors.textMuted
                              : AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${step.instruction} (${step.distanceLabel})',
                          style: TextStyle(
                            fontSize: 13,
                            color: passed
                                ? AppColors.textMuted
                                : AppColors.text,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.md),
          Text(
            'GPS: ${destination.latitude.toStringAsFixed(4)}° N, '
            '${destination.longitude.toStringAsFixed(4)}° E',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (navigating && remainingMeters != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '$remainingMeters m remaining to the pharmacy',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onToggleNavigation,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor:
                    navigating ? AppColors.textMuted : AppColors.primary,
              ),
              icon: Icon(navigating ? Icons.stop_circle_outlined : Icons.navigation),
              label: Text(
                navigating
                    ? 'Stop turn-by-turn'
                    : 'Start turn-by-turn navigation',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.valueColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}