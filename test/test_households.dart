import 'package:chorely/features/households/domain/household_repository.dart';

class TestHouseholds implements HouseholdRepository {
  final attempts = <String>[];
  bool fail = false;
  @override
  Stream<List<HouseholdSummary>> watchHouseholds(String uid) =>
      Stream.value([]);
  @override
  Stream<Household?> watchHousehold(String id) => Stream.value(null);
  @override
  Stream<List<HouseholdProfile>> watchProfiles(String id) => Stream.value([]);
  @override
  Future<String> create({
    required String commandId,
    required String name,
    required String nickname,
    required String timezone,
  }) async {
    attempts.add(commandId);
    if (fail) {
      throw const HouseholdFailure('Connection interrupted. Try again.');
    }
    return 'fictional-home';
  }
}
