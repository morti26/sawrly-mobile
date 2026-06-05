import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';

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
                'إنشاء حساب جديد',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'الرجاء إدخال الاسم' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني';
                  }
                  if (!value.contains('@')) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) => value?.isEmpty ?? true
                    ? 'الرجاء إدخال كلمة المرور'
                    : null,
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('تسجيل كصانع محتوى'),
                subtitle:
                    const Text('حدد هذا الخيار إذا كنت تريد تقديم خدماتك داخل التطبيق'),
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
                    : const Text('تسجيل حساب'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
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
        const SnackBar(
          content: Text('الرجاء التحقق من الحقول المطلوبة'),
          backgroundColor: Colors.orange,
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
        const SnackBar(content: Text('تم إنشاء الحساب بنجاح')),
      );
      return;
    }

    debugPrint('Registration failed: ${authService.error}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authService.error ?? 'فشل إنشاء الحساب'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
