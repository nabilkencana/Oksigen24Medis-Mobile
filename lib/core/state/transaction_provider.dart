import 'package:flutter/material.dart';
import 'package:oksigen24medis_mobile2/core/services/api_service.dart';
import 'package:oksigen24medis_mobile2/core/services/websocket_service.dart';
import 'package:dio/dio.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _customers = [];
  List<dynamic> _rentals = [];
  List<dynamic> _sales = [];
  List<dynamic> _purchases = [];
  bool _isLoading = false;
  bool _isCustomerLoading = false;
  String? _error;

  List<dynamic> get customers => _customers;
  List<dynamic> get rentals => _rentals;
  List<dynamic> get sales => _sales;
  List<dynamic> get purchases => _purchases;
  bool get isLoading => _isLoading;
  bool get isCustomerLoading => _isCustomerLoading;
  String? get error => _error;

  TransactionProvider() {
    WebSocketService().dbChangeEvent.addListener(_onDbChange);
  }

  @override
  void dispose() {
    WebSocketService().dbChangeEvent.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    final path = WebSocketService().dbChangeEvent.value;
    if (path != null && path.contains('/transactions')) {
      debugPrint('WebSocket change detected for transactions: $path. Refreshing histories.');
      fetchTransactions(silent: true);
    }
  }

  Future<void> _fetchCustomersRaw() async {
    final response = await _api.dio.get('/inventory/customers',
        queryParameters: {'limit': 100});
    final data = _api.handleResponse(response);
    debugPrint('[TransactionProvider] fetchCustomers raw type: ${data.runtimeType}');
    if (data is List) {
      _customers = data;
    } else if (data is Map && data['items'] is List) {
      _customers = List<dynamic>.from(data['items']);
    } else if (data is Map && data['data'] is List) {
      _customers = List<dynamic>.from(data['data']);
    }
    debugPrint('[TransactionProvider] fetchCustomers count: ${_customers.length}');
  }

  // Fetch customer list
  Future<void> fetchCustomers() async {
    _isCustomerLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _fetchCustomersRaw();
    } catch (e) {
      _error = e.toString();
      debugPrint('[TransactionProvider] Error fetching customers: $e');
    } finally {
      _isCustomerLoading = false;
      notifyListeners();
    }
  }

  /// Create a new customer and return the created customer object.
  /// Automatically refreshes the customer list on success.
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final response = await _api.dio.post(
      '/inventory/customers',
      data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );
    final created = _api.handleResponse(response);
    // Refresh list so the new customer appears in dropdowns
    await fetchCustomers();
    return Map<String, dynamic>.from(created);
  }

  Future<void> fetchTransactions({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final futures = await Future.wait([
        _api.dio.get('/transactions/rentals', queryParameters: {'limit': 100}),
        _api.dio.get('/transactions/sales', queryParameters: {'limit': 100}),
        _api.dio.get('/transactions/purchases', queryParameters: {'limit': 100}),
      ]);

      final rentalRes = _api.handleResponse(futures[0]);
      final saleRes = _api.handleResponse(futures[1]);
      final purchaseRes = _api.handleResponse(futures[2]);

      if (rentalRes is List) {
        _rentals = rentalRes;
      } else if (rentalRes is Map && rentalRes['items'] is List) {
        _rentals = List<dynamic>.from(rentalRes['items']);
      } else if (rentalRes is Map && rentalRes['data'] is List) {
        _rentals = List<dynamic>.from(rentalRes['data']);
      }

      if (saleRes is List) {
        _sales = saleRes;
      } else if (saleRes is Map && saleRes['items'] is List) {
        _sales = List<dynamic>.from(saleRes['items']);
      } else if (saleRes is Map && saleRes['data'] is List) {
        _sales = List<dynamic>.from(saleRes['data']);
      }

      if (purchaseRes is List) {
        _purchases = purchaseRes;
      } else if (purchaseRes is Map && purchaseRes['items'] is List) {
        _purchases = List<dynamic>.from(purchaseRes['items']);
      } else if (purchaseRes is Map && purchaseRes['data'] is List) {
        _purchases = List<dynamic>.from(purchaseRes['data']);
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit Rent Transaction
  Future<Map<String, dynamic>> submitRental({
    required String customerId,
    required DateTime dueDate,
    required double amountPaid,
    required List<String> cylinderIds,
    String? notes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/transactions/rentals',
        data: {
          'customerId': customerId,
          'dueDate': dueDate.toUtc().toIso8601String(),
          'amountPaid': amountPaid,
          'cylinderIds': cylinderIds,
          'notes': notes,
        },
      );
      final data = _api.handleResponse(response);
      await fetchTransactions(silent: true);
      return data;
    } catch (e) {
      if (e is DioException) {
        throw _api.handleDioError(e);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit Sale Transaction
  Future<Map<String, dynamic>> submitSale({
    String? customerId,
    required double amountPaid,
    required List<Map<String, dynamic>> items,
    String? paymentMethod,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/transactions/sales',
        data: {
          'customerId': customerId,
          'amountPaid': amountPaid,
          'paymentMethod': paymentMethod ?? 'TUNAI',
          'items': items,
        },
      );
      final data = _api.handleResponse(response);
      await fetchTransactions(silent: true);
      return data;
    } catch (e) {
      if (e is DioException) {
        throw _api.handleDioError(e);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit Return Cylinder
  Future<Map<String, dynamic>> submitReturn({
    required String rentalId,
    required List<String> cylinderIds,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/transactions/rentals/$rentalId/return',
        data: {
          'cylinderIds': cylinderIds,
        },
      );
      final data = _api.handleResponse(response);
      await fetchTransactions(silent: true);
      return data;
    } catch (e) {
      if (e is DioException) {
        throw _api.handleDioError(e);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit Extend Rental Transaction
  Future<Map<String, dynamic>> extendRental({
    required String rentalId,
    required DateTime newDueDate,
    required double amountPaid,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/transactions/rentals/$rentalId/extend',
        data: {
          'dueDate': newDueDate.toUtc().toIso8601String(),
          'amountPaid': amountPaid,
        },
      );
      final data = _api.handleResponse(response);
      await fetchTransactions(silent: true);
      return data;
    } catch (e) {
      if (e is DioException) {
        throw _api.handleDioError(e);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit Refill Send to Vendor
  Future<Map<String, dynamic>> submitRefillSend({
    required String vendorId,
    required List<String> cylinderIds,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/transactions/refills/send',
        data: {
          'vendorId': vendorId,
          'cylinderIds': cylinderIds,
        },
      );
      final data = _api.handleResponse(response);
      await fetchTransactions(silent: true);
      return data;
    } catch (e) {
      if (e is DioException) {
        throw _api.handleDioError(e);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit Refill Receive from Vendor
  Future<Map<String, dynamic>> submitRefillReceive({
    required List<String> cylinderIds,
    required double costPerCylinder,
    required double amountPaid,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.post(
        '/transactions/refills/receive',
        data: {
          'cylinderIds': cylinderIds,
          'costPerCylinder': costPerCylinder,
          'amountPaid': amountPaid,
        },
      );
      final data = _api.handleResponse(response);
      await fetchTransactions(silent: true);
      return data;
    } catch (e) {
      if (e is DioException) {
        throw _api.handleDioError(e);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
