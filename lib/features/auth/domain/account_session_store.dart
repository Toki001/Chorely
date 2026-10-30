import 'auth_repository.dart';

abstract interface class AccountSessionStore {
  Future<void> save(AccountSession session);
  Future<AccountSession?> read(String uid);
}
