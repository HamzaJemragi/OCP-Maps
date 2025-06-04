// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class UserData {
//   Future<dynamic> getUserData() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       final userData =
//           await FirebaseFirestore.instance
//               .collection('utilisateurs')
//               .doc(user.uid)
//               .get();
//       return userData.data();
//     }
//     return null;
//   }
// }
