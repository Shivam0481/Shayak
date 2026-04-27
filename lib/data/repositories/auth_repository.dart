import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

enum UserRole { user, volunteer, admin }

class ShayakUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final bool isAvailable;
  final double? latitude;
  final double? longitude;

  ShayakUser({
    required this.uid,
    required this.email,
    required this.name,
    this.role = UserRole.user,
    this.isAvailable = false,
    this.latitude,
    this.longitude,
  });

  factory ShayakUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final email = data['email'] as String? ?? '';
    final roleStr = data['role'] as String?;
    UserRole parsedRole = UserRole.user;
    
    if (email == 'admin@shayak.com' || roleStr == 'admin' || data['isAdmin'] == true) {
      parsedRole = UserRole.admin;
    } else if (roleStr == 'volunteer') {
      parsedRole = UserRole.volunteer;
    }
    return ShayakUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: parsedRole,
      isAvailable: data['isAvailable'] ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role.name,
        'isAvailable': isAvailable,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<ShayakUser?> register({
    required String name,
    required String email,
    required String password,
    UserRole role = UserRole.user,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = ShayakUser(
      uid: cred.user!.uid,
      email: email,
      name: name,
      role: role,
    );
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
    return user;
  }

  Future<ShayakUser?> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return getCurrentUserDoc();
  }

  bool _gsiInitialized = false;

  Future<ShayakUser?> signInWithGoogle({UserRole targetRole = UserRole.user}) async {
    try {
      UserCredential userCred;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        userCred = await _auth.signInWithPopup(googleProvider);
      } else {
        final googleSignIn = gsi.GoogleSignIn.instance;
        if (!_gsiInitialized) {
          await googleSignIn.initialize();
          _gsiInitialized = true;
        }
        final googleUser = await googleSignIn.authenticate();
        if (googleUser == null) return null;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        userCred = await _auth.signInWithCredential(credential);
      }

      final user = userCred.user;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final isSysAdmin = user.email == 'admin@shayak.com';
        final newUser = ShayakUser(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Google User',
          role: isSysAdmin ? UserRole.admin : targetRole,
        );
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
      }
      return ShayakUser.fromDoc(doc);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  Future<ShayakUser?> getCurrentUserDoc() async {
    if (_auth.currentUser == null) return null;
    final doc =
        await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
    if (!doc.exists) return null;
    return ShayakUser.fromDoc(doc);
  }

  Future<void> toggleAvailability(String uid, bool isAvailable) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'isAvailable': isAvailable});
  }

  Future<void> updateLocation(String uid, double lat, double lng) async {
    await _firestore.collection('users').doc(uid).update({
      'latitude': lat,
      'longitude': lng,
    });
  }

  Future<void> updateFCMToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  Stream<ShayakUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShayakUser.fromDoc(doc);
    });
  }

  Stream<List<ShayakUser>> watchAllVolunteers() {
    return _firestore.collection('users')
        .where('role', isEqualTo: UserRole.volunteer.name)
        .snapshots().map((snap) {
      return snap.docs
          .map((doc) => ShayakUser.fromDoc(doc))
          .toList();
    });
  }

  Future<void> signOut() => _auth.signOut();
}
