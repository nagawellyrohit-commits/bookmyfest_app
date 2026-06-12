import 'package:flutter/material.dart';

class CustomTextField
    extends StatelessWidget {

  final TextEditingController controller;
  final String label;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {

    return TextFormField(
      controller: controller,
      obscureText: obscureText,

      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }
}