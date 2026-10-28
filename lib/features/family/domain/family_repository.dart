class FamilyPerson {
  const FamilyPerson({
    required this.id,
    required this.nickname,
    required this.role,
    required this.active,
  });
  final String id;
  final String nickname;
  final String role;
  final bool active;
}

class FamilyAccess {
  const FamilyAccess({
    required this.id,
    required this.kind,
    required this.status,
    this.profileId,
    this.role,
    this.expiresAt,
  });
  final String id;
  final String kind;
  final String status;
  final String? profileId;
  final String? role;
  final DateTime? expiresAt;
}

class FamilyFailure implements Exception {
  const FamilyFailure(this.message);
  final String message;
}

abstract interface class FamilyRepository {
  Stream<List<FamilyPerson>> watchPeople(String householdId);
  Stream<String?> watchRole(String householdId, String uid);
  Stream<List<FamilyAccess>> watchAccess(String householdId, String kind);
  Future<DateTime> invite({
    required String householdId,
    required String nonce,
    required String recipientEmail,
    required String role,
    required String commandId,
  });
  Future<String> accept({
    required String nonce,
    required String nickname,
    required String commandId,
  });
  Future<String> addChild({
    required String householdId,
    required String nickname,
    required String commandId,
  });
  Future<DateTime> approvePairing({
    required String householdId,
    required String profileId,
    required String nonce,
  });
  Future<void> pairDevice({
    required String nonce,
    required String deviceSecret,
  });
  Future<void> revoke({
    required String householdId,
    required String targetId,
    required String kind,
  });
}
