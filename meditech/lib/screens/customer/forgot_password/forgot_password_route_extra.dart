Map<String, String?>? forgotPasswordRouteExtra(Object? extra) {
  if (extra is! Map) return null;
  final identifier = extra['identifier'];
  final deliveryEmail = extra['deliveryEmail'];
  return {
    'identifier': identifier is String ? identifier : null,
    'deliveryEmail': deliveryEmail is String ? deliveryEmail : null,
  };
}