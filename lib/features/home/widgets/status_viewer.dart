import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/services/status_service.dart';
import '../../../models/creator_status.dart';

class StatusViewer extends StatefulWidget {
  final CreatorStatus status;

  const StatusViewer({super.key, required this.status});

  @override
  State<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<StatusViewer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLikeLoading = false;
  late int _likeCount;
  late bool _likedByMe;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.status.likeCount;
    _likedByMe = widget.status.likedByMe;

    if (widget.status.mediaType == 'video') {
       final url = widget.status.imageUrl ?? "";
       if (url.isNotEmpty) {
         _controller = VideoPlayerController.networkUrl(Uri.parse(url))
           ..initialize().then((_) {
             setState(() => _isInitialized = true);
             _controller?.play();
             _controller?.setLooping(true);
           });
       }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final currentUser = context.read<AuthService>().currentUser;
    final canLike = currentUser != null &&
        currentUser.id.trim() != widget.status.creatorId.trim();
    if (!canLike || _isLikeLoading) return;

    final bool nextLiked = !_likedByMe;
    setState(() => _isLikeLoading = true);

    try {
      final result = await context.read<StatusService>().setStoryLike(
        statusId: widget.status.id,
        liked: nextLiked,
      );

      if (!mounted) return;
      setState(() {
        _likedByMe = result['liked_by_me'] == true;
        if (result['like_count'] is num) {
          _likeCount = (result['like_count'] as num).toInt();
        }
        _isLikeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLikeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser;
    final canLike = currentUser != null &&
        currentUser.id.trim() != widget.status.creatorId.trim();

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // Content
          Center(
            child: _buildContent(),
          ),
          
          // Progress Bar (Simplified)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: _isInitialized && widget.status.mediaType == 'video' ? null : 1.0,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header: Avatar, Name, and Close
          Positioned(
            top: MediaQuery.of(context).padding.top + 25,
            left: 16,
            right: 8,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(widget.status.creatorImage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.status.creatorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          if (canLike || _likeCount > 0)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: canLike ? _toggleLike : null,
                      iconSize: 24,
                      splashRadius: 20,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      icon: _isLikeLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _likedByMe ? Icons.favorite : Icons.favorite_border,
                              color: _likedByMe ? Colors.redAccent : Colors.white,
                            ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_likeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.status.mediaType == 'video') {
       if (_isInitialized && _controller != null) {
         return AspectRatio(
           aspectRatio: _controller!.value.aspectRatio,
           child: VideoPlayer(_controller!),
         );
       } else {
         return const CircularProgressIndicator(color: Colors.white);
       }
    } else {
       return Image.network(
         widget.status.imageUrl ?? "",
         fit: BoxFit.contain,
         errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.white),
       );
    }
  }
}
