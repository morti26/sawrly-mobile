import 'dart:async';

import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

class SupportMessage {
  final String id;
  final String userId;
  final String senderType;
  final String content;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.userId,
    required this.senderType,
    required this.content,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'],
      userId: json['user_id'],
      senderType: json['sender_type'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}

class SupportService extends ChangeNotifier {
  final ApiClient _apiClient;
  List<SupportMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<String>? _streamSubscription;
  Timer? _pollingTimer;
  bool _isStreaming = false;

  SupportService(this._apiClient);

  List<SupportMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isStreaming => _isStreaming;

  Future<void> fetchMessages({bool isPolling = false}) async {
    if (!isPolling) {
      _isLoading = true;
      if (hasListeners) notifyListeners();
    }

    try {
      final res = await _apiClient.client.get('/support');
      if (res.statusCode == 200) {
        final List<dynamic> data = res.data;
        _messages = data.map((json) => SupportMessage.fromJson(json)).toList();
        _error = null;
      } else {
        _error = "Failed to load messages: ${res.statusCode}";
      }
    } catch (e) {
      if (!isPolling) _error = e.toString();
      debugPrint("Fetch Messages Error: $e");
    } finally {
      if (!isPolling) _isLoading = false;
      if (hasListeners) notifyListeners();
    }
  }

  Future<bool> sendMessage(String content) async {
    try {
      final res = await _apiClient.client.post('/support', data: {'content': content});
      if (res.statusCode == 200 || res.statusCode == 201) {
        final newMessage = SupportMessage.fromJson(res.data);
        _messages.add(newMessage);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Send Message Error: $e");
      return false;
    }
  }

  Future<void> _startPollingLoop() async {
    await fetchMessages();
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchMessages(isPolling: true);
    });
    _isLoading = false;
    _error = null;
    if (hasListeners) notifyListeners();
  }

  Future<void> connectMessageStream() async {
    if (_isStreaming) {
      return;
    }

    _isStreaming = true;
    _error = null;
    _isLoading = true;
    if (hasListeners) notifyListeners();

    try {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      // Production proxy does not reliably flush SSE in current deployment.
      // Use periodic polling to keep support chat working consistently.
      await _startPollingLoop();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isStreaming = false;
      if (hasListeners) notifyListeners();
    }
  }

  Future<void> disconnectMessageStream() async {
    _isStreaming = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (hasListeners) notifyListeners();
  }
}
