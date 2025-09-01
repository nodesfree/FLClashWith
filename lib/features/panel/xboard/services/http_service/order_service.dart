// services/order_service.dart
import 'package:hiddify/features/panel/xboard/models/order_model.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/xboard/services/token_expiry_handler.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';

class OrderService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  Future<List<Order>> fetchUserOrders(String accessToken) async {
    // 尝试使用V2Board API服务，使用auth_data作为Bearer token
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        final result = await _v2boardApi.getOrders(authData);
        if (result["status"] == "success") {
          final ordersJson = result["data"] as List;
          return ordersJson
              .map((json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception("Failed to fetch user orders: ${result['message']}");
        }
      } else {
        throw Exception('Auth data not found, please login again');
      }
    } catch (e) {
      if (TokenExpiryHandler.isAuthError(e)) {
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        rethrow;
      }
      // 回退到原有实现
      final result = await _httpService.getRequest(
        "/api/v1/user/order/fetch",
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (result["status"] == "success") {
        final ordersJson = result["data"] as List;
        return ordersJson
            .map((json) => Order.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception("Failed to fetch user orders: ${result['message']}");
      }
    }
  }

  Future<Map<String, dynamic>> getOrderDetails(
      String tradeNo, String accessToken) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        // V2BoardApiService没有getOrderDetails方法，直接使用HttpService
        return await _httpService.getRequest(
          "/api/v1/user/order/detail?trade_no=$tradeNo",
          headers: {'Authorization': 'Bearer $authData'},
        );
      } else {
        throw Exception('Auth data not found, please login again');
      }
    } catch (e) {
      if (TokenExpiryHandler.isAuthError(e)) {
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        rethrow;
      }
      // 回退到原有实现
      return await _httpService.getRequest(
        "/api/v1/user/order/detail?trade_no=$tradeNo",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }
  }

  Future<Map<String, dynamic>> cancelOrder(
      String tradeNo, String accessToken) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        // V2BoardApiService没有cancelOrder方法，直接使用HttpService
        return await _httpService.postRequest(
          "/api/v1/user/order/cancel",
          {"trade_no": tradeNo},
          headers: {'Authorization': 'Bearer $authData'},
        );
      } else {
        throw Exception('Auth data not found, please login again');
      }
    } catch (e) {
      if (TokenExpiryHandler.isAuthError(e)) {
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        rethrow;
      }
      // 回退到原有实现
      return await _httpService.postRequest(
        "/api/v1/user/order/cancel",
        {"trade_no": tradeNo},
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }
  }

  Future<Map<String, dynamic>> createOrder(
      String accessToken, int planId, String period) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        return await _v2boardApi.createOrder(
          token: authData,
          planId: planId,
          period: period,
        );
      } else {
        throw Exception('Auth data not found, please login again');
      }
    } catch (e) {
      if (TokenExpiryHandler.isAuthError(e)) {
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        rethrow;
      }
      // 回退到原有实现
      return await _httpService.postRequest(
        "/api/v1/user/order/save",
        {"plan_id": planId, "period": period},
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }
  }
}
