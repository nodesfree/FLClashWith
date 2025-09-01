// services/payment_service.dart
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/xboard/services/token_expiry_handler.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';

class PaymentService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  Future<Map<String, dynamic>> submitOrder(
      String tradeNo, String method, String accessToken,) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        return await _v2boardApi.checkoutOrder(
          token: authData,
          tradeNo: tradeNo,
          method: int.parse(method),
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
        "/api/v1/user/order/checkout",
        {"trade_no": tradeNo, "method": method},
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }
  }

  Future<List<dynamic>> getPaymentMethods(String accessToken) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        final response = await _v2boardApi.getPaymentMethods(authData);
        return (response['data'] as List).cast<dynamic>();
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
      final response = await _httpService.getRequest(
        "/api/v1/user/order/getPaymentMethod",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return (response['data'] as List).cast<dynamic>();
    }
  }
}
