import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/branch_settings.dart';

// Service for loading and updating branch settings and profile (Ph-36)
class BranchSettingsService {
  BranchSettingsService({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client {
    final client = _providedClient;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  static String _formatOperatingHours(List<dynamic> rows) {
    if (rows.isEmpty) return 'Hours not set';

    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final openDays = <String>[];
    String? sampleOpens;
    String? sampleCloses;

    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      if (row['is_closed'] == true) continue;
      final weekday = (row['weekday'] as num?)?.toInt() ?? 0;
      if (weekday >= 0 && weekday < weekdays.length) {
        openDays.add(weekdays[weekday]);
      }
      sampleOpens ??= _formatTime(row['opens_at']);
      sampleCloses ??= _formatTime(row['closes_at']);
    }

    if (openDays.isEmpty) return 'Closed until further notice';
    final days = openDays.length >= 7 ? 'Mon–Sun' : openDays.join(', ');
    final opens = sampleOpens ?? '—';
    final closes = sampleCloses ?? '—';
    return '$days, $opens – $closes';
  }

  static String _formatTime(dynamic value) {
    if (value == null) return '—';
    final text = value.toString();
    // Postgres time often looks like 07:00:00
    if (text.length >= 5) {
      final parts = text.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final dt = DateTime(2000, 1, 1, h, m);
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:${m.toString().padLeft(2, '0')} $ampm';
      }
    }
    return text;
  }

  // Loads current branch settings including FDA LTO and owner license
  Future<BranchSettings> loadSettings() async {
    final branchId = await _client.rpc('my_branch_id') as String?;
    if (branchId == null) {
      throw Exception('Branch settings not found.');
    }

    final response = await _client
        .from('branches')
        .select('''
          id,
          display_id,
          pharmacy_name,
          branch_name,
          address,
          contact_number,
          email,
          latitude,
          longitude,
          lto_number,
          lto_expiry
        ''')
        .eq('id', branchId)
        .maybeSingle();

    if (response == null) {
      throw Exception('Branch settings not found.');
    }

    final hoursRows = await _client
        .from('branch_hours')
        .select('weekday, opens_at, closes_at, is_closed')
        .eq('branch_id', branchId)
        .order('weekday');

    String? storefrontPath;
    try {
      final docRow = await _client
          .from('branch_documents')
          .select('storage_path')
          .eq('branch_id', branchId)
          .eq('kind', 'storefront')
          .order('uploaded_at', ascending: false)
          .limit(1)
          .maybeSingle();
      storefrontPath = docRow?['storage_path'] as String?;
    } catch (_) {}

    return BranchSettings(
      branchId: response['id']?.toString() ?? branchId,
      pharmacyName: response['pharmacy_name']?.toString() ?? '',
      branchName: response['branch_name']?.toString() ?? '',
      address: response['address']?.toString() ?? '',
      contactNumber: response['contact_number']?.toString() ?? '',
      pharmacyEmail: response['email']?.toString() ?? '',
      operatingHours: _formatOperatingHours(hoursRows as List<dynamic>),
      latitude: (response['latitude'] as num?)?.toDouble(),
      longitude: (response['longitude'] as num?)?.toDouble(),
      fdaLto: response['lto_number']?.toString() ?? '',
      fdaLtoExpiry: response['lto_expiry'] != null
          ? DateTime.tryParse(response['lto_expiry'].toString())
          : null,
      storefrontPath: storefrontPath,
    );
  }

  // Updates branch profile and operating details
  Future<void> updateSettings({
    required String branchId,
    required String address,
    required String contactNumber,
    required String operatingHours,
    double? latitude,
    double? longitude,
    bool updateBranchDetails = true,
  }) async {
    if (!updateBranchDetails) return;

    await _client.from('branches').update({
      'address': address,
      'contact_number': contactNumber,
      ...?latitude != null ? {'latitude': latitude} : null,
      ...?longitude != null ? {'longitude': longitude} : null,
    }).eq('id', branchId);

    // Operating hours text is display-only for now (hours live in branch_hours).
  }
}