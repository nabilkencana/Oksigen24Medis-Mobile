import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/core/services/websocket_service.dart';

class WarehouseProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _cylinders = [];
  List<dynamic> _products = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get cylinders => _cylinders;
  List<dynamic> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WarehouseProvider() {
    WebSocketService().dbChangeEvent.addListener(_onDbChange);
  }

  @override
  void dispose() {
    WebSocketService().dbChangeEvent.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    final path = WebSocketService().dbChangeEvent.value;
    if (path != null && (path.contains('/inventory') || path.contains('/transactions'))) {
      debugPrint('WebSocket change detected for inventory: $path. Refreshing warehouse stocks.');
      fetchInventory(silent: true);
    }
  }

  bool _isAccessoryAsset(String serial, String size) {
    final s = serial.toUpperCase();
    final sz = size.toUpperCase();
    return s.startsWith('REG-') || s.startsWith('TRL-') || s.startsWith('ACC-') || sz == 'PCS';
  }

  // Get only actual cylinders
  List<dynamic> get actualCylinders =>
      _cylinders.where((c) => !_isAccessoryAsset(c['serialNumber']?.toString() ?? '', c['size']?.toString() ?? '')).toList();

  // Get rentable accessory assets
  List<dynamic> get rentableAccessories =>
      _cylinders.where((c) => _isAccessoryAsset(c['serialNumber']?.toString() ?? '', c['size']?.toString() ?? '')).toList();

  // Get status count for actual cylinders
  int getCountByStatus(String status) {
    return actualCylinders.where((c) => c['status'] == status).length;
  }

  Future<void> fetchInventory({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final futures = await Future.wait([
        _api.dio.get('/inventory/cylinders', queryParameters: {'limit': 100}),
        _api.dio.get('/inventory/products', queryParameters: {'limit': 100}),
      ]);

      final cylinderRes = _api.handleResponse(futures[0]);
      final productRes = _api.handleResponse(futures[1]);

      // Backend returns { items: [...], meta: {...} } for paginated endpoints
      if (cylinderRes is List) {
        _cylinders = cylinderRes;
      } else if (cylinderRes is Map && cylinderRes['items'] is List) {
        _cylinders = List<dynamic>.from(cylinderRes['items']);
      } else if (cylinderRes is Map && cylinderRes['data'] is List) {
        _cylinders = List<dynamic>.from(cylinderRes['data']);
      }

      if (productRes is List) {
        _products = productRes;
      } else if (productRes is Map && productRes['items'] is List) {
        _products = List<dynamic>.from(productRes['items']);
      } else if (productRes is Map && productRes['data'] is List) {
        _products = List<dynamic>.from(productRes['data']);
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching inventory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new stock movement via API
  Future<void> addStock({
    required String type, // 'rentals', 'sales', 'purchases' or vendor refills
    required Map<String, dynamic> data,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post('/transactions/$type', data: data);
      _api.handleResponse(response);
      await fetchInventory(silent: true);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
