import 'package:chorely/features/family/domain/family_repository.dart';

class TestFamily implements FamilyRepository {
  String role = 'guardian';
  bool fail = false;
  final proofs = <String>[];
  final inviteIds = <String>[];
  List<FamilyPerson> people = const [];
  @override
  Stream<List<FamilyPerson>> watchPeople(String householdId) =>
      Stream.value(people);
  @override
  Stream<String?> watchRole(String householdId, String uid) =>
      Stream.value(role);
  @override
  Stream<List<FamilyAccess>> watchAccess(String householdId, String kind) =>
      Stream.value([]);
  @override
  Future<DateTime> invite({
    required String householdId,
    required String nonce,
    required String recipientEmail,
    required String role,
    required String commandId,
  }) async {
    inviteIds.add(commandId);
    return DateTime.now().add(const Duration(minutes: 10));
  }

  @override
  Future<String> accept({
    required String nonce,
    required String nickname,
    required String commandId,
  }) async => 'fictional-home';
  @override
  Future<String> addChild({
    required String householdId,
    required String nickname,
    required String commandId,
  }) async => 'fictional-child';
  @override
  Future<DateTime> approvePairing({
    required String householdId,
    required String profileId,
    required String nonce,
  }) async => DateTime.now().add(const Duration(minutes: 10));
  @override
  Future<void> pairDevice({
    required String nonce,
    required String deviceSecret,
  }) async {
    proofs.add(deviceSecret);
    if (fail) {
      throw const FamilyFailure('Connection interrupted. Retry this device.');
    }
  }

  @override
  Future<void> revoke({
    required String householdId,
    required String targetId,
    required String kind,
  }) async {}
}
