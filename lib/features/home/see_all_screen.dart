import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'widgets/offer_card.dart';
import '../../core/theme/app_theme_service.dart';
import 'package:provider/provider.dart';

class SeeAllScreen extends StatelessWidget {
  final String title;
  final List<Offer> offers;

  const SeeAllScreen({
    super.key,
    required this.title,
    required this.offers,
  });

  @override
  Widget build(BuildContext context) {
    final showDiscountBadge = title == 'الخصومات';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.watch<AppThemeService>().colors.background,
        elevation: 0,
        foregroundColor: context.watch<AppThemeService>().colors.textPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // Adjust based on card design
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            return OfferCard(
              offer: offers[index],
              showDiscountBadge: showDiscountBadge,
            );
          },
        ),
      ),
    );
  }
}
