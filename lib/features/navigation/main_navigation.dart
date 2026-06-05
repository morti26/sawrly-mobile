import 'package:flutter/material.dart';
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
              boxShadow: const [
                BoxShadow(
                  color: Color(0x8C000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x0F7A3EED),
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Material(
              color: const Color(0xF71A1D27),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x12FFFFFF),
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
        // Very subtle purple fill
        color: const Color(0x1A7A3EED),
        borderRadius: BorderRadius.circular(13),
        // Purple border
        border: Border.all(
          color: const Color(0x8C9B59F5),
          width: 1.3,
        ),
        // Neon purple glow (inner tight + outer wide)
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C7A3EED),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Color(0x339B59F5),
            blurRadius: 18,
            spreadRadius: 3,
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
      color: const Color(0x8CFFFFFF),
      size: 22,
    );
  }
}
