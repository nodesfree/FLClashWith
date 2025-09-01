import 'package:dio/dio.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import '../../xboard/services/http_service/domain_service.dart';

/// V2Board API 服务类
/// 提供与 V2Board 后端 API 的交互功能
class V2BoardApiService with InfraLogger {
  late final Dio _dio;
  static const String _defaultBaseUrl = 'https://api.example.com';

  V2BoardApiService() {
    _dio = Dio();
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    // 添加拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          loggy.debug('请求: ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          loggy.debug('响应: ${response.statusCode} ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (error, handler) {
          loggy.error('请求错误: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// 获取API基础URL
  Future<String> get baseUrl async {
    try {
      final validDomain = await DomainService.fetchValidDomain();
      if (validDomain != null) {
        loggy.info('使用有效域名: $validDomain');
        return validDomain;
      } else {
        loggy.warning('无法获取有效域名，使用默认域名: $_defaultBaseUrl');
        return _defaultBaseUrl;
      }
    } catch (e) {
      loggy.error('获取域名失败: $e，使用默认域名: $_defaultBaseUrl');
      return _defaultBaseUrl;
    }
  }

  // ============ 认证相关 API ============

  /// 用户登录
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/passport/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('登录失败: $e');
      rethrow;
    }
  }

  /// 用户注册
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? inviteCode,
    String? emailCode,
  }) async {
    try {
      final data = <String, dynamic>{
        'email': email,
        'password': password,
      };
      if (inviteCode != null) data['invite_code'] = inviteCode;
      if (emailCode != null) data['email_code'] = emailCode;

      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/passport/auth/register',
        data: data,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('注册失败: $e');
      rethrow;
    }
  }

  /// 发送邮箱验证码
  Future<Map<String, dynamic>> sendEmailCode(String email) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/passport/comm/sendEmailVerify',
        data: {'email': email},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('发送邮箱验证码失败: $e');
      rethrow;
    }
  }

  /// 忘记密码
  Future<Map<String, dynamic>> forgetPassword({
    required String email,
    required String password,
    required String emailCode,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/passport/auth/forget',
        data: {
          'email': email,
          'password': password,
          'email_code': emailCode,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('重置密码失败: $e');
      rethrow;
    }
  }

  /// 退出登录
  Future<Map<String, dynamic>> logout(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/passport/auth/logout',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('退出登录失败: $e');
      rethrow;
    }
  }

  // ============ 用户相关 API ============

  /// 获取用户信息
  Future<Map<String, dynamic>> getUserInfo(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/info',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取用户信息失败: $e');
      rethrow;
    }
  }

  /// 获取用户统计
  Future<Map<String, dynamic>> getUserStats(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/getStat',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取用户统计失败: $e');
      rethrow;
    }
  }

  /// 获取订阅信息
  Future<Map<String, dynamic>> getSubscription(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      
      // 首先验证token是否有效，通过获取用户信息
      try {
        final userInfoResponse = await _dio.get(
          '$apiBaseUrl/user/info',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        loggy.info('用户信息验证成功: ${userInfoResponse.data}');
      } catch (e) {
        loggy.error('Token验证失败: $e');
        rethrow;
      }
      
      final response = await _dio.get(
        '$apiBaseUrl/user/getSubscribe',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取订阅信息失败: $e');
      rethrow;
    }
  }

  /// 重置订阅链接
  Future<Map<String, dynamic>> resetSubscription(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/resetSecurity',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('重置订阅失败: $e');
      rethrow;
    }
  }

  // ============ 订单相关 API ============

  /// 创建订单
  Future<Map<String, dynamic>> createOrder({
    required String token,
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    try {
      final data = <String, dynamic>{
        'plan_id': planId,
        'period': period,
      };
      if (couponCode != null) data['coupon_code'] = couponCode;

      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/user/order/save',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('创建订单失败: $e');
      rethrow;
    }
  }

  /// 订单结算
  Future<Map<String, dynamic>> checkoutOrder({
    required String token,
    required String tradeNo,
    required int method,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/user/order/checkout',
        data: {
          'trade_no': tradeNo,
          'method': method,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('订单结算失败: $e');
      rethrow;
    }
  }

  /// 获取订单列表
  Future<Map<String, dynamic>> getOrders(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/order/fetch',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取订单列表失败: $e');
      rethrow;
    }
  }

  /// 获取支付方式
  Future<Map<String, dynamic>> getPaymentMethods(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/order/getPaymentMethod',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取支付方式失败: $e');
      rethrow;
    }
  }

  // ============ 套餐相关 API ============

  /// 获取套餐列表
  Future<Map<String, dynamic>> getPlans(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/plan/fetch',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取套餐列表失败: $e');
      rethrow;
    }
  }

  // ============ 服务器相关 API ============

  /// 获取服务器列表
  Future<Map<String, dynamic>> getServers(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/server/fetch',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取服务器列表失败: $e');
      rethrow;
    }
  }

  // ============ 邀请相关 API ============

  /// 生成邀请码
  Future<Map<String, dynamic>> generateInvite(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/invite/save',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('生成邀请码失败: $e');
      rethrow;
    }
  }

  /// 获取邀请列表
  Future<Map<String, dynamic>> getInvites(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/invite/fetch',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取邀请列表失败: $e');
      rethrow;
    }
  }

  /// 获取邀请详情
  Future<Map<String, dynamic>> getInviteDetails(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/invite/details',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取邀请详情失败: $e');
      rethrow;
    }
  }

  // ============ 工单相关 API ============

  /// 创建工单
  Future<Map<String, dynamic>> createTicket({
    required String token,
    required String subject,
    required int level,
    required String message,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/user/ticket/save',
        data: {
          'subject': subject,
          'level': level,
          'message': message,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('创建工单失败: $e');
      rethrow;
    }
  }

  /// 获取工单列表
  Future<Map<String, dynamic>> getTickets(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/ticket/fetch',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取工单列表失败: $e');
      rethrow;
    }
  }

  /// 回复工单
  Future<Map<String, dynamic>> replyTicket({
    required String token,
    required int ticketId,
    required String message,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/user/ticket/reply',
        data: {
          'id': ticketId,
          'message': message,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('回复工单失败: $e');
      rethrow;
    }
  }

  /// 关闭工单
  Future<Map<String, dynamic>> closeTicket({
    required String token,
    required int ticketId,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/user/ticket/close',
        data: {'id': ticketId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('关闭工单失败: $e');
      rethrow;
    }
  }

  // ============ 客户端订阅 API ============

  /// 获取订阅配置
  Future<String> getSubscriptionConfig(String userToken) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/client/subscribe?token=$userToken',
        options: Options(
          responseType: ResponseType.plain,
        ),
      );
      return response.data as String;
    } catch (e) {
      loggy.error('获取订阅配置失败: $e');
      rethrow;
    }
  }

  // ============ 通用配置 API ============

  /// 获取系统配置
  Future<Map<String, dynamic>> getSystemConfig(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/comm/config',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取系统配置失败: $e');
      rethrow;
    }
  }

  // ============ 优惠券相关 API ============

  /// 验证优惠券
  Future<Map<String, dynamic>> checkCoupon({
    required String token,
    required String code,
    required int planId,
    required String period,
  }) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.post(
        '$apiBaseUrl/user/coupon/check',
        data: {
          'code': code,
          'plan_id': planId,
          'period': period,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('验证优惠券失败: $e');
      rethrow;
    }
  }

  // ============ 流量统计 API ============

  /// 获取流量日志
  Future<Map<String, dynamic>> getTrafficLog(String token) async {
    try {
      final apiBaseUrl = await baseUrl;
      final response = await _dio.get(
        '$apiBaseUrl/user/stat/getTrafficLog',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      loggy.error('获取流量日志失败: $e');
      rethrow;
    }
  }

  // ============ 工具方法 ============

  /// 设置API基础URL
  void setBaseUrl(String newBaseUrl) {
    // 更新baseUrl（需要重新实例化服务）
    loggy.info('更新API基础URL: $newBaseUrl');
  }

  /// 关闭HTTP客户端
  void close() {
    _dio.close();
  }
}
