import '../../auth/domain/account_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/read_cache.dart';
import 'cached_models.dart';

/// Last confirmed account scope, bound to the SDK's current UID. No token/email
/// is persisted here. This supports cached views, never server authorization.
class CachedAccountSessionStore implements AccountSessionStore {
  CachedAccountSessionStore(this.store, {this.currentUid});
  final String? Function()? currentUid;
  final ReadCacheStore store;
  @override
  Future<void> save(AccountSession s) async {
    if (currentUid != null && currentUid!() != s.uid) return;
    final previous = await store.read(s.uid, '_account', 'session');
    if (previous != null) {
      final old = objectMap(previous.value);
      if (old['householdId'] is String &&
          (old['householdId'] != s.householdId ||
              old['profileId'] != s.profileId ||
              old['supervised'] != s.supervised)) {
        await store.purgeHousehold(s.uid, old['householdId'] as String);
      }
    }
    if (currentUid != null && currentUid!() != s.uid) return;
    await store.write(s.uid, '_account', 'session', {
      'uid': s.uid,
      'verified': s.verified,
      'supervised': s.supervised,
      'householdId': s.householdId,
      'profileId': s.profileId,
    }, DateTime.now());
    if (currentUid != null && currentUid!() != s.uid) {
      await store.purgeHousehold(s.uid, '_account');
    }
  }

  @override
  Future<AccountSession?> read(String uid) async {
    final saved = await store.read(uid, '_account', 'session');
    if (saved == null) return null;
    final s = objectMap(saved.value);
    if (s['uid'] != uid || (s['verified'] != true && s['supervised'] != true)) {
      return null;
    }
    if (s['supervised'] == true &&
        (s['householdId'] is! String || s['profileId'] is! String)) {
      return null;
    }
    return AccountSession(
      uid: uid,
      email: '',
      verified: s['verified'] == true,
      supervised: s['supervised'] == true,
      householdId: s['householdId'] as String?,
      profileId: s['profileId'] as String?,
    );
  }
}
