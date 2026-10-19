# SC520CS 暗红区域检测后继报告（2026-10-19）

暗红后继候选已完成记录所述模块回归、工具构建和 bitstream 生成。板级检测召回、实景误报和连续运行均为 not tested。2026-10-19 构建记录未包含硬件下载或 Flash 写入。

## 候选范围与设计方案

- 候选：qa/sc520cs_dark_red_trial_20261019（本地证据：`qa/sc520cs_dark_red_trial_20261019/RELEASE_DARK_RED.md`）。仅R最低门槛144→96；AE/AWB、Logo、四模式、48色差、64/48密度、160区域支持量、3入/2出迟滞保持。
- 验证：14组继承回归及11项暗红/空间/叠加/Logo测试通过；源码与夹具绑定通过。模型时序setup/hold为+0.013/+0.021ns，TNS均0；36条灰码仍7.2ns，红色邮箱34个存活物理位仍12ns。裕量较stable减小，不能等同板级稳定性。
- bitstream：sc520cs_dark_red.bit（本地证据：`qa/sc520cs_dark_red_trial_20261019/run_bitgen_red_checked/sc520cs_dark_red.bit`），1789539字节。
- SHA-256：`59BCAE9C6CA407B3E685DC84954E2BF7CDDE65891C946F16CE9A6EE1CB677B9F`。
- 分级排除分析和接口契约（本地证据：`qa/sc520cs_dark_red_trial_20261019/DIAGNOSIS_DARK_RED.md`）、上板步骤（本地证据：`qa/sc520cs_dark_red_trial_20261019/BOARD_TEST_GATE.md`）、完整结果（本地证据：`qa/sc520cs_dark_red_trial_20261019/RELEASE_DARK_RED.md`）。

## 问题背景与证据边界

2026-10-19 分析的45.433秒视频为AWB A，AE请求随场景变化，并非持续最大；REQ/DON不得当作传感器实时读回。屏摄没有源RGB和逐级计数，实际苹果在哪一级被排除仍不能确定；此次仅根据源码机制和受控刺激降低最低R门槛，没有从屏摄拟合阈值。部分红棕/肤色仍可能混淆。

## 验证方法与结果

验证采用原 stable 与暗红后继同输入对照、1280×720 区域参考模型和继承回归。以下数值来源于本地 `RELEASE_DARK_RED.md` 与 `dark_release_summary.json`，不表示本次重新执行。

|检查|记录结果|范围|
|---|---|---|
|暗红对照|65 帧、147 项检查、0 错误|包含颜色、密度、支持量、迟滞及异常场景|
|1280×720 空间回归|29 主帧、4,615,435 项检查、0 错误|覆盖原异常扩展反例、边界和恢复|
|继承与专项回归|14 组继承回归、11 项专项测试通过|包括稳定性、OSD 与 Logo，模型边界见原记录|
|Logo|3,795,937 项检查、0 错误|像素级叠加验证|
|最终时序|setup/hold WNS +0.013/+0.021 ns，TNS 均 0|已建模覆盖率 98.95%，不构成板级可靠性证明|
|物理资源|LUT6 17030、REG 18397、Slice 18215、ERAM 42、DSP 17|该候选最终 `route.area` 口径|
|跨域约束|36 条 Gray 路径保持 7.2 ns；34 个物理邮箱位保持 12 ns|最小裕量分别为 +5.884 ns 和 +11.189 ns；逻辑数据包仍为 57 位|

65 帧对照中的合成像素不等同于视频源 RGB 测量。当前证据不能确定实际目标在颜色、密度或区域支持量中的具体排除层级。降低最低 R 门槛可能增加红棕色或部分肤色误报，真实召回与误报须单独板测。原候选存在边界扩展历史，后继的仿真修复证据不能替代实际效果确认。

## 证据索引与来源

本文依据本地候选中的 `RELEASE_DARK_RED.md`、`DIAGNOSIS_DARK_RED.md`、`dark_release_summary.json`、`red_regression_final.json` 及 `run_bitgen_red_checked/bitstream_manifest.json`。2026-10-19 根据本地记录补充该候选说明，仅交叉核对上述文件及产物，未重新执行仿真或构建。所有相关原始文件保持原样。

## 后续验证计划

原 stable、project/vendor 及 `release/current.json` 保留原样。板级测试负责人核对 SHA-256 后，通过 JTAG/SRAM 配置并复位，选择彩色模式、AWB A，固定灯光比较未补光、补光和撤光条件；随后检查暗灰/黑色、肤色、零散红点、边界及目标消失场景，并验证 Logo、四模式和20分钟连续运行。出现新增误报或其他回归时，恢复同一 stable 文件并保留异常记录。
