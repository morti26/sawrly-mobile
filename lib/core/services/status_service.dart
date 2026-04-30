import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../../models/creator_status.dart';

class StatusService extends ChangeNotifier {
  final ApiClient _apiClient;

  List<CreatorStatus> _statusList = [];
  bool _isLoading = false;

  StatusService(this._apiClient);

  List<CreatorStatus> get statusList => _statusList;
  bool get isLoading => _isLoading;

  Future<void> fetchStatuses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.client.get('/status');
      final List<dynamic> data = response.data;

      _statusList = data.map((json) {
        return CreatorStatus.fromJson(json);
      }).toList();
      debugPrint('STORYDBG fetchStatuses ok count=${_statusList.length}');
      for (final s in _statusList.take(5)) {
        debugPrint(
          'STORYDBG status id=${s.id} creatorId=${s.creatorId} creatorName=${s.creatorName} mediaType=${s.mediaType} imageUrl=${s.imageUrl ?? ''} videoUrl=${s.videoUrl ?? ''}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching statuses: $e');
      debugPrint('STORYDBG fetchStatuses failed $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> postStatus(String url, String mediaType, String caption) async {
    try {
      await _apiClient.client.post('/status', data: {
        'mediaUrl': url,
        'mediaType': mediaType,
        'caption': caption,
      });
      await fetchStatuses(); // Refresh list
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String id,
    required String mediaUrl,
    required String mediaType,
    String caption = '',
  }) async {
    try {
      await _apiClient.client.patch('/status', data: {
        'id': id,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'caption': caption,
      });
      await fetchStatuses();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStatus(String id) async {
    try {
      await _apiClient.client.delete('/status', queryParameters: {'id': id});
      await fetchStatuses();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> setStoryLike({
    required String statusId,
    required bool liked,
  }) async {
    try {
      final response = await _apiClient.client.post('/status/like', data: {
        'statusId': statusId,
        'liked': liked,
      });

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      final int likeCount =
          data['like_count'] is num ? (data['like_count'] as num).toInt() : 0;
      final bool likedByMe = data['liked_by_me'] == true;

      _statusList = _statusList.map((status) {
        if (status.id != statusId) return status;
        return status.copyWith(likeCount: likeCount, likedByMe: likedByMe);
      }).toList();
      notifyListeners();

      return data;
    } catch (e) {
      rethrow;
    }
  }
}
