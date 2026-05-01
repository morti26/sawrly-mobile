import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../search/global_search_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/protected_screen.dart';
import '../orders/orders_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // body extends under the floating nav bar
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  Widget _buildFloatingNavBar() {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 22, bottom: 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          // Dark semi-transparent background
          color: const Color(0xFF1A1D27).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(14),
          // Soft shadow below
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
            // Subtle purple glow from below
            BoxShadow(
              color: const Color(0xFF7A3EED).withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          // Very subtle border
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_icons.length, _buildNavItem),
        ),
      ),
    ),   // close Padding
    );  // close SafeArea
  }

  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: SizedBox(
        width: 52,
        height: 64,
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
        // Very subtle purple fill
        color: const Color(0xFF7A3EED).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        // Purple border
        border: Border.all(
          color: const Color(0xFF9B59F5).withValues(alpha: 0.55),
          width: 1.3,
        ),
        // Neon purple glow (inner tight + outer wide)
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7A3EED).withValues(alpha: 0.55),
            blurRadius: 16,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF9B59F5).withValues(alpha: 0.20),
            blurRadius: 32,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(
        _icons[index],
        color: const Color(0xFFBC83FF), // bright purple icon
        size: 21,
      ),
    );
  }

  Widget _buildInactiveIcon(int index) {
    return Icon(
      _icons[index],
      color: Colors.white.withValues(alpha: 0.55),
      size: 22,
    );
  }
}
