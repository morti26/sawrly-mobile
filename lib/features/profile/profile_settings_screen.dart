import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme_service.dart';
import '../../models/user.dart';
import 'edit_profile_screen.dart';
import 'creator_subscription_screen.dart';
import 'privacy_security_screen.dart';
import 'creator_wallet_screen.dart';
import '../../core/localization/app_locale_service.dart';
import '../../core/localization/app_strings.dart';

class ProfileSettingsScreen extends StatelessWidget {
  final User user;

  const ProfileSettingsScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    final locale = context.watch<AppLocaleService>();
    final colors = theme.colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          AppStrings.settings,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeaderCard(context, colors, theme.config),
              const SizedBox(height: 20),
              _buildSectionTitle(colors, AppStrings.profileSection),
              const SizedBox(height: 8),
              _buildCard(
                colors,
                children: [
                  _buildTile(
                    colors,
                    icon: Icons.visibility_outlined,
                    title: tr('عرض الملف الشخصي', 'View profile'),
                    subtitle:
                        tr('العودة إلى صفحة الملف الشخصي', 'Back to profile'),
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
                    title: AppStrings.editProfile,
                    subtitle: AppStrings.editProfileSubtitle,
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
              _buildSectionTitle(colors, AppStrings.account),
              const SizedBox(height: 8),
              _buildCard(
                colors,
                children: [
                  _buildTile(
                    colors,
                    icon: Icons.notifications_outlined,
                    title: AppStrings.notifications,
                    subtitle: AppStrings.soon,
                    onTap: null,
                    trailing: _buildSoonBadge(colors),
                    disabled: true,
                  ),
                  _buildDivider(colors),
                  if (user.role == UserRole.creator)
                    _buildTile(
                      colors,
                      icon: Icons.workspace_premium_outlined,
                      title: AppStrings.subscription,
                      subtitle: AppStrings.subscriptionSubtitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatorSubscriptionScreen(),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                    ),
                  if (user.role == UserRole.creator) _buildDivider(colors),
                  if (user.role == UserRole.creator)
                    _buildTile(
                      colors,
                      icon: Icons.account_balance_wallet_outlined,
                      title: AppStrings.wallet,
                      subtitle: AppStrings.walletSubtitle,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatorWalletScreen(),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_left_rounded),
                    ),
                  _buildDivider(colors),
                  _buildTile(
                    colors,
                    icon: Icons.privacy_tip_outlined,
                    title: AppStrings.privacy,
                    subtitle: AppStrings.privacySubtitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacySecurityScreen(),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                  ),
                  _buildDivider(colors),
                  _buildTile(
                    colors,
                    icon: Icons.language_outlined,
                    title: AppStrings.language,
                    subtitle: locale.isEnglish
                        ? AppStrings.english
                        : AppStrings.arabic,
                    onTap: () => _showLanguageDialog(context),
                    trailing: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildLogoutButton(context, colors),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final locale = context.read<AppLocaleService>();
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.language),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppLanguage>(
              value: AppLanguage.arabic,
              groupValue: locale.language,
              title: Text(AppStrings.arabic),
              onChanged: (value) => Navigator.pop(dialogContext, value),
            ),
            RadioListTile<AppLanguage>(
              value: AppLanguage.english,
              groupValue: locale.language,
              title: Text(AppStrings.english),
              onChanged: (value) => Navigator.pop(dialogContext, value),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await locale.setLanguage(selected);
    }
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
                    user.role == UserRole.creator
                        ? AppStrings.creatorAccount
                        : AppStrings.clientAccount,
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
    if (icon == Icons.visibility_outlined) return const SizedBox.shrink();
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
        AppStrings.soon,
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
                AppStrings.logout,
                style: TextStyle(color: colors.textPrimary),
              ),
              content: Text(
                AppStrings.logoutQuestion,
                style: TextStyle(color: colors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    AppStrings.cancel,
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    AppStrings.exit,
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
          AppStrings.logout,
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
