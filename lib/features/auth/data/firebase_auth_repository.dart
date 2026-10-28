import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<AccountSession?> watchSession() => _auth.userChanges().map(
    (user) => user == null
        ? null
        : AccountSession(
            uid: user.uid,
            email: user.email ?? '',
            verified: user.emailVerified,
          ),
  );

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AccountFailure(switch (e.code) {
        'network-request-failed' =>
          'Couldn’t connect. Check your connection and try again.',
        'too-many-requests' => 'Please wait a moment before trying again.',
        'weak-password' => 'Choose a password with at least 12 characters.',
        'email-already-in-use' => 'Couldn’t create this account. Try signing in or resetting your password.',
        _ => 'Couldn’t sign in. Check your details and try again.',
      });
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  });
  @override
  Future<void> register(String email, String password) => _guard(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _auth.currentUser!.sendEmailVerification();
  });
  @override
  Future<void> sendVerification() => _guard(() async {
    await _auth.currentUser?.sendEmailVerification();
  });
  @override
  Future<void> refresh() => _guard(() async {
    await _auth.currentUser?.reload();
    await _auth.currentUser?.getIdToken(true);
  });
  @override
  Future<void> resetPassword(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));
  @override
  Future<void> signOut() => _auth.signOut();
}
