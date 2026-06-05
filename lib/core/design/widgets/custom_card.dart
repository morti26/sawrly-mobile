import 'package:flutter/material.dart';
import '../design_tokens.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool hasBorder;
  final Color? backgroundColor;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.hasBorder = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: hasBorder
            ? Border.all(color: AppColors.border, width: 1)
            : null,
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final StatusType type;

  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: _getTextColor(),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case StatusType.success:
        return AppColors.successBg;
      case StatusType.warning:
        return AppColors.warningBg;
      case StatusType.error:
        return AppColors.errorBg;
      case StatusType.info:
        return AppColors.infoBg;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.error:
        return AppColors.error;
      case StatusType.info:
        return AppColors.info;
    }
  }
}

enum StatusType { success, warning, error, info }
