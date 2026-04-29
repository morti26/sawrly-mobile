import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/creator_status.dart';

class CreatorStatusRow extends StatelessWidget {
  final List<CreatorStatus> statusList;
  final bool showAddButton;
  final VoidCallback? onAddPressed;
  final VoidCallback? onMyStoryLongPress;
  final void Function(List<CreatorStatus> statuses) onStatusPressed;
  final String? userImage;
  final CreatorStatus? myStatus;

  const CreatorStatusRow({
    super.key,
    required this.statusList,
    this.showAddButton = false,
    this.onAddPressed,
    this.onMyStoryLongPress,
    required this.onStatusPressed,
    this.userImage,
    this.myStatus,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<CreatorStatus>> grouped = <String, List<CreatorStatus>>{};
    for (final status in statusList) {
      grouped.putIfAbsent(status.creatorId, () => <CreatorStatus>[]).add(status);
    }

    final List<List<CreatorStatus>> groups = grouped.values.toList()
      ..sort((a, b) {
        final aLatest = a.map((e) => e.createdAt).reduce((x, y) => x.isAfter(y) ? x : y);
        final bLatest = b.map((e) => e.createdAt).reduce((x, y) => x.isAfter(y) ? x : y);
        return bLatest.compareTo(aLatest);
      });

    final totalCount = groups.length + (showAddButton ? 1 : 0);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (showAddButton && index == 0) {
            return GestureDetector(
              onTap: onAddPressed,
              child: _buildAddStatusItem(context),
            );
          }

          // If we have the add button, the status list is shifted by 1
          final listIndex = showAddButton ? index - 1 : index;
          final statuses = List<CreatorStatus>.from(groups[listIndex])
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final status = statuses.isNotEmpty ? statuses.last : null;
          if (status == null) {
            return const SizedBox.shrink();
          }

          return GestureDetector(
            onTap: () => onStatusPressed(statuses),
            onLongPress: myStatus != null && status.creatorId == myStatus!.creatorId
                ? onMyStoryLongPress
                : null,
            child: _buildStatusItem(context, status),
          );
        },
      ),
    );
  }

  Widget _buildStoryAvatar(
    BuildContext context,
    CreatorStatus status,
  ) {
    final imagePreview =
        status.mediaType == 'image' && (status.imageUrl?.isNotEmpty ?? false)
            ? status.imageUrl!
            : '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (status.mediaType == 'video' &&
            (status.videoUrl?.isNotEmpty ??
                status.imageUrl?.isNotEmpty ??
                false))
          const _VideoStoryAvatar()
        else
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2A2D38),
            backgroundImage:
                imagePreview.isNotEmpty ? NetworkImage(imagePreview) : null,
            child: imagePreview.isEmpty
                ? const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 28,
                  )
                : null,
          ),
        if (status.mediaType == 'video')
          Positioned(
            bottom: -1,
            left: -1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddStatusItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      userImage ?? "https://via.placeholder.com/150",
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                      ),
                      child:
                          const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, CreatorStatus status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2), // Space for gradient border
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Gradient ring if active status
              gradient: status.hasStory
                  ? const LinearGradient(colors: [Colors.purple, Colors.orange])
                  : null,
              color: status.hasStory
                  ? null
                  : Colors.transparent, // transparent if no story
            ),
            child: Container(
              padding: const EdgeInsets.all(
                  2), // White space between boarder and image
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Stack(
                children: [
                  _buildStoryAvatar(context, status),
                  if (status.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // No text under circles as per requirements?
          // Docs said "no text under circles" but typically names are useful.
          // Requirements check: "No text under circles" - adhering strictly.
          // Leaving text here but making it empty or removing to follow strict rules.
          // "No text under circles" -> Removing name.
        ],
      ),
    );
  }
}

class _VideoStoryAvatar extends StatefulWidget {
  const _VideoStoryAvatar();

  @override
  State<_VideoStoryAvatar> createState() => _VideoStoryAvatarState();
}

class _VideoStoryAvatarState extends State<_VideoStoryAvatar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipOval(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B2233), Color(0xFF2A2D38)],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white70,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
