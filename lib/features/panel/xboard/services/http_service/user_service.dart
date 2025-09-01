// services/user_service.dart
import 'package:hiddify/features/panel/xboard/models/user_info_model.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/xboard/services/token_expiry_handler.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';

class UserService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  Future<UserInfo?> fetchUserInfo(String accessToken) async {
    // 尝试使用V2Board API服务，使用auth_data作为Bearer token
    try {
      // 获取存储的auth_data用于V2Board API认证（JWT格式）
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        final result = await _v2boardApi.getUserInfo(authData);
        if (result.containsKey("data")) {
          final data = result["data"];
          return UserInfo.fromJson(data as Map<String, dynamic>);
        }
      } else {
        throw Exception('Auth data not found, please login again');
      }
    } catch (e) {
      // 检查是否是认证错误
      if (TokenExpiryHandler.isAuthError(e)) {
        // 使用全局认证错误处理器
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        rethrow;
      }
      // 如果新API失败，回退到原有实现
      final result = await _httpService.getRequest(
        "/api/v1/user/info",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (result.containsKey("data")) {
        final data = result["data"];
        return UserInfo.fromJson(data as Map<String, dynamic>);
      }
    }
    throw Exception("Failed to retrieve user info");
  }

  Future<bool> validateToken(String token) async {
    try {
      final response = await _httpService.getRequest(
        "/api/v1/user/getSubscribe",
        headers: {'Authorization': 'Bearer $token'},
      );
      return response['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  Future<String?> getSubscriptionLink(String accessToken) async {
    // 直接使用V2Board客户端订阅端点，使用简单token作为查询参数
    try {
      // 获取存储的简单token用于客户端订阅
      final token = await TokenStorage.getToken();
      if (token != null) {
        // 获取API基础URL（已包含/api/v1）
        final apiBaseUrl = await _v2boardApi.baseUrl;
        // 构建客户端订阅URL，去掉/api/v1后缀，添加客户端端点
        final domainUrl = apiBaseUrl.replaceAll('/api/v1', '');
        final subscribeUrl = '$domainUrl/api/v1/client/subscribe?token=$token';
        return subscribeUrl;
      } else {
        throw Exception('Token not found, please login again');
      }
    } catch (e) {
      // 检查是否是认证错误
      if (TokenExpiryHandler.isAuthError(e)) {
        // 使用全局认证错误处理器
        await TokenExpiryHandler.handleAuthError(
          context: null,
          ref: null,
          errorMessage: e.toString(),
        );
        rethrow;
      }
      // 如果新API失败，回退到原有实现
      final result = await _httpService.getRequest(
        "/api/v1/user/getSubscribe",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      // ignore: avoid_dynamic_calls
      return result["data"]["subscribe_url"] as String?;
    }
  }

  Future<String?> resetSubscriptionLink(String accessToken) async {
    // 使用新的V2Board API服务，尝试使用auth_data作为Bearer token
    try {
      // 获取存储的auth_data用于V2Board API认证（JWT格式）
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        final result = await _v2boardApi.resetSubscription(authData);
        return result["data"] as String?;
      } else {
        throw Exception('Auth data not found, please login again');
      }
    } catch (e) {
      // 如果新API失败，回退到原有实现
      final result = await _httpService.getRequest(
        "/api/v1/user/resetSecurity",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return result["data"] as String?;
    }
  }
}
