// services/user_service.dart
import 'package:hiddify/features/panel/xboard/models/user_info_model.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';

class UserService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  Future<UserInfo?> fetchUserInfo(String accessToken) async {
    final result = await _httpService.getRequest(
      "/api/v1/user/info",
      headers: {'Authorization': accessToken},
    );
    if (result.containsKey("data")) {
      final data = result["data"];
      return UserInfo.fromJson(data as Map<String, dynamic>);
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
    // 使用新的V2Board API服务
    try {
      final result = await _v2boardApi.getSubscription(accessToken);
      // ignore: avoid_dynamic_calls
      return result["data"]["subscribe_url"] as String?;
    } catch (e) {
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
    // 使用新的V2Board API服务
    try {
      final result = await _v2boardApi.resetSubscription(accessToken);
      return result["data"] as String?;
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
