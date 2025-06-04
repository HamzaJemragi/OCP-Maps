// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Get current user
//   User? getCurrentUser() {
//     return _auth.currentUser;
//   }

//   // Stream of authentication state changes
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   // Sign In with Email and Password
//   Future<UserCredential?> signInWithEmailPassword(
//     String email,
//     String password,
//   ) async {
//     try {
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return userCredential;
//     } on FirebaseAuthException catch (e) {
//       print("FirebaseAuthException during sign in: ${e.message}");
//       throw e;
//     } catch (e) {
//       print("Error during sign in: $e");
//       throw e;
//     }
//   }

//   // Sign Out
//   Future<void> signOut() async {
//     try {
//       await _auth.signOut();
//     } catch (e) {
//       print("Error during sign out: $e");
//       throw e;
//     }
//   }

//   // Fetch user data (including site) from Firestore
//   Future<Map<String, dynamic>?> getUserData(String uid) async {
//     try {
//       DocumentSnapshot doc =
//           await _firestore.collection('users').doc(uid).get();
//       if (doc.exists) {
//         return doc.data() as Map<String, dynamic>?;
//       }
//       return null;
//     } catch (e) {
//       print("Error fetching user data: $e");
//       return null;
//     }
//   }
// }
// https://www.google.com/maps/place/Office+Ch%C3%A9rifien+des+Phosphates/@33.5496179,-7.647463,17z/data=!3m1!4b1!4m6!3m5!1s0xda62d2f9c1f95bb:0x7f4323e00d2044a1!8m2!3d33.5496179!4d-7.647463!16s%2Fg%2F1hm4p8d87?entry=ttu&g_ep=EgoyMDI1MDUyNy4wIKXMDSoJLDEwMjExNDUzSAFQAw%3D%3D