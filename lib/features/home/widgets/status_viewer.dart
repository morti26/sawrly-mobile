import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/services/status_service.dart';
import '../../../models/creator_status.dart';

class StatusViewer extends StatefulWidget {
  final List<CreatorStatus> statuses;
  final int initialIndex;

  const StatusViewer({
    super.key,
    required this.statuses,
    this.initialIndex = 0,
  });

  @override
  State<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<StatusViewer> {
  VideoPlayerController? _controller;
  Future<void>? _videoInitFuture;
  bool _isLikeLoading = false;
  late int _index;
  late int _likeCount;
  late bool _likedByMe;

  CreatorStatus get _status => widget.statuses[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.statuses.length - 1);
    _loadForIndex(_index);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _loadForIndex(int index) {
    _controller?.dispose();
    _controller = null;
    _videoInitFuture = null;

    _likeCount = widget.statuses[index].likeCount;
    _likedByMe = widget.statuses[index].likedByMe;

    final status = widget.statuses[index];
    if (status.mediaType == 'video') {
      final url = status.imageUrl ?? '';
      if (url.isNotEmpty) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url))
          ..setLooping(true);
        _controller = controller;
        _videoInitFuture = controller.initialize().then((_) {
          if (!mounted) return;
          controller.play();
          setState(() {});
        });
      }
    }

    setState(() {
      _index = index;
    });
  }

  void _goNext() {
    if (_index >= widget.statuses.length - 1) {
      Navigator.pop(context);
      return;
    }
    _loadForIndex(_index + 1);
  }

  void _goPrev() {
    if (_index <= 0) return;
    _loadForIndex(_index - 1);
  }

  Future<void> _toggleLike() async {
    final currentUser = context.read<AuthService>().currentUser;
    final canLike = currentUser != null &&
        currentUser.id.trim() != _status.creatorId.trim();
    if (!canLike || _isLikeLoading) return;

    final bool nextLiked = !_likedByMe;
    setState(() => _isLikeLoading = true);

    try {
      final result = await context.read<StatusService>().setStoryLike(
        statusId: _status.id,
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
        currentUser.id.trim() != _status.creatorId.trim();

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final width = MediaQuery.of(context).size.width;
                final x = details.globalPosition.dx;
                if (x < width * 0.33) {
                  _goPrev();
                } else {
                  _goNext();
                }
              },
              child: Center(
                child: _buildContent(),
              ),
            ),
          ),
          
          // Progress Bar (Simplified)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(widget.statuses.length, (i) {
                final active = i == _index;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                    height: 2,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }),
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
                  backgroundImage: NetworkImage(_status.creatorImage),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _status.creatorName,
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
    if (_status.mediaType == 'video') {
      final future = _videoInitFuture;
      if (_controller == null || future == null) {
        return const CircularProgressIndicator(color: Colors.white);
      }
      return FutureBuilder<void>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              _controller == null ||
              !_controller!.value.isInitialized) {
            return const CircularProgressIndicator(color: Colors.white);
          }
          return AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          );
        },
      );
    }

    return Image.network(
      _status.imageUrl ?? '',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.error, color: Colors.white),
    );
  }
}
