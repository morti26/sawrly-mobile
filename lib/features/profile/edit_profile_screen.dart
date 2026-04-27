import 'dart:io';
import 'package:flutter/material.dart';
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
  String _gender = "Male";
  File? _newProfileImage;
  File? _newCoverImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio ?? "");
    _gender = widget.user.gender ?? "Male";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
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

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161921),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("تعديل الملف الشخصي",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    debugPrint("EditProfileScreen: Save pressed!");
                    setState(() => _isSaving = true);

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final mediaService = context.read<MediaService>();

                    String? avatarUrl = widget.user.avatarUrl;
                    String? coverUrl = widget.user.coverImageUrl;

                    try {
                      if (_newProfileImage != null) {
                        debugPrint(
                            "EditProfileScreen: Uploading new profile image...");
                        final uploadedUrl =
                            await mediaService.uploadFile(_newProfileImage!);
                        if (uploadedUrl == null) {
                          throw Exception("Failed to upload profile image");
                        }
                        avatarUrl = uploadedUrl;
                        debugPrint(
                            "EditProfileScreen: Profile image uploaded: $avatarUrl");
                      }
                      if (_newCoverImage != null) {
                        debugPrint(
                            "EditProfileScreen: Uploading new cover image...");
                        final uploadedUrl =
                            await mediaService.uploadFile(_newCoverImage!);
                        if (uploadedUrl == null) {
                          throw Exception("Failed to upload cover image");
                        }
                        coverUrl = uploadedUrl;
                        debugPrint(
                            "EditProfileScreen: Cover image uploaded: $coverUrl");
                      }

                      debugPrint("EditProfileScreen: Calling updateProfile...");
                      final success = await authService.updateProfile(
                        name: _nameController.text,
                        bio: _bioController.text,
                        gender: _gender,
                        avatarUrl: avatarUrl,
                        coverImageUrl: coverUrl,
                      );

                      if (success && mounted) {
                        debugPrint(
                            "EditProfileScreen: Profile updated successfully!");
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text("تم تحديث الملف الشخصي بنجاح!")),
                        );
                      } else {
                        debugPrint(
                            "EditProfileScreen: Profile update failed (success=false)");
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                                content:
                                    Text(authService.error ?? "Update failed")),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint("EditProfileScreen: Save Error: $e");
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text("$e")),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text("حفظ",
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header for Cover Image
            _buildCoverSection(),
            const Divider(height: 1),
            // Header for Profile Image
            _buildAvatarSection(),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // Fields - using Directionality to mimic RTL layout if desired,
            // but standard LTR: Label Left, Input Right usually.
            // Screenshot has Label Right. Let's try to match screenshot layout logic:
            // Row(Expanded(TextField), Text(Label))

            _buildFieldRow("الاسم", _nameController),
            _buildDropdownRow("الجنس"),
            _buildFieldRow("نبذة / توقيع", _bioController, maxLines: 3),

            const SizedBox(height: 50),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Confirm logout
                  final authService = context.read<AuthService>();
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تسجيل الخروج'), // Logout
                      content: const Text(
                          'هل أنت متأكد أنك تريد تسجيل الخروج؟'), // Are you sure you want to logout?
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'), // Cancel
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('خروج',
                              style: TextStyle(color: Colors.red)), // Logout
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
                label: const Text('تسجيل الخروج',
                    style: TextStyle(color: Colors.red)), // Logout
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverSection() {
    return InkWell(
      onTap: _pickCoverImage,
      child: Container(
        height: 120, // Reduced height for list item look
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side: Image preview
            Container(
              width: 100,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: _newCoverImage != null
                    ? DecorationImage(
                        image: FileImage(_newCoverImage!), fit: BoxFit.cover)
                    : widget.user.coverImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(widget.user.coverImageUrl!
                                    .startsWith('/')
                                ? "https://ph.sitely24.com${widget.user.coverImageUrl}"
                                : widget.user.coverImageUrl!),
                            fit: BoxFit.cover)
                        : const DecorationImage(
                            image: NetworkImage(
                                "https://picsum.photos/seed/cover/800/400"),
                            fit: BoxFit.cover),
              ),
              child: const Center(
                  child: Icon(Icons.camera_alt, color: Colors.white54)),
            ),
            const Text("صورة الغلاف",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return InkWell(
      onTap: _pickProfileImage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                    image: _newProfileImage != null
                        ? DecorationImage(
                            image: FileImage(_newProfileImage!),
                            fit: BoxFit.cover)
                        : widget.user.avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(widget.user.avatarUrl!
                                        .startsWith('/')
                                    ? "https://ph.sitely24.com${widget.user.avatarUrl}"
                                    : widget.user.avatarUrl!),
                                fit: BoxFit.cover)
                            : const DecorationImage(
                                image: NetworkImage(
                                    "https://picsum.photos/seed/avatar/200/200"),
                                fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            const Text("صورة الملف الشخصي",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              textAlign: TextAlign.left,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: "أدخل القيمة",
                hintStyle: TextStyle(color: Colors.grey),
              ),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80, // Fixed width for labels to align
            child: Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DropdownButton<String>(
            value: _gender,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: "Male", child: Text("ذكر")),
              DropdownMenuItem(value: "Female", child: Text("أنثى")),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _gender = val);
            },
          ),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
