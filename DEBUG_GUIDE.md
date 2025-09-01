# HiddifyWithPanels 调试指南

## 🔧 已修复的问题

### 1. ✅ API基础URL配置
- **问题**: `No host specified in URI /api/v1/user/getSubscribe`
- **修复**: 配置了正确的v2board API基础URL
- **文件**: `lib/features/panel/v2board/services/v2board_api_service.dart`
- **URL**: `https://smallrocket-subscribe001.xn--1kv99f.com/api/v1`

### 2. ✅ 订阅内容解析
- **问题**: `Exception: 没有找到有效的代理配置`
- **修复**: 改进了配置转换器，支持多种订阅格式
- **文件**: `lib/clash/config_converter.dart`
- **支持格式**: Clash YAML、VMess、VLess、Trojan、Shadowsocks

### 3. ✅ 用户服务API集成
- **问题**: 旧的HttpService缺少基础URL
- **修复**: UserService现在使用V2BoardApiService
- **文件**: `lib/features/panel/xboard/services/http_service/user_service.dart`

### 4. ✅ 订阅内容解析
- **问题**: `Exception: 没有找到有效的代理配置`
- **修复**: 添加Hysteria2协议支持，改进Base64解码
- **文件**: `lib/clash/config_converter.dart`
- **支持协议**: Hysteria2、Shadowsocks、VMess、VLess、Trojan
- **测试结果**: 成功解析40个节点（11个Hysteria2 + 29个Shadowsocks）

## 🧪 测试步骤

### 第一步: 验证登录功能
1. 启动应用
2. 使用您的v2board凭据登录
3. 检查日志中是否显示成功的登录响应

**期望日志**:
```
POST https://smallrocket-subscribe001.xn--1kv99f.com/api/v1/passport/auth/login response: {"data":{"token":"...","auth_data":"..."}}
Token stored: ...
```

### 第二步: 验证订阅获取
1. 登录成功后，应用会自动尝试获取订阅
2. 检查日志中的订阅处理过程

**期望日志**:
```
[PanelSubscriptionAdapter] 开始更新面板订阅
[PanelSubscriptionAdapter] 获取到订阅链接: https://...
[PanelSubscriptionAdapter] 成功下载订阅内容，长度: XXXX
[ConfigConverter] 处理订阅内容，长度: XXXX
[ConfigConverter] Base64解码成功，解码后长度: XXXX
[ConfigConverter] 解析订阅链接: 总行数=40, 有效代理=40
[ConfigConverter] 成功解析 X 个代理配置
```

### 第三步: 验证节点显示
1. 检查应用界面是否显示节点列表
2. 尝试点击连接按钮
3. 检查连接状态

## 🐛 问题排查

### 如果仍然看到 "No host specified"
1. 检查HttpService是否仍在使用
2. 确保V2BoardApiService正确初始化
3. 查看是否有其他服务没有更新

### 如果订阅解析失败
1. 检查订阅内容格式（在日志中）
2. 验证订阅链接是否返回正确内容
3. 查看ConfigConverter的调试日志

### 如果没有节点显示
1. 检查ClashAdapterService是否正确初始化
2. 验证配置转换是否成功
3. 查看SimpleClashCore的状态

## 📋 调试命令

### 运行应用并查看详细日志
```bash
cd /Users/hoinyan/HiddifyWithPanels
./build/macos/Build/Products/Debug/Hiddify.app/Contents/MacOS/Hiddify
```

### 重新构建应用
```bash
flutter clean
flutter pub get
flutter build macos --debug
```

### 检查配置文件
```bash
# 查看生成的配置文件位置
find ~/Library/Containers/app.hiddify.com/Data -name "*.yaml" -o -name "*.json"
```

## 🔍 关键日志标识

监听这些日志来确认功能正常：

1. **登录成功**: `Token stored:`
2. **订阅获取**: `获取到订阅链接:`
3. **订阅解析**: `处理订阅内容，长度:`
4. **配置转换**: `检测到Clash YAML格式` 或 `成功解析 X 个代理配置`
5. **核心初始化**: `ClashAdapterService初始化完成`

## 🚀 下一步测试

1. **连接测试**: 尝试连接不同的节点
2. **速度测试**: 检查节点延迟和速度
3. **规则测试**: 验证代理规则是否生效
4. **稳定性测试**: 长时间运行测试

## 📞 如果问题持续存在

请提供以下信息：
1. 完整的日志输出
2. 订阅链接返回的内容（前100字符）
3. 应用界面截图
4. 错误发生的具体步骤

---

**当前版本**: 已修复API URL、订阅解析、用户服务集成、Hysteria2协议支持
**测试状态**: 应用已重新构建并启动，订阅解析测试通过（40个节点）
**最新修复**: 支持Hysteria2和Shadowsocks协议，Base64解码正常
