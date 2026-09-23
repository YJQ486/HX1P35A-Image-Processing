# HX1P35A 项目 QA 报告

> 更新日期：2026-09-21  
> 当前阶段：未修改 lab_ex1 的 GUI clean build 结果审计  
> 状态：`pass`、`fail`、`not tested`

## 1. 构建与证据 QA

| 检查项 | 状态 | 证据/说明 |
|---|---|---|
| Tang Dynasty 版本 | pass | 本次日志为 V6.2.168116；`syn_1/run.log`、`phy_1/run.log`。 |
| Device / Top | pass | `PH1P35MDG324` / `design_top_wrapper`；`syn_1/flow.status`。 |
| 源、ADC、SDC 可解析 | pass | elaboration、read_adc、read_sdc、opt_rtl、opt_gate 均完成；`syn_1/run.log`、`flow.status`。 |
| 加密 IP/许可证可用于本工程 | pass | MIPI/DDR/HDMI/FIFO 通过本次完整 build，无 license/decrypt/black-box error。 |
| clean synthesis | pass | setup `+0.860 ns`，hold `+0.114 ns`；`syn_1/camera_to_dsi_display_gate.ts`。 |
| place | pass（中间 hold 违例） | place 后 hold `-0.270 ns`、541 endpoints；后续 fix_hold 已修复。`phy_1/place_flow.status`。 |
| route/fix_hold | pass | setup `+1.408 ns`、hold `+0.020 ns`、TNS=0、违例端点=0；`phy_1/route_flow.status`。 |
| bitgen | pass | `Generate bitstream completely`；`phy_1/run.log` 第 1752–1767 行。 |
| bitstream 可追溯性 | pass | 主 bit：1,789,539 bytes，mtime 2026-09-21 16:38:08.368 +08:00，SHA-256 `5D799F...DD78`。 |
| 构建阻断错误 | pass | 新 `run.logw` 中 ERROR/FATAL=0。 |
| RTL 仿真 | not tested | 未执行。 |
| 上板功能 | not tested | 未 Download、未连接摄像头、未验证 HDMI/DDR。 |
| QSPI 冷启动 | not tested | 未固化、未断电启动。 |

## 2. 约束与时钟 QA

| 检查项 | 状态 | 证据/风险 |
|---|---|---|
| Final setup closure | pass | SWNS `+1.408 ns`，STNS 0；最差为 375.094 MHz `HDMI_SERIAL_CLK`。 |
| Final hold closure | pass（低余量） | HWNS `+0.020 ns`，HTNS 0；MIPI RX/HDMI pixel 的 ERAM 路径达到该最差值。 |
| STA coverage | fail | `95.64%`，不是 100%；`phy_1/final_timing.rpt` 第 8 行。 |
| 未约束对象 | fail | 综合 mapping 报告 109 个 timing-unconstrained PI/PO 对象；最终报告未枚举全部未约束路径，不能判定为 0。 |
| SDC 例外 | fail（待审查） | 两组 `set_max_delay` 各 18 条路径全部被 `set_clock_groups` 忽略；`phy_1/camera_to_dsi_display_exception.timing`。 |
| DDR ref_clk 输入 | fail | DDR IP elaboration 参数 100.0 MHz，但 wrapper 将 50 MHz `I_sys_clk` 接到 `.ref_clk`；构建成功未消除此冲突。 |
| `dhi_clk` 声明 | fail | 本次综合仍报告 undeclared symbol，并按 implicit wire 处理；`syn_1/run.log` 第 230 行。 |
| 相机 24 MHz 时钟树 | fail（上板前） | `PHY-5060` mixed fanout，且 `PHY-5079` 标记 `pll_clk_24m` 使用 local routing。 |
| I2C SCL 时钟树 | fail（上板前） | `PHY-5060` mixed clock/data-control fanout。 |
| PLL clock-to-IO | fail（待确认） | `PHY-5016`×4：PLL clkc 驱动未定位或非 clock-capable IO；需定位具体实例后才能 waiver。 |

## 3. 资源与实现 QA

| 检查项 | 状态 | 结果 |
|---|---|---|
| LUT | pass | 9,865 / 21,216（46.50%） |
| REG | pass | 13,313 / 42,432（31.37%） |
| SLICE | pass | 12,358 / 21,216（58.25%） |
| ERAM | pass | 40 / 108（37.04%） |
| DSP | pass | 8 / 40（20.00%） |
| PLL | pass | 3 / 6（50.00%） |
| GCLK | pass | 9 / 32（28.12%） |
| IO | pass | 58 / 160（36.25%） |
| Routing congestion | pass | place QoR：Top 1% tile avg 76.71%，over-100% tile=0；`phy_1/place.qor`。 |
| Route completion | pass | route/fix_hold、routing DRC、bitgen 均完成；`phy_1/run.log`。 |

“pass”表示未超器件容量或该阶段完成，不代表资源/布局已经优化。

## 4. 警告处置矩阵

| 级别 | 项目 | 状态 | 处置要求 |
|---|---|---|---|
| 阻断 | ERROR/FATAL、license、decrypt、black-box、route/timing violation | pass | 本次未发现。 |
| 上板前 | DDR 100 MHz 参数 / 50 MHz 输入冲突 | fail | 在任何 Download 前按官方 DDR IP 参考设计确认并修正配置或连接；本阶段未修改。 |
| 上板前 | `dhi_clk` implicit wire | fail | 明确声明并核对其与 `O_ddr_clk`/用户接口时钟的语义；本阶段未修改。 |
| 上板前 | STA coverage 95.64% / unconstrained objects | fail | 生成并审查完整未约束路径/端点报告，确认 IO、CDC、generated clock 约束。 |
| 上板前 | 3 条物理 CRITICAL-WARNING | fail | 对 `O_cam_24m`、I2C SCL、`pll_clk_24m` 运行时钟详情分析并确认路由意图。 |
| 上板前 | hold 余量 20 ps | fail（风险） | 在约束覆盖正确后复核 PVT/seed 稳定性；不要仅凭单次正裕量认定稳健。 |
| 上板前 | MIPI/DDR/RAW 关键宽度和 undriven 警告 | fail | 检查 `I_lane_invert`、DDR mask、RAW ready/black-level/FIFO 信号是否为预期截断或禁用分支。 |
| 普通 | 注释嵌套、生成器匿名网、未用端口/位、RAM_STYLE 回退 | pass（需 waiver） | 逐类确认来自未用功能/生成模板后记录 waiver；无需在本基线阶段修改。 |

完整警告统计和代表性位置见 `docs/BASELINE_BUILD_REPORT.md` 第 6 节。

## 5. 工程基线完整性

- RTL、IP 配置 XML、相机寄存器、pin.adc、SDC 的已记录 SHA-256 未变化。
- Tang Dynasty GUI 保存工程时自动把 `.al` 的 `Project Path` 从旧电脑绝对路径改为当前 `D:/FPGA/...`；project `.al` 因这一行与 vendor 不再字节相同。未发现器件、Top、源清单或约束配置变化。
- `vendor/` 未修改、未清理。
- 本阶段未执行 Download、program、SVF/QSPI 或任何板卡操作。

## 6. 当前发布判定

| 发布门槛 | 状态 |
|---|---|
| 可重复构建的基线 bitstream | pass |
| 时序违例为 0 | pass |
| 约束覆盖完整 | fail |
| DDR 输入时钟配置一致 | fail |
| 关键时钟 CRITICAL-WARNING 已关闭 | fail |
| RTL 仿真通过 | not tested |
| 摄像头到 HDMI 上板通过 | not tested |
| QSPI 断电启动通过 | not tested |

当前结论：**可作为构建基线，不可作为已验证上板发布版本。**
