import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/offer.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.36).clamp(128.0, 160.0).toDouble();
    const imageHeight = 58.0;
    const sectionHeight = 188.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('المزيد',
                      style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFFA726))), // Arabic "More"
                )
            ],
          ),
        ),

        // List
        SizedBox(
          height: sectionHeight,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
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
      ],
    );
  }
}
