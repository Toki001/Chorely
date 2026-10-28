import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/household_repository.dart';

class FirebaseHouseholdRepository implements HouseholdRepository {
  FirebaseHouseholdRepository(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<HouseholdSummary>> watchHouseholds(String uid) => _db
      .collection('users/$uid/households')
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => HouseholdSummary(
                id: d.id,
                name: d.data()['name'] as String,
                role: d.data()['role'] as String,
              ),
            )
            .toList(),
      );
  @override
  Stream<Household?> watchHousehold(String id) =>
      _db.doc('households/$id').snapshots().map((s) {
        final d = s.data();
        return d == null
            ? null
            : Household(
                id: s.id,
                name: d['name'] as String,
                timezone: d['timezoneIana'] as String,
              );
      });
  @override
  Stream<List<HouseholdProfile>> watchProfiles(String id) => _db
      .collection('households/$id/profiles')
      .snapshots()
      .map(
        (s) => s.docs
            .map(
              (d) => HouseholdProfile(
                nickname: d.data()['nickname'] as String,
                role: d.data()['role'] as String,
              ),
            )
            .toList(),
      );
  @override
  Future<String> create({
    required String commandId,
    required String name,
    required String nickname,
    required String timezone,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createHousehold')
          .call<Map<String, dynamic>>({
            'commandId': commandId,
            'name': name,
            'nickname': nickname,
            'timezone': timezone,
          });
      return result.data['householdId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw HouseholdFailure(switch (e.code) {
        'permission-denied' => 'Your account can’t create a household. Check that your email is verified.',
        'resource-exhausted' =>
          'Your account has reached the household creation limit.',
        'invalid-argument' =>
          'Check the household details and timezone, then try again.',
        'already-exists' => 'Your earlier request may have succeeded. Go back to your homes and check.',
        _ => 'Couldn’t confirm your household. Check your connection and try again.',
      });
    }
  }
}
