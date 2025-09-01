import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'v2board_token';
  static const String _authDataKey = 'v2board_auth_data';
  
  // 内存缓存，提高性能
  static String? _cachedToken;
  static String? _cachedAuthData;

  // 存储 token（持久化到SharedPreferences）
  static Future<void> storeToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _cachedToken = token;
      print("Token stored successfully: $token");
    } catch (e) {
      print("Error storing token: $e");
      rethrow;
    }
  }

  // 存储 auth_data（持久化到SharedPreferences）
  static Future<void> storeAuthData(String authData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authDataKey, authData);
      _cachedAuthData = authData;
      print("Auth data stored successfully: $authData");
    } catch (e) {
      print("Error storing auth data: $e");
      rethrow;
    }
  }

  // 同时存储 token 和 auth_data
  static Future<void> storeCredentials(String token, String authData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_authDataKey, authData);
      _cachedToken = token;
      _cachedAuthData = authData;
      print("Credentials stored successfully - Token: $token, Auth Data: $authData");
    } catch (e) {
      print("Error storing credentials: $e");
      rethrow;
    }
  }

  // 获取 token（优先从缓存，然后从SharedPreferences）
  static Future<String?> getToken() async {
    try {
      // 如果缓存中有token，直接返回
      if (_cachedToken != null) {
        print("Token retrieved from cache: $_cachedToken");
        return _cachedToken;
      }
      
      // 从SharedPreferences中读取
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      
      // 更新缓存
      _cachedToken = token;
      
      print("Token retrieved from storage: $token");
      return token;
    } catch (e) {
      print("Error retrieving token: $e");
      return null;
    }
  }

  // 获取 auth_data（优先从缓存，然后从SharedPreferences）
  static Future<String?> getAuthData() async {
    try {
      // 如果缓存中有auth_data，直接返回
      if (_cachedAuthData != null) {
        print("Auth data retrieved from cache: $_cachedAuthData");
        return _cachedAuthData;
      }
      
      // 从SharedPreferences中读取
      final prefs = await SharedPreferences.getInstance();
      final authData = prefs.getString(_authDataKey);
      
      // 更新缓存
      _cachedAuthData = authData;
      
      print("Auth data retrieved from storage: $authData");
      return authData;
    } catch (e) {
      print("Error retrieving auth data: $e");
      return null;
    }
  }

  // 删除 token（同时清除缓存和SharedPreferences）
  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      _cachedToken = null;
      print("Token deleted successfully");
    } catch (e) {
      print("Error deleting token: $e");
      rethrow;
    }
  }

  // 删除 auth_data（同时清除缓存和SharedPreferences）
  static Future<void> deleteAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authDataKey);
      _cachedAuthData = null;
      print("Auth data deleted successfully");
    } catch (e) {
      print("Error deleting auth data: $e");
      rethrow;
    }
  }

  // 删除所有凭据（token 和 auth_data）
  static Future<void> deleteAllCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_authDataKey);
      _cachedToken = null;
      _cachedAuthData = null;
      print("All credentials deleted successfully");
    } catch (e) {
      print("Error deleting credentials: $e");
      rethrow;
    }
  }

  // 检查是否有有效的认证凭据
  static Future<bool> hasValidCredentials() async {
    try {
      final token = await getToken();
      final authData = await getAuthData();
      return token != null && authData != null;
    } catch (e) {
      print("Error checking credentials: $e");
      return false;
    }
  }
}
