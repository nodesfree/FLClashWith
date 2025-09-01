// services/invite_code_service.dart
import 'package:hiddify/features/panel/xboard/models/invite_code_model.dart';
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/xboard/services/token_expiry_handler.dart';
import 'package:hiddify/features/panel/xboard/utils/storage/token_storage.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';

class InviteCodeService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  // 生成邀请码的方法
  Future<bool> generateInviteCode(String accessToken) async {
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        await _v2boardApi.generateInvite(authData);
        return true;
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
      await _httpService.getRequest(
        "/api/v1/user/invite/save",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      return true; // 如果没有抛出异常，则表示成功生成邀请码
    }
  }

  // 获取邀请码数据的方法
  Future<List<InviteCode>> fetchInviteCodes(String accessToken) async {
    Map<String, dynamic> result;
    
    // 尝试使用auth_data
    try {
      final authData = await TokenStorage.getAuthData();
      if (authData != null) {
        result = await _v2boardApi.getInvites(authData);
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
      result = await _httpService.getRequest(
        "/api/v1/user/invite/fetch",
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    }

    if (result.containsKey("data") && result["data"] is Map<String, dynamic>) {
      final data = result["data"];
      // ignore: avoid_dynamic_calls
      final codes = data["codes"] as List;
      return codes
          .cast<Map<String, dynamic>>()
          .map((json) => InviteCode.fromJson(json))
          .toList();
    } else {
      throw Exception("Failed to retrieve invite codes");
    }
  }

  // 获取完整邀请码链接的方法
  String getInviteLink(String code) {
    final inviteLinkBase = "${HttpService.baseUrl}/#/register?code=";
    if (HttpService.baseUrl.isEmpty) {
      throw Exception('Base URL is not set.');
    }
    return '$inviteLinkBase$code';
  }
}
