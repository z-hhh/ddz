# 离线斗地主（Flutter 原生 Android / iOS）

简体中文，单机或同平台附近联机。Android：RFCOMM 真蓝牙；iOS：MultipeerConnectivity（系统自动选择蓝牙/点对点 Wi-Fi）。无服务器、无账号、无在线服务。**安卓与 iPhone 不互通**，未实现可选 Wi-Fi TCP 模式。

## 运行与构建

开发环境：Flutter 3.50.0 / Dart 3.14.0、JDK 17、Android SDK 36。依赖只有 Flutter SDK、本地化 SDK 及测试/静态检查工具；未使用蓝牙第三方插件。

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
# debug 构建完成后再按需运行
flutter build apk --release
```

`android/gradle.properties` 限制 Gradle 内存并关闭常驻 daemon。Release 使用 debug 签名供直接安装；正式商店上架必须换签名。iOS 详见 [ios/构建说明.md](ios/构建说明.md)。首次开发构建需要下载 SDK/Maven/Pub 依赖，成品运行离线。

## 玩法

选择简单/普通 → 单机开局。点牌抬起选中，也可横滑连选，“提示”循环候选，“出牌/不出”执行。最高叫分者当地主，任一方先出完获胜；炸弹和王炸翻倍，可选春天翻倍。界面规则页说明本作飞机/四带二的具体约定。

联机先选 2 人或 3 人。房主创建房间并允许系统可发现提示；客人搜索并点房主设备名，安卓必要时按系统界面完成配对。旧版安卓扫描需要位置权限和位置服务。2 人模式第三席由房主本地 AI 顶上。断线时房主暂停并可选择机器人接管；客人接管前可返回菜单重新搜索加入；房主断线则客人本局结束。不要锁屏或切后台。

## 模块

- `lib/game/cards.dart`：54 张牌、点数与花色。
- `lib/game/rules.dart`：识别、比较、合法性；无 Flutter 依赖。
- `lib/game/ai.dart`：按牌组构造候选，支持拆牌、跟牌、提示循环。
- `lib/game/game_state.dart`：发牌、叫分、出牌、轮转、春天、零和结算。
- `lib/game/protocol.dart`：帧编解码、序号防重放、断线超时；无 Flutter 依赖。
- `lib/transport/local_transport.dart`：平台无关 API、MethodChannel/EventChannel 封装。
- `lib/ui/table_controller.dart`：房主权威、客人意图、私有快照、心跳、重连与接管。
- `lib/ui/game_app.dart`：手机横竖屏、规则与房间、退出确认。
- `lib/ui/table_widgets.dart`：程序绘制绒面牌桌、玩家席位、纸牌和横滑选牌手势。
- `android/app/src/main/kotlin/cn/offline/doudizhu/`：安卓权限、发现、RFCOMM 帧流。
- `ios/Runner/BluetoothTransport.swift`：iOS 原生附近会话。
- `test/`：规则、AI、帧、状态机、双人/三人联机模拟、手机布局回归。
- `tool/capture_test.dart`：Linux 测试渲染截图（依赖本机 Noto 中文字体，不影响产品）。

## 通道与线协议

MethodChannel `cn.offline.doudizhu/transport` 提供 `createRoom/discover/join/send/dispose`；EventChannel `cn.offline.doudizhu/events` 推送 `found/connected/message/left/error/scanDone`。`LocalTransport.onMessage/onPeerLeft` 为筛选后的流。

统一消息：**4 字节无符号大端长度 + UTF-8 JSON**，长度 1–262144 字节。安卓用 DataInputStream.readInt/readFully，天然处理半包和粘包；每个 socket 同步发送一整帧，后台读线程分离。读错误/非法长度/JSON/EOF 关闭 socket 并发 left，重连新建 reader，无残帧复用。iOS 的 reliable data 保留消息边界，但同样校验长度前缀和帧总长。

- 房主发送 `welcome {v,session,seat}`；每次合法操作后发送 `state {session,revision,state}`。给每位客人的快照仅含该客人的真实手牌，对手牌以 -1 隐藏。
- 客人发送 `intent {v,session,seq,revision,action,value,cards}`。房主按连接身份绑定座位，检查版本/会话、递增序号和快照版本，然后调用共享状态机验证叫分/出牌/过牌。
- 星型应用协议：客人仅向所选房主发送意图；两客人操作经房主校验后广播私有状态。iOS 底层 MCSession 的拓扑由系统管理，应用层忽略非房主的客户消息。
- 房主每 5 秒发送 ping，客人回 pong；双方 30 秒未收到对端消息判离线。原生连接/搜索阶段也有 30 秒超时。正常局面无强制出牌倒计时。
- 房主保留掉线客人的身份→座位映射并暂停 AI，重连发新 welcome/完整快照并重置该连接序号。用户点机器人接管后释放保留身份；房主掉线则客人终止本局，不做房主迁移。

## 权限与限制

安卓 12+ 运行时申请 BLUETOOTH_CONNECT/SCAN/ADVERTISE；安卓 6–11 申请 ACCESS_FINE_LOCATION，清单旧蓝牙/位置权限限 maxSdkVersion 30。拒绝通过平台错误和 SnackBar 提示，不自动重试。蓝牙关闭/硬件缺失同样提示。房主通过系统可发现界面授权 300 秒，过期后需要重建房间再发现；已配对设备仍可尝试加入。

iOS Info.plist 包含 NSLocalNetworkUsageDescription、NSBonjourServices `_ddz-local._tcp` 和蓝牙用途说明。权限由 Apple 系统控制，错误事件提示设置恢复。

沙箱没有可用手机蓝牙，平台传输的真实发现/配对/多人稳定性未经实机验证。Linux 无 Xcode，iOS Swift 与签名未经编译验证。应用层模拟测试不能替代以上真机验证。没有离线资产外链和在线服务；不做真钱、账号、匹配大厅或跨平台互联。


当前版本 2.1.0：全程双向横屏、左图右入口首页、浅色手绘素材与精简文案。源图与提示词见 design/2.1.0 和随包源图ZIP；双尺寸四界面截图脚本 tool/theme_review_test.dart。
