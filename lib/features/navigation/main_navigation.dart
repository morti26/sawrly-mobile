import 'package:flutter/material.dart';
import '../../core/design/design_tokens.dart';
import '../home/home_screen.dart';
import '../search/global_search_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/protected_screen.dart';
import '../orders/orders_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GlobalSearchScreen(),
    const CategoriesScreen(),
    const ProtectedScreen(
      title: 'حجوزاتي',
      child: OrdersScreen(),
    ),
    const ProtectedScreen(
      title: 'البروفايل',
      child: ProfileScreen(),
    ),
  ];

  // Icons matching the reference image exactly
  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.search_rounded,
    Icons.grid_view_rounded,
    Icons.shopping_bag_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // body extends under the floating nav bar
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  Widget _buildFloatingNavBar() {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 22, bottom: 16),
        child: RepaintBoundary(
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Material(
              color: AppColors.background.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_icons.length, _buildNavItem),
                ),
              ),
            ),
          ),
        ),
      ),
    );  // close SafeArea
  }

  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    return SizedBox(
      width: 56,
      height: 64,
      child: InkWell(
        onTap: () {
          if (_currentIndex == index) {
            return;
          }
          setState(() => _currentIndex = index);
        },
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: isActive ? _buildActiveIcon(index) : _buildInactiveIcon(index),
        ),
      ),
    );
  }

  Widget _buildActiveIcon(int index) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.55),
          width: 1.3,
        ),
        boxShadow: AppShadows.glowPrimary,
      ),
      child: Icon(
        _icons[index],
        color: AppColors.primaryLight,
        size: 21,
      ),
    );
  }

  Widget _buildInactiveIcon(int index) {
    return Icon(
      _icons[index],
      color: AppColors.textPrimary.withValues(alpha: 0.55),
      size: 22,
    );
  }
}
