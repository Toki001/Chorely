class AccountSession {
  const AccountSession({
    required this.uid,
    required this.email,
    required this.verified,
    this.supervised = false,
    this.restoring = false,
    this.householdId,
    this.profileId,
  });
  final String uid;
  final String email;
  final bool verified;
  final bool supervised, restoring;
  final String? householdId;
  final String? profileId;
}

abstract interface class AuthRepository {
  Stream<AccountSession?> watchSession();
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> sendVerification();
  Future<void> refresh();
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);
  final String message;
}
