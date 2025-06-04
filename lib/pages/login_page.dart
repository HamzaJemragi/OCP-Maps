import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import '../components/my_button.dart';
import '../components/my_textfield.dart';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  // text editing controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  void _signIn() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
      usernameController.clear();
      passwordController.clear();
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      if (e.code == 'user-not-found') {
        print(e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found for that email.', style: TextStyle(color: Colors.red),)),
        );
      } else if (e.code == 'wrong-password') {
        print(e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong password provided for that user.', style: TextStyle(color: Colors.red),)),
        );
      } else if (e.code == 'invalid-email') {
        print(e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The email address is not valid.', style: TextStyle(color: Colors.red),)),
        );
      } else {
        print(e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unknown error occurred.', style: TextStyle(color: Colors.red),)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),

              // logo
              const Icon(Icons.lock, size: 100, color: Colors.green),

              const SizedBox(height: 50),

              Text(
                'Welcome back you\'ve been missed!',
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),

              const SizedBox(height: 25),

              // email textfield
              MyTextField(
                // Key: Key('email'),
                controller: usernameController,
                hintText: 'Email',
                obscureText: false,
              ),

              const SizedBox(height: 10),

              // password textfield
              MyTextField(
                // Key: Key('password'),
                controller: passwordController,
                hintText: 'Password',
                obscureText: true,
              ),

              const SizedBox(height: 50),
              MyButton(onTap: _signIn),
            ],
          ),
        ),
      ),
    );
  }
}