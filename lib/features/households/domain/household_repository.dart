class HouseholdSummary {
  const HouseholdSummary({
    required this.id,
    required this.name,
    required this.role,
  });
  final String id;
  final String name;
  final String role;
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.timezone,
  });
  final String id;
  final String name;
  final String timezone;
}

class HouseholdProfile {
  const HouseholdProfile({required this.nickname, required this.role});
  final String nickname;
  final String role;
}

class HouseholdFailure implements Exception {
  const HouseholdFailure(this.message);
  final String message;
}

abstract interface class HouseholdRepository {
  Stream<List<HouseholdSummary>> watchHouseholds(String uid);
  Stream<Household?> watchHousehold(String id);
  Stream<List<HouseholdProfile>> watchProfiles(String id);
  Future<String> create({
    required String commandId,
    required String name,
    required String nickname,
    required String timezone,
  });
}
