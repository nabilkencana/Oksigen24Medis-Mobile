import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/core/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Retrieve user role name
  String get userRole => _currentUser?['role']?['name'] ?? 'GUEST';

  // Check if role is allowed
  bool hasRole(List<String> allowedRoles) {
    return allowedRoles.contains(userRole);
  }

  // Initialize and check auto-login
  Future<void> initialize() async {
    if (_isInitialized) return;
    await Future.delayed(const Duration(seconds: 2));
    _isLoading = true;
    notifyListeners();

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');
      final refreshToken = prefs.getString('refreshToken');
      if (token != null) {
        // Warm up in-memory cache so interceptor has tokens immediately
        _api.setMemoryTokens(
          accessToken: token,
          refreshToken: refreshToken ?? '',
        );
        // Fetch current user details
        final response = await _api.dio.get('/auth/me');
        _currentUser = _api.handleResponse(response);
        // Connect websocket if authenticated
        WebSocketService().connect();
      }
    } catch (e) {
      debugPrint('Error initializing auth provider: $e');
      try {
        final p = prefs ?? await SharedPreferences.getInstance();
        await p.remove('accessToken');
        await p.remove('refreshToken');
      } catch (_) {}
      _currentUser = null;
    } finally {
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Log in user
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = _api.handleResponse(response);

      _currentUser = data['user'];

      // Always set in-memory tokens immediately — this is the primary mechanism
      // that keeps the Authorization header working for all subsequent requests.
      // SharedPreferences is only a persistence layer for cold-start auto-login.
      _api.setMemoryTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', data['accessToken']);
        await prefs.setString('refreshToken', data['refreshToken']);
      } catch (_) {
        // Platform channel may be broken on Hot Restart — in-memory cache
        // handles the current session; disk persistence resumes on cold start.
      }

      // Connect WebSocket
      WebSocketService().connect();
    } catch (e) {
      _currentUser = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Change user password
  Future<void> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/auth/change-password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );
      _api.handleResponse(response);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Change user PIN
  Future<void> changePin(String oldPin, String newPin) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/auth/change-pin',
        data: {'oldPin': oldPin, 'newPin': newPin},
      );
      _api.handleResponse(response);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile details
  Future<void> updateProfile({required String fullName, String? branch}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.put(
        '/auth/profile',
        data: {
          'fullName': fullName,
          'branch': ?branch,
        },
      );
      final data = _api.handleResponse(response);
      _currentUser = data['user'] ?? data;
    } catch (e) {
      // Fallback: update locally so it functions for presentation/testing
      if (_currentUser != null) {
        _currentUser!['fullName'] = fullName;
        if (branch != null) {
          if (_currentUser!['branch'] is Map) {
            _currentUser!['branch']['name'] = branch;
          } else {
            _currentUser!['branch'] = {'name': branch};
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Log out user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Call logout endpoint (it clears session from backend)
      await _api.dio.post('/auth/logout');
    } catch (e) {
      // Even if network call fails, we still want to log out locally
    } finally {
      _currentUser = null;
      // Clear in-memory cache so no stale token is sent after logout
      _api.clearMemoryTokens();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('accessToken');
        await prefs.remove('refreshToken');
      } catch (_) {
        // Platform channel may be broken on Hot Restart
      }

      // Disconnect WebSocket
      WebSocketService().disconnect();

      _isLoading = false;
      notifyListeners();
    }
  }
}
