import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:provider/provider.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/theme/app_theme_service.dart';
import '../../../core/localization/app_locale_service.dart';
import 'offer_card.dart';

class OfferSectionView extends StatelessWidget {
  final String title;
  final List<Offer> offers;
  final VoidCallback? onSeeAll;
  final bool showEngagementStats;
  final bool showDiscountBadge;

  const OfferSectionView({
    super.key,
    required this.title,
    required this.offers,
    this.onSeeAll,
    this.showEngagementStats = false,
    this.showDiscountBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    context.watch<AppLocaleService>();
    final premium = PremiumDesignTokens.from(theme.config);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.43).clamp(152.0, 182.0).toDouble();
    final imageHeight = (cardWidth * .54).clamp(82.0, 98.0).toDouble();
    const sectionHeight = 250.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: premium.textPrimary,
                  letterSpacing: -.15,
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: premium.accentWarm,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onSeeAll,
                  child: Text(
                    tr('المزيد', 'More'),
                    style: TextStyle(color: premium.accentWarm),
                  ), // Arabic "More"
                )
            ],
          ),
        ),

        // List
        SizedBox(
          height: sectionHeight,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
              scrollDirection: Axis.horizontal,
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return OfferCard(
                  offer: offers[index],
                  cardWidth: cardWidth,
                  imageHeight: imageHeight,
                  showEngagementStats: showEngagementStats,
                  showDiscountBadge: showDiscountBadge,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
