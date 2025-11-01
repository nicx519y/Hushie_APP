# 自定义 Analytics 事件文档

本文档汇总了当前 App 中所有通过 `AnalyticsService().logCustomEvent(...)` 上报的自定义事件，包括事件名称、触发条件、参数说明、典型场景与实现位置，便于产品、研发与数据分析对齐和维护。

## 目录
- 引导进入主页（Onboarding → Main）
- 订阅流程（Subscribe Flow）
- 音频播放（Audio Play）
- 搜索与列表点击（Search & Lists）
- 首页点击（Home Page）
- 网络与 HTTP 状态（Network & HTTP）
- 事件命名与参数规范

---

## 引导进入主页（Onboarding → Main）

- 事件：`onboarding_submit_enter_home`
  - 触发条件：用户在引导页完成提交后进入 `MainLayout`。
  - 典型场景：`OnboardingPage` → （可能进入 `SubscribePage`）→ `MainApp` → `MainLayout`。
  - 参数：
    - `timestamp`：毫秒时间戳。
    - `source`：固定为 `'submit'`。
  - 实现位置：`lib/layouts/main_layout.dart`（`_reportOnboardingEnterFromParam`）。

- 事件：`onboarding_returning_enter_home`
  - 触发条件：已是返回用户（Returning User）从引导检查直接进入 `MainLayout`。
  - 典型场景：`OnboardingPage` → `MainApp` → `MainLayout`。
  - 参数：
    - `timestamp`：毫秒时间戳。
    - `source`：固定为 `'returning_user'`。
  - 实现位置：`lib/layouts/main_layout.dart`（`_reportOnboardingEnterFromParam`）。

说明：
- 为避免在中途进入 `SubscribePage` 时丢失来源，`onboardingEnterSource` 通过路由参数贯穿传递到 `MainLayout`，由 `MainLayout.initState()` 一次性上报。
- 相关传递链路：`OnboardingPage` → `SubscribePage(onboardingEnterSource)` → `MainApp(onboardingEnterSource)` → `MainLayout(onboardingEnterSource)`。

---

## 订阅流程（Subscribe Flow）

- 事件：`subscribe_flow_start`
  - 触发条件：Google Play 购买流程开始（`PurchaseEventType.purchaseStarted`）。
  - 参数：
    - `product_id`：字符串，商品 ID。
    - `base_plan_id`：可选，基础计划 ID。
    - `scene`：可选，发起场景（如 `'unknown'` 或调用处传入）。
    - `timestamp`：毫秒时间戳。
  - 实现位置：`lib/components/subscribe_options_logic.dart`（`_handlePurchaseEvent`）。

- 事件：`subscribe_result`（成功）
  - 触发条件：购买成功（`PurchaseEventType.purchaseSuccess`）。
  - 参数：
    - `status`：固定 `'success'`。
    - `product_id`、`base_plan_id?`、`offer_id?`。
    - `purchase_token?`：可选，交易 Token。
    - `currency`：三字母货币代码。
    - `price`：数值，价格。
    - `timestamp`：毫秒时间戳。
  - 实现位置：`lib/components/subscribe_options_logic.dart`（`_handlePurchaseSuccess`）。

- 事件：`subscribe_result`（失败）
  - 触发条件：购买失败（`purchaseFailed`）、购买错误（`purchaseError`）、或购买流程抛异常。
  - 参数：
    - `status`：固定 `'failed'`。
    - `product_id`、`base_plan_id?`、`offer_id?`。
    - `error_message?`：可选，失败或异常信息。
    - `timestamp`：毫秒时间戳。
  - 实现位置：`lib/components/subscribe_options_logic.dart`（`_handlePurchaseFailure`、`_handlePurchaseError`、`_initiateGooglePlayBillingPurchase` 异常分支）。

- 事件：`subscribe_result`（取消）
  - 触发条件：购买取消（`PurchaseEventType.purchaseCanceled`）。
  - 参数：
    - `status`：固定 `'canceled'`。
    - `product_id`、`base_plan_id?`、`offer_id?`。
    - `timestamp`：毫秒时间戳。
  - 实现位置：`lib/components/subscribe_options_logic.dart`（`_handlePurchaseCanceled`）。

- 事件：`in_app_purchase`
  - 触发条件：购买成功后，手动上报一次通用购买事件（与 Firebase `logPurchase` 呼应）。
  - 参数：
    - `value`、`currency`、`price`、`quantity`。
    - `transaction_id?`：可选。
    - `items`：数组，包含 `item_id`、`item_name`、`price`、`quantity`。
    - `product_id`、`base_plan_id`、`offer_id?`。
    - `source`：固定 `'client_manual'`。
  - 实现位置：`lib/components/subscribe_options_logic.dart`（`_handlePurchaseSuccess`）。

---

## 音频播放（Audio Play）

- 事件：`audio_real_play`
  - 触发条件：开始播放后，实际播放进度相对起始进度达到 ≥ 2 秒，且每次打开 App 只上报一次（防抖与一次性标记）。
  - 参数：
    - `audio_id`、`audio_title`。
    - `start_position_ms`：起始进度（毫秒）。
    - `position_ms`：当前进度（毫秒）。
    - `delta_ms`：播放的实际时间差（毫秒）。
    - `timestamp`：毫秒时间戳。
    - `source`：固定 `'audio_service'`。
  - 实现位置：`lib/services/audio_service.dart`（`positionStream` 监听逻辑）。

说明：
- 该事件用于衡量“真实播放”（非瞬时点击），通过 ≥ 2s 的门槛进行过滤。
- 事件只在本次应用会话中上报一次（`_realPlayReported` 标记）。

---

## 搜索与列表点击（Search & Lists）

- 事件：`search_result_audio_tap`
  - 触发条件：在搜索页点击搜索结果中的音频项。
  - 参数：
    - `audio_id`：音频 ID。
  - 实现位置：`lib/pages/search_page.dart`（`_onSearchItemTap`）。

- 事件：`player_histroy_audio_tap`（拼写为 `histroy`，与现有代码保持一致）
  - 触发条件：在播放历史弹窗中点击音频项。
  - 参数：
    - `audio_id`：音频 ID。
  - 实现位置：`lib/components/audio_history_dialog.dart`（列表项点击）。

- 事件：`me_history_audio_tap`
  - 触发条件：在个人页历史列表点击音频项。
  - 参数：
    - `audio_id`：音频 ID。
  - 实现位置：`lib/pages/profile_page.dart`（`_onHistoryListItemTap`）。

- 事件：`me_likes_audio_tap`
  - 触发条件：在个人页喜欢列表点击音频项。
  - 参数：
    - `audio_id`：音频 ID。
  - 实现位置：`lib/pages/profile_page.dart`（`_onLikesListItemTap`）。

---

## 首页点击（Home Page）

- 事件：`homepage_audio_tap`
  - 触发条件：首页点击音频卡片（包含 For You、其他 Tab）。
  - 参数：
    - `current_tab_name`：当前 Tab 名称（如 `'for_you'`）。
    - `audio_id`：音频 ID。
  - 实现位置：`lib/pages/home_page.dart`（`_onAudioTap`）。

---

## 网络与 HTTP 状态（Network & HTTP）

- 事件：`StatusCode_401`
  - 触发条件：HTTP 请求返回 401 未授权。
  - 参数：
    - `uri`：请求的完整 URI。
    - `timestamp`：毫秒时间戳。
  - 实现位置：`lib/services/http_client_service.dart`（重试与刷新逻辑中）。

- 事件：`Network_Unhealthy`
  - 触发条件：认证相关操作前网络健康检查返回非健康状态。
  - 参数：
    - `status`：网络健康状态的文本描述。
    - `action`：当前正在进行的认证动作描述。
  - 实现位置：`lib/services/auth_manager.dart`（`_ensureNetworkHealthy`）。

- 事件：`Network_Check_Failed`
  - 触发条件：进行网络健康检查过程发生异常。
  - 参数：
    - `action`：当前正在进行的认证动作描述。
    - `error`：异常信息字符串。
  - 实现位置：`lib/services/auth_manager.dart`（`_ensureNetworkHealthy` 异常分支）。

---

## 事件命名与参数规范

- 命名约定：
  - 使用下划线分隔的动宾结构，例如：`homepage_audio_tap`、`subscribe_flow_start`。
  - 结果类事件统一使用 `*_result`，并通过 `status` 区分结果（`success`/`failed`/`canceled`）。
  - 进程/阶段类事件使用 `*_start` 等动词后缀明确阶段。

- 参数约定：
  - 时间统一使用毫秒级时间戳字段 `timestamp`（如需）。
  - ID 字段命名保持一致（`audio_id`、`product_id`、`base_plan_id` 等）。
  - 可选参数在实现中使用条件添加，避免空值上报。
  - 若与 Firebase 的标准电商事件同时使用（如 `logPurchase`），自定义事件可通过 `source` 字段注明来源（如 `'client_manual'`）。

- 去重与一次性：
  - `audio_real_play` 在一次应用会话中仅上报一次（内部标记 `_realPlayReported`）。
  - 引导进入主页事件在 `MainLayout.initState()` 内基于路由参数一次性上报。

---

## 维护与扩展建议

- 在新增自定义事件时：
  - 按上述命名与参数规范执行，并在此文档追加条目。
  - 说明触发场景与防抖、去重策略，确保数据可解释性。
  - 若事件与订阅或电商相关，确认是否需要对齐 Firebase 标准事件。

- 在修改现有事件逻辑时：
  - 注意保持事件名称稳定，避免历史报表断裂。
  - 若必须改名或调整参数，需同步更新数据管道与报表，并在此文档清晰标注变更。