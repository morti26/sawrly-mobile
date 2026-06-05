import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import 'creator_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // Safety check, though ProtectedScreen handles this.
    if (!auth.isAuthenticated) {
      return const Center(child: CircularProgressIndicator()); 
    }

    // 2. Authenticated -> Show Profile
    // Safe to access auth.currentUser! because isAuthenticated is true
    final user = auth.currentUser!;

    // For now, we use the same rich profile layout for both Clients and Creators
    // as per the requirement to match the specific design with Cover/Avatar/Tabs.
    return CreatorProfileScreen(user: user);
  }
}
