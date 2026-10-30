import '../domain/account_session_store.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, {this.sessionStore});
  final FirebaseAuth _auth;
  final AccountSessionStore? sessionStore;

  @override
  Stream<AccountSession?> watchSession() {
    late final StreamController<AccountSession?> controller;
    StreamSubscription<User?>? subscription;
    var generation = 0;
    String? lastUid;
    controller = StreamController<AccountSession?>(
      onListen: () {
        subscription = _auth.userChanges().listen((user) async {
          final current = ++generation;
          if (user == null) {
            lastUid = null;
            controller.add(null);
            return;
          }
          if (lastUid != user.uid) {
            controller.add(
              AccountSession(
                uid: user.uid,
                email: user.email ?? '',
                verified: false,
                restoring: true,
              ),
            );
          }
          lastUid = user.uid;
          try {
            final claims =
                (await user.getIdTokenResult()).claims ?? <String, dynamic>{};
            if (current != generation || controller.isClosed) return;
            final session = AccountSession(
              uid: user.uid,
              email: user.email ?? '',
              verified: user.emailVerified,
              supervised: claims['scopedChild'] == true,
              householdId: claims['householdId'] as String?,
              profileId: claims['actorId'] as String?,
            );
            if (session.verified || session.supervised) {
              try {
                await sessionStore?.save(session);
              } catch (_) {}
            }
            if (current == generation && !controller.isClosed) {
              controller.add(session);
            }
          } catch (error, stack) {
            // A currently signed-in SDK UID may read its last confirmed scope
            // during network failure. Revoked/disabled credentials never fall back.
            if (error is FirebaseAuthException &&
                error.code == 'network-request-failed') {
              try {
                final cached = await sessionStore?.read(user.uid);
                if (cached != null &&
                    current == generation &&
                    !controller.isClosed) {
                  controller.add(cached);
                  return;
                }
              } catch (_) {}
            }
            if (current == generation && !controller.isClosed) {
              controller.addError(error, stack);
            }
          }
        }, onError: controller.addError);
      },
      onCancel: () async {
        generation++;
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

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
