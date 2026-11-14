import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/env.dart';
import '../models/pharmacy_application.dart';

// A problem with the application, with messages for specific fields
class RegistrationException implements Exception {
  RegistrationException(this.message, [this.fieldErrors = const {}]);

  final String message;
  final Map<String, String> fieldErrors;
}

// Sends a pharmacy application to the server
class RegistrationService {
  RegistrationService(this._client);

  final http.Client _client;

  // Returns the new pharmacy ID, like PHM-000004
  Future<String> submit(PharmacyApplication application) async {
    final uri = Uri.parse('${Env.supabaseUrl}/functions/v1/submit-application');

    final request = http.MultipartRequest('POST', uri)
      ..headers['apikey'] = Env.supabasePublishableKey
      ..fields['data'] = jsonEncode(application.toJson())
      ..files.add(_file('lto_file', application.ltoFile))
      ..files.add(_file('storefront_file', application.storefrontFile));

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw RegistrationException('No internet connection. Please try again.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) return body['application_id'] as String;

    throw RegistrationException(
      body['error'] as String? ?? 'Something went wrong. Please try again.',
      Map<String, String>.from(body['fields'] as Map? ?? {}),
    );
  }

  // Turn a picked file into a form attachment
  http.MultipartFile _file(String field, PickedDocument doc) {
    return http.MultipartFile.fromBytes(
      field,
      doc.bytes,
      filename: doc.name,
      contentType: MediaType.parse(doc.mimeType),
    );
  }
}