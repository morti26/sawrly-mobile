import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_tokens.dart';
import '../../core/auth/auth_service.dart';
import '../../core/localization/app_locale_service.dart';

class RegisterSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const RegisterSheet({super.key, this.onSuccess});

  @override
  State<RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<RegisterSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreator = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    context.watch<AppLocaleService>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('إنشاء حساب جديد', 'Create a new account'),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: tr('الاسم الكامل', 'Full name'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true
                        ? tr('الرجاء إدخال الاسم', 'Please enter your name')
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: tr('البريد الإلكتروني', 'Email'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return tr('الرجاء إدخال البريد الإلكتروني', 'Please enter your email');
                  }
                  if (!value.contains('@')) {
                    return tr('البريد الإلكتروني غير صحيح', 'Invalid email address');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: tr('كلمة المرور', 'Password'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) => value?.isEmpty ?? true
                    ? tr('الرجاء إدخال كلمة المرور', 'Please enter your password')
                    : null,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.error!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              CheckboxListTile(
                title: Text(tr('تسجيل كصانع محتوى', 'Register as a creator')),
                subtitle: Text(tr(
                    'حدد هذا الخيار إذا كنت تريد تقديم خدماتك داخل التطبيق',
                    'Select this if you want to offer services in the app')),
                value: _isCreator,
                onChanged: (val) {
                  setState(() {
                    _isCreator = val ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: auth.isLoading
                    ? const CircularProgressIndicator()
                    : Text(tr('تسجيل حساب', 'Create account')),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(tr('لديك حساب بالفعل؟ تسجيل الدخول', 'Already have an account? Log in')),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    debugPrint('Register button clicked');

    debugPrint('Validating register form...');
    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('Register form validation failed.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('الرجاء التحقق من الحقول المطلوبة', 'Please check the required fields')),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final authService = context.read<AuthService>();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final role = _isCreator ? 'creator' : 'client';

    debugPrint(
      'Register payload prepared for $email with role $role and password length ${password.length}',
    );

    final success = await authService.register(
      name,
      email,
      password,
      role: role,
    );

    debugPrint('AuthService.register returned: $success');

    if (!mounted) {
      debugPrint('RegisterSheet is no longer mounted after register.');
      return;
    }

    if (success) {
      debugPrint('Registration succeeded.');
      Navigator.pop(context);
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('تم إنشاء الحساب بنجاح', 'Account created successfully'))),
      );
      return;
    }

    debugPrint('Registration failed: ${authService.error}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authService.error ?? tr('فشل إنشاء الحساب', 'Account creation failed')),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
