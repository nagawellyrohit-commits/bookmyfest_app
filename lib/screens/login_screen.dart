import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import 'dashboard_screen.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                const Icon(Icons.school, size: 100),

                const SizedBox(height: 20),

                const Text(
                  "Student App",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                CustomTextField(controller: emailController, label: "Email"),

                const SizedBox(height: 20),

                CustomTextField(
                  controller: passwordController,
                  label: "Password",
                ),

                const SizedBox(height: 30),

                CustomButton(
                  text: "Login",
                  onPressed: () {
                    Provider.of<UserProvider>(
                      context,
                      listen: false,
                    ).setUsername(emailController.text);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
