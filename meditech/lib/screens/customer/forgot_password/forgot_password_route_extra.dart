Map<String, String?>? forgotPasswordRouteExtra(Object? extra) {
  if (extra is! Map) return null;
  final identifier = extra['identifier'];
  final deliveryEmail = extra['deliveryEmail'];
  final signInPath = extra['signInPath'];
  final resetPath = extra['resetPath'];
  return {
    'identifier': identifier is String ? identifier : null,
    'deliveryEmail': deliveryEmail is String ? deliveryEmail : null,
    'signInPath': signInPath is String ? signInPath : '/sign-in',
    'resetPath': resetPath is String ? resetPath : '/forgot-password/reset',
  };
}