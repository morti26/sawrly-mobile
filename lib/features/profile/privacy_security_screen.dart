import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_locale_service.dart';
import '../../core/network/api_client.dart';
import '../../core/services/media_service.dart';
import '../../core/theme/app_theme_service.dart';

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
  bool _isSubmitting = false;
  String? _submissionMessage;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _captureDocument(bool identity) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
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
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || file == null) return;
    setState(() => _selfie = File(file.path));
  }

  Future<void> _submitDocuments() async {
    final documents = <({String type, File file})>[
      if (_identityDocument != null)
        (type: 'identity_document', file: _identityDocument!),
      if (_addressProof != null) (type: 'address_proof', file: _addressProof!),
      if (_selfie != null) (type: 'selfie', file: _selfie!),
    ];

    if (documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('التقط صورة واحدة على الأقل أولاً',
                'Capture at least one image first'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionMessage = null;
    });

    try {
      final mediaService = context.read<MediaService>();
      final apiClient = context.read<ApiClient>();
      for (final document in documents) {
        final fileUrl = await mediaService.uploadFile(
          document.file,
          subDir: 'identity-verification',
        );
        if (fileUrl == null || fileUrl.trim().isEmpty) {
          throw Exception(mediaService.lastUploadError ??
              tr('فشل رفع الصورة', 'Image upload failed'));
        }
        await apiClient.client.post('/identity-verifications', data: {
          'documentType': document.type,
          'fileUrl': fileUrl,
        });
      }

      if (!mounted) return;
      setState(() => _submissionMessage = tr(
          'تم حفظ الصور وإرسالها إلى الإدارة للمراجعة',
          'Images saved and sent to admin for review'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submissionMessage!)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submissionMessage = tr('تعذر إرسال الصور. حاول مرة أخرى.',
          'Could not send the images. Please try again.'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_submissionMessage!)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _uploadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    File? file,
  }) {
    final colors = context.read<AppThemeService>().colors;
    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(
        file == null ? subtitle : tr('تم التقاط الصورة', 'Image captured'),
      ),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    );
  }

  Widget _imageDropdown(File file) {
    final colors = context.read<AppThemeService>().colors;
    return ExpansionTile(
      initiallyExpanded: true,
      leading: Icon(Icons.image_outlined, color: colors.primary),
      title: Text(tr('عرض الصورة المحفوظة', 'View saved image')),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
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
        centerTitle: true,
      ),
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
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: tr('البريد الإلكتروني', 'Email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {},
              child: Text(tr(
                  'حفظ وإرسال رمز التحقق', 'Save and send verification code')),
            ),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  _uploadTile(
                    title: tr('بطاقة الهوية أو جواز السفر',
                        'National ID or passport'),
                    subtitle: tr('التقط صورة واضحة للوثيقة بالكاميرا',
                        'Capture a clear document image with the camera'),
                    icon: Icons.badge_outlined,
                    onTap: () => _captureDocument(true),
                    file: _identityDocument,
                  ),
                  if (_identityDocument != null)
                    _imageDropdown(_identityDocument!),
                  const Divider(height: 1),
                  _uploadTile(
                    title: tr(
                        'إثبات السكن أو العنوان', 'Address or residence proof'),
                    subtitle: tr('التقط إثبات العنوان بالكاميرا',
                        'Capture address proof with the camera'),
                    icon: Icons.home_work_outlined,
                    onTap: () => _captureDocument(false),
                    file: _addressProof,
                  ),
                  if (_addressProof != null) _imageDropdown(_addressProof!),
                  const Divider(height: 1),
                  _uploadTile(
                    title:
                        tr('صورة التحقق بالكاميرا', 'Camera identity selfie'),
                    subtitle: tr('التقط صورة شخصية مباشرة من الكاميرا',
                        'Take a selfie directly with the camera'),
                    icon: Icons.camera_alt_outlined,
                    onTap: _takeSelfie,
                    file: _selfie,
                  ),
                  if (_selfie != null) _imageDropdown(_selfie!),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitDocuments,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(tr('حفظ وإرسال الصور إلى الإدارة',
                  'Save and send images to admin')),
            ),
            if (_submissionMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _submissionMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              tr('بعد الإرسال، يراجع admin المستندات والصورة يدوياً',
                  'After submission, an admin manually reviews the documents and selfie.'),
              style: TextStyle(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
