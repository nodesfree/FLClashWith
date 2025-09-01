// services/auth_service.dart
import 'package:hiddify/features/panel/xboard/services/http_service/http_service.dart';
import 'package:hiddify/features/panel/v2board/services/v2board_api_service.dart';

class AuthService {
  final HttpService _httpService = HttpService();
  final V2BoardApiService _v2boardApi = V2BoardApiService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    // 使用新的V2Board API服务
    try {
      final result = await _v2boardApi.login(email, password);
      return result;
    } catch (e) {
      // 如果新API失败，回退到原有实现
      return await _httpService.postRequest(
        "/api/v1/passport/auth/login",
        {"email": email, "password": password},
        requiresHeaders: true,
      );
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String inviteCode, String emailCode) async {
    return await _httpService.postRequest(
      "/api/v1/passport/auth/register",
      {
        "email": email,
        "password": password,
        "invite_code": inviteCode,
        "email_code": emailCode,
      },
    );
  }

  Future<Map<String, dynamic>> sendVerificationCode(String email) async {
    return await _httpService.postRequest(
      "/api/v1/passport/comm/sendEmailVerify",
      {'email': email},
    );
  }

  Future<Map<String, dynamic>> resetPassword(String email, String password, String emailCode) async {
    return await _httpService.postRequest(
      "/api/v1/passport/auth/forget",
      {
        "email": email,
        "password": password,
        "email_code": emailCode,
      },
    );
  }
}
