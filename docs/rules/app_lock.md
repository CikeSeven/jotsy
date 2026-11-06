# 应用锁、应用密码与身份验证

- 必须：验证身份只经 `IdentityVerifier`（`lib/ui/app_lock/controllers/identity_verifier.dart`，`identityVerifierProvider`）。验证方式是全局的一个设置：设了应用密码就用应用密码，否则用系统验证（指纹、面容或锁屏密码，`DeviceAuthService` → local_auth）。应用锁、上锁的日记本（进入、编辑、合并、删除与重锁遮罩）与局域网配对确认都经这里。
- 禁止：在 `lib/ui/app_lock/` 与 `device_auth_service.dart` 之外读 `deviceAuthServiceProvider`、使用 `DeviceAuthService` 或引入 local_auth（`test/ui/app_lock/app_lock_source_test.dart` 兜底）：这样的代码在应用密码方式下仍会弹系统验证，在 Linux 上则直接打不开。
- 必须：页面里的验证用 `IdentityVerifier.verify(context, …)`，应用密码方式下打开 `AppPasswordVerifyPage`。锁屏遮罩（`AppLockOverlay`、`NotebookLockLayer`）挂在 Navigator 之上，打不开页面：密码方式下遮罩里直接放 `AppPasswordView`，系统方式下用 `verifySystem`。遮罩里的输入框必须套在 `AppLockSurface` 里，它补上 `Material` 与 `Overlay.wrap`，否则 TextField 的选区手柄与菜单会报错。遮罩里也不能弹对话框（`showAppDialog` 需要 Navigator），说明一律原地展开。
- 必须：验证分两种用途。`IdentityPurpose.unlock`（解锁、进入日记本、配对）在开着快捷解锁时允许指纹 / 面容；`IdentityPurpose.sensitive`（关闭应用锁、切换验证方式、修改密码）只认应用密码，防止拿到已解锁手机的人借机主的指纹改掉密码。会削弱保护的改动都要先按当前方式验证：
  - 系统验证 → 应用密码：先做一次系统验证，设备没有系统验证时直接设置；
  - 应用密码 → 系统验证：先输入密码，且设备必须能弹出系统验证，通过后清除密码；
  - 打开指纹快捷解锁：先验一次指纹。关闭不用验证。
- 必须：应用密码只存本机，放在单个 JSON 键 `app.security.app_password`（`AppPasswordStore`，与 `AiProviderStore` 同样和 SettingsService 分离），不随备份导出，也不参与局域网同步。设置页那一条仍然是 `appLockEnabled`：它随备份，不同步。“方式”不单独存：有有效的摘要即为应用密码，摘要无效或缺失即为系统验证，不会出现方式与密码对不上的状态。存储加载失败时按系统验证处理，仍然要验证。
- 必须：摘要只经 `AppPasswordHasher`：PBKDF2-HMAC-SHA256，16 字节随机盐，默认 6 万次迭代，在 `Isolate.run` 里计算，常数时间比较。迭代次数随摘要保存，以后调高只影响新设的密码。测试经 `appPasswordHasherProvider` 换成不进 isolate、低迭代的实例。
- 必须：输错限流：第 5 次输错起依次要等 30 秒、1 分、5 分，之后每次 15 分。次数与截止时刻写在同一个键里，杀进程不会清零；系统时钟往回调时，截止时刻收回到“现在 + 当前档位”。输对或指纹通过后清零。界面倒数与存储共用 `appPasswordClockProvider`。
- 必须：密码规则：4–16 个字符（按码点计），区分大小写，不能有空白。没有找回途径（用户的决定），设置页与锁屏上的“忘记密码？”都要明确说明：只能清除应用数据或重装，再从备份恢复。
- 必须：应用密码输入框只用 `AppPasswordField`：关掉建议与输入法学习，`autofillHints` 显式为 null（TextField 默认的空列表仍会让 Android 提示保存密码），`obscureText` 可切换。系统因此弹出密码键盘，这对真正的密码是预期行为，与普通输入框“用普通键盘”的约定不冲突。
- 必须：平台差异只经 `AppPlatform`。`supportsDeviceAuth`（系统验证）不含 Linux；`supportsBiometricOnly`（只认生物识别的快捷解锁）只有 Android、iOS、macOS，Windows Hello 不支持 `biometricOnly`。“这台设备能不能上锁”看 `identityVerificationPossible`：设了应用密码，或平台有系统验证。Linux 设了应用密码后，应用锁与上锁日记本都能用。
- 必须：设置入口为 设置 → 数据与隐私 → 应用锁与密码（`SettingsAppLockTile` → `AppLockSettingsPage`），操作编排在 `AppLockSettingsFlow`，界面规格见 DESIGN.md §5.31。
