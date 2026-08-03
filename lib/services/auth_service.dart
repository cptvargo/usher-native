import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown by [AuthService] with a message that's already safe to show
/// directly in the UI.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Admin registrations that include this code are auto-approved as Admin.
const kAdminCode = 'GUARDIAN-LEAD-2024';

/// Converts a phone number into the synthetic email Firebase Auth uses
/// under the hood for "no email" accounts, e.g. "(555) 123-4567" ->
/// "5551234567@usherapp.internal".
String phoneToInternalEmail(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  return '$digits@usherapp.internal';
}

/// Wraps Firebase Auth + the `team` Firestore collection with the church
/// usher app's registration rules: an usher may sign up with an email or
/// just a phone number, phone accounts can link to a pre-existing email
/// record so the same person doesn't appear twice in the roster, and new
/// registrations sit unapproved until a lead usher approves them (unless
/// they supply the admin code).
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _team =>
      _firestore.collection('team');

  Future<void> login({
    required bool usePhone,
    required String email,
    required String phone,
    required String password,
  }) async {
    final credentialEmail =
        usePhone ? phoneToInternalEmail(phone) : email.trim().toLowerCase();
    try {
      await _auth.signInWithEmailAndPassword(
        email: credentialEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e, usePhone: usePhone);
    }
  }

  Future<void> register({
    required bool usePhone,
    required String displayName,
    required String email,
    required String phone,
    required String existingEmail,
    required String password,
    required String adminCode,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw AuthException('Please enter your full name.');
    }
    if (usePhone && phone.replaceAll(RegExp(r'\D'), '').length < 7) {
      throw AuthException('Please enter a valid phone number.');
    }

    final credentialEmail =
        usePhone ? phoneToInternalEmail(phone) : email.trim().toLowerCase();

    final UserCredential userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: credentialEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e, usePhone: usePhone);
    }

    final uid = userCredential.user!.uid;
    await userCredential.user!.updateDisplayName(name);

    final isAdmin = adminCode.trim() == kAdminCode;

    try {
      if (usePhone && existingEmail.trim().isNotEmpty) {
        await _linkPhoneToExistingEmail(
          uid: uid,
          phone: phone,
          existingEmail: existingEmail,
        );
      } else {
        await _createOrClaimTeamRecord(
          uid: uid,
          usePhone: usePhone,
          name: name,
          email: email,
          phone: phone,
          isAdmin: isAdmin,
        );
      }
    } on AuthException {
      await userCredential.user!.delete();
      rethrow;
    }
  }

  Future<void> _linkPhoneToExistingEmail({
    required String uid,
    required String phone,
    required String existingEmail,
  }) async {
    final linkedEmail = existingEmail.trim().toLowerCase();
    final snap = await _team.where('email', isEqualTo: linkedEmail).get();
    if (snap.docs.isEmpty) {
      throw AuthException(
        'No account found with that email. Leave the field blank to register without linking.',
      );
    }
    final primaryDoc = snap.docs.first;
    await primaryDoc.reference
        .update({'phone': phone.trim(), 'phoneUid': uid});
    await _team.doc(uid).set({'linkedTo': primaryDoc.id});
  }

  Future<void> _createOrClaimTeamRecord({
    required String uid,
    required bool usePhone,
    required String name,
    required String email,
    required String phone,
    required bool isAdmin,
  }) async {
    QueryDocumentSnapshot<Map<String, dynamic>>? primaryDoc;

    if (usePhone) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final snap = await _team.get();
      for (final doc in snap.docs) {
        final docPhone = doc.data()['phone'] as String?;
        if (docPhone != null &&
            docPhone.replaceAll(RegExp(r'\D'), '') == digits) {
          primaryDoc = doc;
          break;
        }
      }
    } else {
      final linkedEmail = email.trim().toLowerCase();
      final snap = await _team.where('email', isEqualTo: linkedEmail).get();
      if (snap.docs.isNotEmpty) primaryDoc = snap.docs.first;
    }

    if (primaryDoc != null) {
      final updateFields = <String, dynamic>{'approved': true};
      if (usePhone) {
        updateFields['phoneUid'] = uid;
        updateFields['phone'] = phone.trim();
      } else {
        updateFields['emailUid'] = uid;
        updateFields['email'] = email.trim().toLowerCase();
      }
      await primaryDoc.reference.update(updateFields);
      await _team.doc(uid).set({'linkedTo': primaryDoc.id});
    } else {
      await _team.doc(uid).set({
        'id': uid,
        'name': name,
        if (usePhone) 'phone': phone.trim() else 'email': email.trim().toLowerCase(),
        'role': isAdmin ? 'Admin' : 'Usher',
        'approved': isAdmin,
        'denied': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw AuthException('Please enter your email address.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: trimmed.toLowerCase());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw AuthException('No account found with that email.');
      }
      throw AuthException('Could not send reset email. Try again.');
    }
  }

  AuthException _mapAuthError(FirebaseAuthException e, {required bool usePhone}) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthException(usePhone
            ? 'This phone number is already registered.'
            : 'This email is already registered.');
      case 'weak-password':
        return AuthException('Password should be at least 6 characters.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException(usePhone
            ? 'Incorrect phone number or password.'
            : 'Incorrect email or password.');
      default:
        return AuthException('Authentication failed. Please check your details.');
    }
  }
}
