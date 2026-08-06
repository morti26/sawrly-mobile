import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme_service.dart';
import '../../models/user.dart';
import 'edit_profile_screen.dart';

class ProfileSettingsScreen extends StatelessWidget {
  final User user;

  const ProfileSettingsScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          'الإعدادات',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeaderCard(context, colors, config),
            const SizedBox(height: 20),
            _buildSectionTitle(colors, 'الملف الشخصي'),
            const SizedBox(height: 8),
            _buildCard(
              colors,
              children: [
                _buildTile(
                  colors,
                  icon: Icons.visibility_outlined,
                  title: 'عرض الملف الشخصي',
                  subtitle: 'العودة إلى صفحة الملف الشخصي',
                  onTap: () => Navigator.pop(context),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
                _buildDivider(colors),
                _buildTile(
                  colors,
                  icon: Icons.edit_outlined,
                  title: 'تعديل الملف الشخصي',
                  subtitle: 'الاسم، الصورة، النبذة، الخدمة، إلخ',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(user: user),
                      ),
                    );
                  },
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionTitle(colors, 'الحساب'),
            const SizedBox(height: 8),
            _buildCard(
              colors,
              children: [
                _buildTile(
                  colors,
                  icon: Icons.notifications_outlined,
                  title: 'الإشعارات',
                  subtitle: 'قريباً',
                  onTap: null,
                  trailing: _buildSoonBadge(colors),
                  disabled: true,
                ),
                _buildDivider(colors),
                _buildTile(
                  colors,
                  icon: Icons.payment_outlined,
                  title: 'الدفع والمحفظة',
                  subtitle: 'قريباً',
                  onTap: null,
                  trailing: _buildSoonBadge(colors),
                  disabled: true,
                ),
                _buildDivider(colors),
                _buildTile(
                  colors,
                  icon: Icons.privacy_tip_outlined,
                  title: 'الخصوصية والأمان',
                  subtitle: 'قريباً',
                  onTap: null,
                  trailing: _buildSoonBadge(colors),
                  disabled: true,
                ),
                _buildDivider(colors),
                _buildTile(
                  colors,
                  icon: Icons.language_outlined,
                  title: 'اللغة',
                  subtitle: 'قريباً',
                  onTap: null,
                  trailing: _buildSoonBadge(colors),
                  disabled: true,
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildLogoutButton(context, colors),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(
      BuildContext context, dynamic colors, dynamic config) {
    final gradient = config.effects.primaryGradient(
      colors.primary,
      colors.primaryDark,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.textPrimary.withValues(alpha: 0.35),
                width: 2,
              ),
              image: (user.avatarUrl?.trim().isNotEmpty ?? false)
                  ? DecorationImage(
                      image: NetworkImage(user.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: colors.surface,
            ),
            child: (user.avatarUrl?.trim().isNotEmpty ?? false)
                ? null
                : Center(
                    child: Text(
                      (user.name.trim().isNotEmpty
                              ? user.name.trim()[0].toUpperCase()
                              : '?'),
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.trim().isEmpty ? '—' : user.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.textPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user.role == UserRole.creator ? 'حساب منشئ' : 'حساب عميل',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(dynamic colors, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCard(dynamic colors, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.textPrimary.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildTile(
    dynamic colors, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool disabled = false,
  }) {
    final bg = disabled ? colors.background : Colors.transparent;
    final fg = disabled ? colors.textSecondary : colors.textPrimary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: disabled
                      ? null
                      : LinearGradient(
                          colors: [
                            colors.primary.withValues(alpha: 0.14),
                            colors.primaryDark.withValues(alpha: 0.14),
                          ],
                        ),
                  color: disabled
                      ? colors.textPrimary.withValues(alpha: 0.05)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(dynamic colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colors.textPrimary.withValues(alpha: 0.06),
      ),
    );
  }

  Widget _buildSoonBadge(dynamic colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'قريباً',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, dynamic colors) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final authService = context.read<AuthService>();
          final navigator = Navigator.of(context);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: colors.surface,
              title: Text(
                'تسجيل الخروج',
                style: TextStyle(color: colors.textPrimary),
              ),
              content: Text(
                'هل أنت متأكد أنك تريد تسجيل الخروج؟',
                style: TextStyle(color: colors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'خروج',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await authService.logout();
            if (!context.mounted) return;
            navigator.popUntil((route) => route.isFirst);
          }
        },
        icon: Icon(Icons.logout, color: colors.error),
        label: Text(
          'تسجيل الخروج',
          style: TextStyle(color: colors.error, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
