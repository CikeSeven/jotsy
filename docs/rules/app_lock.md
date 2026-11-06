# 应用锁、应用密码与身份验证

- 必须：验证身份只经 `IdentityVerifier`（`lib/ui/app_lock/controllers/identity_verifier.dart`，`identityVerifierProvider`）。验证方式是全局的一个设置：设了应用密码就用应用密码，否则用系统验证（指纹、面容或锁屏密码，`DeviceAuthService` → local_auth）。应用锁、上锁的日记本（进入、编辑、合并、删除与重锁遮罩）与局域网配对确认都经这里。
- 禁止：在 `lib/ui/app_lock/` 与 `device_auth_service.dart` 之外读 `deviceAuthServiceProvider`、使用 `DeviceAuthService` 或引入 local_auth（`test/ui/app_lock/app_lock_source_test.dart` 兜底）：这样的代码在应用密码方式下仍会弹系统验证，在 Linux 上则直接打不开。
- 必须：应用密码有两种形式，设置时三选一（`PasscodeForm`）：6 位数字、4 位数字、3×3 图案（至少连 4 个点，越过的中间点自动补上，与系统图案锁一致）。数字一律在应用内的数字键盘（`PasscodeKeypad`）上输入，输满即核对，不弹系统键盘、不用输入框（这是锁屏本身的输入方式，不违反“输入框用普通键盘”的约定）；桌面可直接用实体键盘的数字键、小键盘与 Backspace。图案抬手即核对，少于 4 个点只提示、不算输错。
- 必须：页面里的验证用 `IdentityVerifier.verify(context, …)`，应用密码方式下打开 `PasscodeVerifyPage`。锁屏遮罩（`AppLockOverlay`、`NotebookLockLayer`）挂在 Navigator 之上，打不开页面：应用密码方式下遮罩里直接放 `PasscodeUnlockView`（外框 `AppLockSurface` 补上 `Material` 与 `Overlay.wrap`），系统方式下用 `verifySystem`。遮罩里不能弹对话框（`showAppDialog` 需要 Navigator），说明一律原地展开。
- 必须：验证分两种用途。`IdentityPurpose.unlock`（解锁、进入日记本、配对）在开着快捷解锁时允许指纹 / 面容；`IdentityPurpose.sensitive`（关闭应用锁、切换验证方式、修改密码）只认应用密码，防止拿到已解锁手机的人借机主的指纹改掉密码。会削弱保护的改动都要先按当前方式验证：
  - 系统验证 → 应用密码：先做一次系统验证，设备没有系统验证时直接设置；
  - 应用密码 → 系统验证：先输入应用密码，且设备必须能弹出系统验证，通过后清除密码；
  - 修改密码（可以换形式）：先输入当前密码；
  - 打开指纹快捷解锁：先验一次指纹。关闭不用验证。
- 必须：应用密码只存本机，放在单个 JSON 键 `app.security.passcode`（`AppPasscodeStore`，与 `AiProviderStore` 同样和 SettingsService 分离），不随备份导出，也不参与局域网同步。设置页那一条仍然是 `appLockEnabled`：它随备份，不同步。“方式”不单独存：有有效的摘要即为应用密码，摘要、形式或位数无效即为系统验证，不会出现方式与密码对不上的状态。存储加载失败时按系统验证处理，仍然要验证。形式与数字位数明文保存（界面要据此画圆点或九宫格）。
- 必须：摘要只经 `AppPasscodeHasher`：PBKDF2-HMAC-SHA256，16 字节随机盐，默认 6 万次迭代，在 `Isolate.run` 里计算，常数时间比较；原文为 `AppPasscodeRules.material`（形式前缀 + 数字串或图案格子序号）。迭代次数随摘要保存，以后调高只影响新设的密码。测试经 `appPasscodeHasherProvider` 换成不进 isolate、低迭代的实例。数字密码取值空间小，真正挡住乱试的是下面的限流。
- 必须：输错限流：第 5 次输错起依次要等 30 秒、1 分、5 分，之后每次 15 分。次数与截止时刻写在同一个键里，杀进程不会清零；系统时钟往回调时，截止时刻收回到“现在 + 当前档位”。输对或指纹通过后清零。界面倒数与存储共用 `appPasscodeClockProvider`。上锁日记本的重锁遮罩在应用密码方式下不按“连续两次”退回全部日记，由这里统一限流。
- 必须：没有找回途径（用户的决定），设置页底部与锁屏上的“忘记密码？”都要明确说明：只能清除应用数据或重装，再从备份恢复。
- 必须：平台差异只经 `AppPlatform`。`supportsDeviceAuth`（系统验证）不含 Linux；`supportsBiometricOnly`（只认生物识别的快捷解锁）只有 Android、iOS、macOS，Windows Hello 不支持 `biometricOnly`。“这台设备能不能上锁”看 `identityVerificationPossible`：设了应用密码，或平台有系统验证。Linux 设了应用密码后，应用锁与上锁日记本都能用。
- 必须：设置入口为 设置首页「数据与安全」组 → 应用锁与密码（`SettingsAppLockTile` → `AppLockSettingsPage`），操作编排在 `AppLockSettingsFlow`，输入状态在 `PasscodeEntryController`（解锁）与 `PasscodeSetupController`（两步设置），界面规格见 DESIGN.md §5.31。
