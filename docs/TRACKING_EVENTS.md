# Hushie App 追踪打点说明（Tracking Events Guide）

本文档梳理当前客户端打点实现，包括：事件列表、参数说明、调用逻辑与场景规范，以及调试日志示例，便于开发与排查。

## 统一打点接口
- 基础方法：`TrackingService.track({ required String actionType, String? audioId, Map<String, dynamic>? extraData })`
- 真实上报：`_postTracking({ required String actionType, String? audioId, Map<String, dynamic>? extraData })`
- HTTP 请求：向 `ApiEndpoints.tracking` 发送 `POST JSON`，请求体包含：
  - `action_type: string`（必填）
  - `audio_id: string`（选填）
  - `extra_data: object`（选填）
- 超时：`ApiConfig.defaultTimeout`
- 调试日志（示例）：
  - `📍 [TRACKING] POST <url>`
  - `📍 [TRACKING] body keys: [action_type, audio_id?, extra_data?]`
  - `📍 [TRACKING] status: <statusCode>`
  - `📍 [TRACKING] errNo: <number>`

## 事件列表与参数

### 1) 订阅弹窗展示：`membership_overlay_show`
- 方法：`TrackingService.trackMembershipOverlay({ required String scene })`
- 参数：
  - `scene: string`（来源场景，必填）
- 逻辑：订阅弹窗打开时上报一次
- 典型调用：`SubscribeDialog._sendOpenTracking()`；`showSubscribeDialog(context, scene: 'search'|'me'|...)` 透传给弹窗
- 示例载荷：
```json
{
  "action_type": "membership_overlay_show",
  "extra_data": {"scene": "search"}
}
```

### 2) 订阅点击：`subscribe_click`
- 登录触发：`TrackingService.trackSubscribeClickLogin({ String? scene })`
  - 参数：
    - `scene: string?`（来源场景，可选）
  - 逻辑：用户点击订阅但未登录时上报
  - 典型调用：`SubscribeOptions._onSubscribe()`（判定未登录时）
  - 示例载荷：
```json
{
  "action_type": "subscribe_click",
  "extra_data": {"trigger": "login", "scene": "search"}
}
```

- 支付触发（基础计划/优惠）：`TrackingService.trackSubscribeClickPayment({ String? basePlanId, String? offerId })`
  - 参数：
    - `base_plan_id: string?`
    - `offer_id: string?`
  - 逻辑：点击支付并带上可用的基础计划与优惠标识
  - 典型调用：可在支付前根据选中计划与优惠调用
  - 示例载荷：
```json
{
  "action_type": "subscribe_click",
  "extra_data": {"trigger": "payment", "base_plan_id": "monthly_001", "offer_id": "intro_7d"}
}
```

- 支付触发（含场景）：`TrackingService.trackSubscribeClickPay({ required String scene })`
  - 参数：
    - `scene: string`（来源场景，必填）
  - 逻辑：点击支付时携带来源场景，便于渠道归因
  - 典型调用：`SubscribeOptions._onSubscribe()` 成功进入支付流程前
  - 示例载荷：
```json
{
  "action_type": "subscribe_click",
  "extra_data": {"trigger": "payment", "scene": "onboarding"}
}
```

### 3) 应用进入后台：`app_background`
- 方法：`TrackingService.trackHomeBackground()`；别名：`trackHomeToBackground()`
- 参数：无
- 逻辑：整个应用从前台进入后台时上报，用于计算留存/会话中断
- 典型调用：在全局 `AppRoot` 的 `WidgetsBindingObserver` 中监听 `AppLifecycleState.paused|inactive`
- 示例载荷：
```json
{"action_type": "app_background"}
```

### 4) 主页 Tab 点击：`homepage_tab_tap`
- 方法：`TrackingService.trackHomepageTabTap(String tabName)`；别名：`trackHomeTabTap({ required String tabName })`
- 参数：
  - `tab: string`（Tab 名称，如 `home`、`me`、`search`）
- 逻辑：切换底部导航或主页 tab 时上报
- 示例载荷：
```json
{
  "action_type": "homepage_tab_tap",
  "extra_data": {"tab": "home"}
}
```

### 5) 搜索输入：`search_input`
- 方法：`TrackingService.trackSearchInput({ required String keyword })`
- 参数：
  - `keyword: string`（用户输入的查询词）
- 逻辑：搜索框文本变化或提交时上报（避免高频可做节流）
- 示例载荷：
```json
{
  "action_type": "search_input",
  "extra_data": {"query": "rain", "len": 4}
}
```

### 6) 搜索结果点击：`search_result_tap`
- 方法一（仅结果 ID）：`TrackingService.trackSearchResultTap(String audioId)`
  - 参数：
    - `audioId: string`（结果的音频 ID）
  - 示例载荷：
```json
{
  "action_type": "search_result_tap",
  "audio_id": "a_123456"
}
```

- 方法二（包含查询词与结果 ID）：`TrackingService.trackSearchResultClick({ required String keyword, required String resultId })`
  - 参数：
    - `keyword: string`
    - `resultId: string`（结果 ID）
  - 示例载荷：
```json
{
  "action_type": "search_result_tap",
  "audio_id": "a_123456",
  "extra_data": {"query": "rain"}
}
```

## 场景（scene）规范
- 作用：标识来源场景，便于归因（如用户从哪个入口触发订阅）
- 常见取值：
  - `search`（搜索页内订阅入口）
  - `me`（个人页/会员卡入口）
  - `onboarding`（新手引导结束进入订阅页）
  - `player`（播放页因权限触发订阅弹窗）
  - `home`（首页相关入口）
  - `unknown`（当无法确定来源时）
- 传递路径：
  - 弹窗：`showSubscribeDialog(context, scene: 'search') -> SubscribeDialog.scene -> SubscribeOptions.scene`
  - 订阅页：`SubscribePage(scene: 'onboarding') -> SubscribeOptions.scene`

## 调用位置与逻辑建议
- 订阅弹窗展示：在弹窗 `initState` 中立即上报一次
- 订阅点击（登录）：在按钮点击但用户未登录时上报，并导航登录
- 订阅点击（支付）：在进入支付流程前上报，并携带 `scene` 或 `base_plan_id / offer_id`
- 应用进入后台：在 `AppRoot` 的全局生命周期回调中监听 `paused|inactive` 上报
- 搜索输入：在 `onChanged` 中做节流后上报或在提交时上报
- 搜索结果点击：在结果项点击时上报（可含 `keyword`）

## 调试日志与排查
- 在 `debugPrint` 中可查看：请求 URL、请求体 key、HTTP 状态码与 `errNo`
- 若怀疑某事件未统计：
  - 检查调用是否执行（在调用点临时打印）
  - 检查 `scene` 是否为空或未透传
  - 检查网络请求是否成功返回 200
  - 检查服务端是否正确解析 `action_type` 与 `extra_data`

## 相关代码文件
- 客户端实现：`lib/services/api/tracking_service.dart`
- 常用调用处：
  - 订阅弹窗：`lib/components/subscribe_dialog.dart`
  - 订阅选项：`lib/components/subscribe_options.dart`
  - 订阅页：`lib/pages/subscribe_page.dart`
  - 搜索页：`lib/pages/search_page.dart`
  - 个人页会员卡：`lib/components/premium_access_card.dart`

## 变更记录
- 2025-10-25：初版文档，依据当前实现整理事件、参数与场景规范。
- 2025-10-25：将后台事件改为 `app_background`，并改为在 `AppRoot` 统一上报。