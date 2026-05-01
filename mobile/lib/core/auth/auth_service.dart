import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';
import 'token_storage.dart';
import '../../models/user.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthService(this._apiClient, this._tokenStorage) {
    _apiClient.setUnauthorizedHandler(_handleUnauthorizedSession);
  }

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCreator => _currentUser?.role == UserRole.creator;

  Future<void> init() async {
    final token = await _tokenStorage.getToken();
    if (token != null) {
      try {
        await fetchMe();
      } catch (e) {
        // Token invalid or network error
        await logout();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _clearError();
    _setLoading(true);
    try {
      final response = await _apiClient.client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        // Added specific type check
        _error = "Server returned invalid response format";
        return false;
      }

      final token = data['token'];
      final userJson = data['user'];

      if (token == null || userJson == null) {
        _error = "Server returned success but missing data";
        return false;
      }

      await _tokenStorage.saveToken(token);
      final user = User.fromJson(userJson);
      _currentUser = user;

      final roleString = user.role == UserRole.creator ? 'creator' : 'client';
      await _tokenStorage.saveRole(roleString);

      notifyListeners();
      return true;
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        _error = resData['error']?.toString() ?? 'Login failed';
      } else {
        _error = 'Login failed: ${e.message}';
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String name, String email, String password,
      {String role = 'client'}) async {
    _clearError();
    _setLoading(true);
    try {
      final response = await _apiClient.client.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'phone': '',
      });

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        // Added specific type check
        _error = "Server returned invalid response format";
        return false;
      }

      final token = data['token'];
      final userJson = data['user'];

      if (token == null || userJson == null) {
        _error = "Server returned success but missing data";
        return false;
      }

      await _tokenStorage.saveToken(token);
      final user = User.fromJson(userJson);
      _currentUser = user;
      final roleString = user.role == UserRole.creator ? 'creator' : 'client';
      await _tokenStorage.saveRole(roleString);

      notifyListeners();
      return true;
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        _error = resData['error']?.toString() ?? 'Registration failed';
      } else {
        _error = 'Registration failed: ${e.message}';
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchMe() async {
    try {
      final response = await _apiClient.client.get('/auth/me');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Added specific type check
        final user = User.fromJson(data);
        _currentUser = user;
        final roleString = user.role == UserRole.creator ? 'creator' : 'client';
        await _tokenStorage.saveRole(roleString);
        _error = null;
        notifyListeners();
      } else {
        debugPrint(
            "fetchMe: Expected Map<String, dynamic> but got ${data.runtimeType}");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    _currentUser = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> _handleUnauthorizedSession() async {
    final token = await _tokenStorage.getToken();
    if (token == null && _currentUser == null) {
      return;
    }

    await _tokenStorage.clear();
    _currentUser = null;
    _isLoading = false;
    _error = 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى';
    notifyListeners();
  }

  Future<User?> fetchUserProfile(String userId) async {
    try {
      final response = await _apiClient.client.get('/users/$userId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleFollow(String targetUserId) async {
    try {
      final response =
          await _apiClient.client.post('/users/$targetUserId/follow');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } catch (e) {
      debugPrint("Error toggling follow: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchReviews(String creatorId) async {
    try {
      final response = await _apiClient.client.get('/users/$creatorId/reviews');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> submitReview(
      String creatorId, int rating, String comment) async {
    try {
      final response = await _apiClient.client.post(
        '/users/$creatorId/reviews',
        data: {'rating': rating, 'comment': comment},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e) {
      debugPrint("Error submitting review: $e");
      return null;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? gender,
    String? avatarUrl,
    String? coverImageUrl,
  }) async {
    _clearError();
    _setLoading(true);
    try {
      final response =
          await _apiClient.client.post('/auth/update-profile', data: {
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (gender != null) 'gender': gender,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      });

      final data = response.data;
      debugPrint("AuthService: updateProfile response: $data");

      if (data is Map<String, dynamic> && data['success'] == true) {
        _currentUser = User.fromJson(data['user']);
        notifyListeners();
        return true;
      }
      _error = (data is Map)
          ? (data['error']?.toString() ?? "Update failed")
          : "Invalid response from server";
      return false;
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map) {
        _error = resData['error']?.toString() ?? 'Update failed';
      } else {
        _error = 'Update failed: ${e.message}';
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
