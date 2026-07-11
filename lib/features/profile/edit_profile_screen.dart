import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/media_service.dart';
import '../../models/user.dart';
import '../../core/auth/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _countryController;
  late TextEditingController _cityController;
  String _gender = "Male";
  File? _newProfileImage;
  File? _newCoverImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio ?? "");
    _countryController = TextEditingController(text: widget.user.country ?? "");
    _cityController = TextEditingController(text: widget.user.city ?? "");
    _gender = widget.user.gender ?? "Male";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final file = await context.read<MediaService>().pickImage();
    if (file != null) {
      setState(() => _newProfileImage = file);
    }
  }

  Future<void> _pickCoverImage() async {
    final file = await context.read<MediaService>().pickImage();
    if (file != null) {
      setState(() => _newCoverImage = file);
    }
  }

  Future<void> _saveProfile() async {
    debugPrint("EditProfileScreen: Save pressed!");
    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mediaService = context.read<MediaService>();
    final authService = context.read<AuthService>();

    String? avatarUrl = widget.user.avatarUrl;
    String? coverUrl = widget.user.coverImageUrl;

    try {
      if (_newProfileImage != null) {
        final uploadedUrl = await mediaService.uploadFile(_newProfileImage!);
        if (uploadedUrl == null) {
          throw Exception("Failed to upload profile image");
        }
        avatarUrl = uploadedUrl;
      }

      if (_newCoverImage != null) {
        final uploadedUrl = await mediaService.uploadFile(_newCoverImage!);
        if (uploadedUrl == null) {
          throw Exception("Failed to upload cover image");
        }
        coverUrl = uploadedUrl;
      }

      final success = await authService.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        gender: _gender,
        avatarUrl: avatarUrl,
        coverImageUrl: coverUrl,
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
      );

      if (success && mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text("تم تحديث الملف الشخصي بنجاح!")),
        );
      } else if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(authService.error ?? "Update failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("$e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161921),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF161921),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("تعديل الملف الشخصي",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("حفظ",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          children: [
            _buildMediaSection(),
            const SizedBox(height: 16),
            _buildSectionCard(
              children: [
                _buildTextFieldTile(
                  label: "الاسم",
                  controller: _nameController,
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                ),
                _buildTextFieldTile(
                  label: "الدولة",
                  controller: _countryController,
                  icon: Icons.public_rounded,
                  textInputAction: TextInputAction.next,
                ),
                _buildTextFieldTile(
                  label: "المدينة",
                  controller: _cityController,
                  icon: Icons.location_city_outlined,
                  textInputAction: TextInputAction.next,
                ),
                _buildGenderTile(),
                _buildTextFieldTile(
                  label: "نبذة / توقيع",
                  controller: _bioController,
                  icon: Icons.edit_note_rounded,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final authService = context.read<AuthService>();
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تسجيل الخروج'),
                      content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'خروج',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authService.logout();
                    if (!mounted) return;
                    navigator.popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return _buildSectionCard(
      children: [
        _buildImageTile(
          title: "صورة الغلاف",
          subtitle: "اضغط لتغيير الغلاف",
          onTap: _pickCoverImage,
          preview: _buildCoverPreview(),
        ),
        _buildImageTile(
          title: "صورة الملف الشخصي",
          subtitle: "اضغط لتغيير الصورة",
          onTap: _pickProfileImage,
          preview: _buildAvatarPreview(),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildImageTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Widget preview,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              preview,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPreview() {
    final imageProvider = _newCoverImage != null
        ? FileImage(_newCoverImage!)
        : _buildNetworkImage(widget.user.coverImageUrl);

    return Container(
      width: 108,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(14),
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: imageProvider == null
          ? const Icon(Icons.image_outlined, color: Colors.white54)
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
            ),
    );
  }

  Widget _buildAvatarPreview() {
    final imageProvider = _newProfileImage != null
        ? FileImage(_newProfileImage!)
        : _buildNetworkImage(widget.user.avatarUrl);

    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A3040),
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: imageProvider == null
              ? const Icon(Icons.person_outline, color: Colors.white54)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF11131C),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider? _buildNetworkImage(String? rawUrl) {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    final normalized =
        url.startsWith('/') ? "https://sawrly.com$url" : url;
    return NetworkImage(normalized);
  }

  Widget _buildTextFieldTile({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment:
              maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: maxLines,
                minLines: maxLines > 1 ? maxLines : 1,
                textAlign: TextAlign.right,
                textInputAction: textInputAction,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: label,
                  hintStyle: const TextStyle(color: Colors.white38),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 78,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.wc_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gender,
                    dropdownColor: const Color(0xFF232938),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: const [
                      DropdownMenuItem(value: "Male", child: Text("ذكر")),
                      DropdownMenuItem(value: "Female", child: Text("أنثى")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _gender = val);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 78,
              child: Text(
                "الجنس",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
