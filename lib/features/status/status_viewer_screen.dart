import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme_service.dart';

class StatusViewerScreen extends StatelessWidget {
  const StatusViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Status Content (Mocked)
            Center(
              child: Container(
                color: colors.surface,
                child: Center(
                  child: Text(
                    "Video/Image Content Here",
                    style: TextStyle(color: colors.textPrimary),
                  ),
                ),
              ),
            ),

            // Progress Bar
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.5,
                      backgroundColor: Colors.grey.withValues(alpha: 0.5),
                      color: colors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // Use Info
            Positioned(
              top: 30,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          NetworkImage('https://i.pravatar.cc/150')),
                  SizedBox(width: 8),
                  Text("Creator Name",
                      style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Text("2h ago", style: TextStyle(color: colors.textSecondary)),
                ],
              ),
            ),

            // Close
            Positioned(
              top: 30,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: colors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
