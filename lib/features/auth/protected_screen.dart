import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import 'login_sheet.dart';

class ProtectedScreen extends StatelessWidget {
  final Widget child;
  final String title; // Title for the AppBar when showing login prompt

  const ProtectedScreen({
    super.key, 
    required this.child,
    this.title = 'دخول', // Login
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.isAuthenticated) {
      return child;
    }

    // Not authenticated -> Show Login Prompt
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'يجب تسجيل الدخول', // Must login
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                child: Text(
                  'يرجى تسجيل الدخول أو إنشاء حساب جديد للوصول إلى هذه الصفحة', // Please login or register to access this page
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              // We embed the form logic or trigger the sheet.
              // Triggering the sheet is better for consistency, but here we want an inline button.
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const LoginSheet(),
                  );
                },
                child: const Text('دخول / تسجيل جديد'), // Login / New Register
              ),
            ],
          ),
        ),
      ),
    );
  }
}
