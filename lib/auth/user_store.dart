import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreAuthService {
  final CollectionReference users = FirebaseFirestore.instance.collection('users');

  Future<String?> register(String name, String email, String password) async {
    final userDoc = users.doc(email);
    if ((await userDoc.get()).exists) return 'User already exists';

    await userDoc.set({
      'name': name,
      'email': email,
      'password': password,
    });
    return null;
  }

  Future<String?> login(String email, String password) async {
    final doc = await users.doc(email).get();
    if (!doc.exists) return 'User not found';

    final data = doc.data() as Map<String, dynamic>;
    return data['password'] == password ? null : 'Invalid password';
  }

  Future<bool> userExists(String email) async {
    return (await users.doc(email).get()).exists;
  }
}
