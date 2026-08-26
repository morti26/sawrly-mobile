import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import 'login_sheet.dart';
import '../../core/localization/app_locale_service.dart';
import '../../core/localization/app_strings.dart';

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
    context.watch<AppLocaleService>();
    final localizedTitle = switch (title) {
      'حجوزاتي' => AppStrings.bookings,
      'البروفايل' => AppStrings.profile,
      _ => tr(title, title),
    };

    if (auth.isAuthenticated) {
      return child;
    }

    // Not authenticated -> Show Login Prompt
    return Scaffold(
      appBar: AppBar(title: Text(localizedTitle)),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                tr('يجب تسجيل الدخول', 'Please log in'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                child: Text(
                  tr('يرجى تسجيل الدخول أو إنشاء حساب جديد للوصول إلى هذه الصفحة', 'Please log in or create an account to access this page'),
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
                child: Text(tr('دخول / تسجيل جديد', 'Log in / Register')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
