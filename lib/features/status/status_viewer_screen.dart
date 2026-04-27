import 'package:flutter/material.dart';

class StatusViewerScreen extends StatelessWidget {
  const StatusViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Status Content (Mocked)
            Center(
              child: Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: Text(
                    "Video/Image Content Here",
                    style: TextStyle(color: Colors.white),
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
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Use Info
            const Positioned(
              top: 30,
              left: 16,
              child: Row(
                children: [
                   CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://i.pravatar.cc/150')),
                   SizedBox(width: 8),
                   Text("Creator Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   SizedBox(width: 8),
                   Text("2h ago", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            // Close
            Positioned(
              top: 30,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
