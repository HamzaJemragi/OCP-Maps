import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_data.dart';

// class SiteData {
  // Future<dynamic> getSiteData() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   final userData = await UserData().getUserData();
  //   if (user != null) {
  //     final siteData =
  //         await FirebaseFirestore.instance
  //             .collection('sites')
  //             .where("site", isEqualTo: userData['site'])
  //             .get();
  //     return siteData;
  //   }
  //   return null;
  // }

  // StreamB<QuerySnapshot> getSiteData() {
  //   final user = FirebaseAuth.instance.currentUser;
  //   final userData = UserData().getUserData();
  //   if (user != null) {
  //     return FirebaseFirestore.instance
  //         .collection('sites')
  //         .where("site", isEqualTo: userData['site'])
  //         .snapshots();
  //   }
  //   return Stream.empty();
  // }
// }