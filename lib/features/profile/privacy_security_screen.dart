import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/localization/app_locale_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _picker = ImagePicker();
  File? _identityDocument;
  File? _addressProof;
  File? _selfie;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(bool identity) async {
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (!mounted || file == null) return;
    setState(() {
      if (identity) {
        _identityDocument = File(file.path);
      } else {
        _addressProof = File(file.path);
      }
    });
  }

  Future<void> _takeSelfie() async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (!mounted || file == null) return;
    setState(() => _selfie = File(file.path));
  }

  Widget _uploadTile(
      {required String title,
      required String subtitle,
      required IconData icon,
      required VoidCallback onTap,
      File? file}) {
    final colors = context.read<AppThemeService>().colors;
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(
          file == null ? subtitle : tr('تم اختيار الملف', 'File selected')),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    context.watch<AppLocaleService>();
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
          title: Text(tr('الخصوصية والأمان', 'Privacy & security')),
          centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: tr('رقم الهاتف', 'Phone number'),
                    prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: tr('البريد الإلكتروني', 'Email'),
                    prefixIcon: const Icon(Icons.email_outlined))),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () {},
                child: Text(tr('حفظ وإرسال رمز التحقق',
                    'Save and send verification code'))),
            const SizedBox(height: 20),
            Card(
                child: Column(children: [
              _uploadTile(
                  title: tr(
                      'بطاقة الهوية أو جواز السفر', 'National ID or passport'),
                  subtitle: tr('رفع صورة واضحة للوثيقة',
                      'Upload a clear document image'),
                  icon: Icons.badge_outlined,
                  onTap: () => _pickDocument(true),
                  file: _identityDocument),
              const Divider(height: 1),
              _uploadTile(
                  title: tr(
                      'إثبات السكن أو العنوان', 'Address or residence proof'),
                  subtitle: tr('رفع بطاقة العنوان أو مستند رسمي',
                      'Upload an address card or official document'),
                  icon: Icons.home_work_outlined,
                  onTap: () => _pickDocument(false),
                  file: _addressProof),
              const Divider(height: 1),
              _uploadTile(
                  title: tr('صورة التحقق بالكاميرا', 'Camera identity selfie'),
                  subtitle: tr('التقط صورة شخصية مباشرة من الكاميرا',
                      'Take a selfie directly with the camera'),
                  icon: Icons.camera_alt_outlined,
                  onTap: _takeSelfie,
                  file: _selfie),
            ])),
            const SizedBox(height: 12),
            Text(
                tr('بعد الإرسال، يراجع admin المستندات والصورة يدويًا',
                    'After submission, an admin manually reviews the documents and selfie.'),
                style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
