import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/creator_status.dart';

class CreatorStatusRow extends StatelessWidget {
  final List<CreatorStatus> statusList;
  final bool showAddButton;
  final VoidCallback? onAddPressed;
  final VoidCallback? onMyStoryLongPress;
  final void Function(List<CreatorStatus> statuses) onStatusPressed;
  final String? userImage;
  final String? myUserName;
  final CreatorStatus? myStatus;

  const CreatorStatusRow({
    super.key,
    required this.statusList,
    this.showAddButton = false,
    this.onAddPressed,
    this.onMyStoryLongPress,
    required this.onStatusPressed,
    this.userImage,
    this.myUserName,
    this.myStatus,
  });

  Widget _networkCircleImage({
    required String url,
    required double radius,
    required Color backgroundColor,
    required Widget fallback,
  }) {
    final safeUrl = Uri.encodeFull(url);
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: Image.network(
          safeUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: backgroundColor,
              child: Center(child: fallback),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: backgroundColor,
              child: Center(child: fallback),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<CreatorStatus>> grouped =
        <String, List<CreatorStatus>>{};
    for (final status in statusList) {
      grouped
          .putIfAbsent(status.creatorId.trim(), () => <CreatorStatus>[])
          .add(status);
    }

    String? myCreatorId = myStatus?.creatorId.trim();
    if ((myCreatorId == null || myCreatorId.isEmpty) &&
        myUserName != null &&
        myUserName!.trim().isNotEmpty) {
      final targetName = myUserName!.trim().toLowerCase();
      for (final entry in grouped.entries) {
        final first = entry.value.isNotEmpty ? entry.value.first : null;
        if (first != null &&
            first.creatorName.trim().toLowerCase() == targetName) {
          myCreatorId = entry.key.trim();
          break;
        }
      }
    }

    final rawMyStatuses = myCreatorId != null ? grouped[myCreatorId] : null;
    final myStatuses = (rawMyStatuses != null && rawMyStatuses.isNotEmpty)
        ? List<CreatorStatus>.from(rawMyStatuses)
        : (myStatus != null ? <CreatorStatus>[myStatus!] : <CreatorStatus>[]);
    myStatuses.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final List<List<CreatorStatus>> groups =
        grouped.entries
            .where((e) => myCreatorId == null || e.key != myCreatorId)
            .map((e) => e.value)
            .toList()
          ..sort((a, b) {
            final aLatest = a
                .map((e) => e.createdAt)
                .reduce((x, y) => x.isAfter(y) ? x : y);
            final bLatest = b
                .map((e) => e.createdAt)
                .reduce((x, y) => x.isAfter(y) ? x : y);
            return bLatest.compareTo(aLatest);
          });

    final ownStoryCount = showAddButton && myStatuses.isNotEmpty ? 1 : 0;
    final addButtonCount = showAddButton ? 1 : 0;
    final leadingCount = ownStoryCount + addButtonCount;
    final totalCount = groups.length + leadingCount;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (showAddButton && myStatuses.isNotEmpty && index == 0) {
            final latest = myStatuses.last;
            return GestureDetector(
              onTap: () => onStatusPressed(myStatuses),
              onLongPress: onMyStoryLongPress,
              child: _buildMyStoryItem(context, latest),
            );
          }

          if (showAddButton && index == ownStoryCount) {
            return GestureDetector(
              onTap: onAddPressed,
              child: _buildAddStatusItem(context),
            );
          }

          final listIndex = index - leadingCount;
          final statuses = List<CreatorStatus>.from(groups[listIndex])
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final status = statuses.isNotEmpty ? statuses.last : null;
          if (status == null) {
            return const SizedBox.shrink();
          }

          return GestureDetector(
            onTap: () => onStatusPressed(statuses),
            onLongPress:
                myCreatorId != null &&
                    myCreatorId.isNotEmpty &&
                    status.creatorId.trim() == myCreatorId
                ? onMyStoryLongPress
                : null,
            child: _buildStatusItem(context, status),
          );
        },
      ),
    );
  }

  Widget _buildStoryAvatar(BuildContext context, CreatorStatus status) {
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
          imagePreview.isNotEmpty
              ? _networkCircleImage(
                  url: imagePreview,
                  radius: 28,
                  backgroundColor: const Color(0xFF2A2D38),
                  fallback: const Icon(
                    Icons.image_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                )
              : const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF2A2D38),
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
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
    final url = (userImage ?? "https://via.placeholder.com/150").trim();
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
                  _networkCircleImage(
                    url: url,
                    radius: 28,
                    backgroundColor: const Color(0xFF2A2D38),
                    fallback: const Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: 26,
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
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
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

  Widget _buildMyStoryItem(BuildContext context, CreatorStatus status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: status.hasStory
                  ? const LinearGradient(colors: [Colors.purple, Colors.orange])
                  : null,
              color: status.hasStory ? null : Colors.grey.shade300,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: _buildStoryAvatar(context, status),
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
                2,
              ), // White space between boarder and image
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
                            width: 2,
                          ),
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
