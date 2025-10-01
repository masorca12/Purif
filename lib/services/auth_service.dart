import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AuthService {
static Future<void> login(String email, String pass) =>
FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);


static Future<void> register(String email, String pass, String role) async {
final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
'email': email,
'role': role,
'createdAt': FieldValue.serverTimestamp(),
});
}


static Future<void> logout() => FirebaseAuth.instance.signOut();
}