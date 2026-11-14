// Who just signed in, taken from the login token
class SignedInAccount {
  final String accountType;
  final String state;
  final String? role;
  final String? branchId;

  const SignedInAccount({
    required this.accountType,
    required this.state,
    this.role,
    this.branchId,
  });

  factory SignedInAccount.fromJson(Map<String, dynamic> json) {
    return SignedInAccount(
      accountType: (json['app_account_type'] ?? json['account_type']) as String,
      state: json['app_state'] as String? ?? 'active',
      role: json['app_role'] as String?,
      branchId: json['app_branch_id'] as String?,
    );
  }
}
