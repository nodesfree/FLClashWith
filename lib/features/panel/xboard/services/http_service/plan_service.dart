// services/plan_service.dart
import 'package:hiddify/features/panel/xboard/models/plan_model.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/xboard/services/token_expiry_handler.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';


class PlanService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  Future<List<Plan>> fetchPlanData(String accessToken) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        final result = await _v2boardApi.getPlans(authData);
        if (result["status"] == "success") {
          final plansJson = result["data"] as List;
          return plansJson
              .map((json) => Plan.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception("Failed to fetch plan data: ${result['message']}");
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
        "/api/v1/user/plan/fetch",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return (result["data"] as List)
          .cast<Map<String, dynamic>>()
          .map((json) => Plan.fromJson(json))
          .toList();
    }
  }
}
