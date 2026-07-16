import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/core/services/websocket_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _summary;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DashboardProvider() {
    // Listen for WebSocket db_change events to trigger automatic refetches
    WebSocketService().dbChangeEvent.addListener(_onDbChange);
  }

  @override
  void dispose() {
    WebSocketService().dbChangeEvent.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    final path = WebSocketService().dbChangeEvent.value;
    if (path != null) {
      debugPrint('WebSocket db_change detected on dashboard path: $path. Refreshing dashboard stats.');
      fetchSummary(silent: true);
    }
  }

  Future<void> fetchSummary({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await _api.dio.get('/dashboard/summary');
      _summary = _api.handleResponse(response);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching dashboard summary: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
