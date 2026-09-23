# lab_ex1 基线上板就绪性只读审查

审查日期：2026-09-21  
对象：未修改的 `project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi` 及其 2026-09-21 Tang Dynasty 6.2.168116 clean build 产物。  
边界：本次仅阅读源码、生成 IP、约束、官方资料和已有构建报告；未执行 Download、未连接开发板、未改动 RTL/IP/ADC/SDC/工程配置。

为避免重复超长路径，本文使用以下唯一缩写：

- `P` = `project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi`
- `D` = `P/user_source/hdl_source/ph1p35_ddr/ddr2`
- `SYN` = `P/td_project/camera_to_dsi_display_Runs/syn_1`
- `PHY` = `P/td_project/camera_to_dsi_display_Runs/phy_1`
- `O32` = `vendor/official_docs/2_Example/32_cs500_mipi_hdmi`

## 结论

**当前 bitstream 不批准用于短时间基线下载。** 阻断原因不是构建失败，而是 DDR IP 明确按 100 MHz 参考输入生成，实际却由 50 MHz `I_sys_clk` 驱动。实现报告已经把 DDR 时钟推导为配置目标的一半，且按生成参数计算的 PLL0 实际 VCO 约为 533.3 MHz，低于 PH1P 数据手册给出的 800 MHz 下限。另有两个视频异步 FIFO 的 36 条灰码跨域 `set_max_delay` 被顶层 `set_clock_groups` 全部忽略。这两项都必须在把当前设计视为可验证板级基线之前解决。

`SWNS=+1.408 ns`、`HWNS=+0.020 ns` 只证明已被 STA 覆盖的路径通过，不证明 DDR 配置正确，也不覆盖其余 4.36% 时序对象。依据：`project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display_Runs/phy_1/final_timing.rpt:8,25-29`。

## 1. DDR `PLL0_REFCLK_FREQ=100.0` 的准确含义

### 1.1 配置到原语的证据链

1. DDR IP 配置同时写明参考输入 100 MHz、DDR2-1066、`tCK=1876 ps`、双 PLL：
   - `PH1P_SINGLE_PLL=0`、`PH1P_REF_CLK=100.0000`、`PH1P_DDR_SPEED=1066.00`：`project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/ph1p35_ddr/ddr2/Design.xml:13-15`
   - `tCK=1876`：同文件 `:49`
   - `PLL0_REFCLK_FREQ=100.0`、`REFCLK_DIV=3`、`FBKCLK_DIV=32`、`CLK2_DIV=2`、`CLK3_DIV=21`：同文件 `:83-89`
   - `PLL1_REFCLK_FREQ=133.3`、`REFCLK_DIV=4`、`CLK0_DIV=12`：同文件 `:90-92`
2. 生成的时钟顶层把外部 `ref_clk` 直接接入 PLL0，并把 PLL0 `clkc[0]` 送到 PLL1：`D/src/rtl/clk/ph1p_ddrphy_clk_top.v:49-75`。
3. `PLL0_REFCLK_FREQ` 被传给 `ph1p_ddrphy_pll0.REFCLK_FREQ`，随后直接送入器件 PLL 原语参数 `.FIN(REFCLK_FREQ)`；实际时钟端口同时直接接到 `.refclk(refclk)`：`D/src/rtl/clk/ph1p_ddrphy_pll0.v:10-16,92,101-102,200-201`。
4. 官方 DDR 手册把 **PLL Reference Clock Frequency** 定义为“PLL 的输入参考时钟频率”，并用 100 MHz 输入对应 `create_clock -period 10`；依据：`vendor/official_docs/6_PH1P35数据手册/参考IP设计资料文档/IPUG035_安路PH1A系列FPGA DDR IP用户手册.pdf`，PDF 第 14 页（印刷页 13）。该手册是 PH1A 系列，故只用来确认参数语义和通用时钟结构，不替代缺失的 PH1P 专用 DDR 用户手册。
5. PH1P 数据手册把 PLL 参数 `FIN` 定义为“输入时钟频率”；依据：`vendor/official_docs/6_PH1P35数据手册/DS1300_PH1P_Datasheet.pdf`，PDF 第 77 页（印刷页 71），表 3-45。

因此，`PLL0_REFCLK_FREQ=100.0` 是送入 PLL0 `refclk` 引脚的**物理输入频率声明**，不是 DDR 输出频率、目标频率标签或可与实际输入无关的注释。

### 1.2 当前实际连接与实现结果

- 外层 DDR wrapper 把 `I_sys_clk` 直接接到 DDR IP `ref_clk`：`P/user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v:79`。
- 顶层把板级 `I_sys_clk` 直接送入该 wrapper：`P/user_source/hdl_source/design_top_wrapper.v:757-759`。
- 工程约束把 `I_sys_clk` 定义为 20 ns，即 50 MHz：`P/td_project/camera_to_dsi_display.sdc:1`；管脚为 C4：`P/user_source/constraints_source/pin.adc:2`。
- 原理图另有 K5/L5 的 `FPGA_DDR_100MHZ_LVDS_P/N` 差分 100 MHz 时钟；依据：`vendor/official_docs/3_原理图/开发板原理图/HX1P35B_FT_40P_2.pdf`，PDF 第 1 页、印刷图纸第 2/11 页。当前顶层与 `pin.adc` 没有使用这对输入。
- 实现工具从 50 MHz 主时钟实际推导出 PLL0 `clkc[0:1] = 66.667 MHz`、`clkc[2] = 266.667 MHz`、PLL1 `clkc[0] = 66.667 MHz`：`PHY/run.log:124-132`；最终报告同样列出 `usr_clk/ref_clk/ctl_clk=66.667 MHz`、`ddr_clk=266.667 MHz`：`PHY/final_timing.rpt:35-50,53-67`。

按生成的 `REFCLK_DIV=3`、`FBKCLK_DIV=32`，若物理输入为 100 MHz，PLL0 VCO 为约 1066.7 MHz；当前 50 MHz 输入则只有约 533.3 MHz。PH1P35 的 PLL VCO 允许范围为 800–1600 MHz；依据：`DS1300_PH1P_Datasheet.pdf`，PDF 第 77 页（印刷页 71），表 3-45。虽然同表说明 50 MHz 本身位于 `FIN=10–600 MHz` 的通用输入范围内，但这不能使“原语声明 100 MHz、实际输入 50 MHz”的组合合法；当前分频/倍频、DDR 时序参数和训练数据均是按 100 MHz/DDR2-1066 生成的。

**判定：这是已确认的真实配置错误，并且是当前上板阻断项。** clean build 和 PLL 静态推导不会验证上电锁定、DDR 初始化或校准成功。

## 2. `dhi_clk`、`O_ddr_clk` 的真实关系

### 2.1 产生位置与频率

- PLL0 `clkc[0]` 作为 PLL1 的 `refclk`：`D/src/rtl/clk/ph1p_ddrphy_clk_top.v:67-75`。
- PLL1 `clkc[0]` 被赋给 `dhi_clk`：同文件 `:137-138`。
- DDR IP SDC 把 PLL1 `clkc[0]` 重命名为 `usr_clk`：`D/src/sdc/ddr2.sdc:9-10`。
- 本次最终实现中的 `usr_clk` 为 **66.667 MHz**：`PHY/final_timing.rpt:38,55`。因此当前 `dhi_clk` 和外部导出的 `O_ddr_clk` 均为 66.667 MHz；它们不是板上 100 MHz DDR 差分参考时钟。

官方通用时钟结构说明 PLL0 产生 PHY 并行/串行时钟，PLL1 产生 DFI/用户逻辑相关时钟，PLL0 给 PLL1 提供参考；依据：`IPUG035_安路PH1A系列FPGA DDR IP用户手册.pdf`，PDF 第 32–33 页（印刷页 31–32），3.5 节和图 3-2。由于该文档针对 PH1A，`dhi_clk` 名称本身仍以本工程生成 RTL 为准。

### 2.2 用途与扇出

- 在 DDR IP 内，`dhi_clk` 驱动 PHY-to-MC 读 FIFO 和内存控制器：`D/src/rtl/top/ph1p_ddrmc_top.v:277-309`。
- 它还作为 PHY 字节逻辑的用户时钟及训练/数据通路时钟：`D/src/rtl/phy/ph1p_ddrphy.v:531,606`、`D/src/rtl/phy/ph1p_ddrphy_top.v:439-660`。
- 外层 wrapper 直接执行 `assign O_ddr_clk = dhi_clk`：`P/user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v:61`。
- 顶层把 `O_ddr_clk` 接成 `S_ddr_clk`，再驱动 `video_in`、`video_out`、`mc_to_user_interface` 以及 DDR 调试状态寄存器：`P/user_source/hdl_source/design_top_wrapper.v:234-304,363-402,672-761`。
- 校准完成输出只是 `ddrphy_rdy` 的直连：`P/user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v:60`；当前没有上板读到该信号，不能声称校准已通过。

### 2.3 隐式 wire

`ph1p35_324_ddr_wrapper.v` 使用了 `dhi_clk`，但没有显式声明；综合器在本次构建中将其假定为默认 `wire`：`SYN/run.log:230`。它不会改变上述连线和频率，但会掩盖拼写/宽度错误，属于应修复的 RTL 质量问题；它不是本次 DDR 频率减半的成因。

## 3. 4.36% 未覆盖与 109 个 unconstrained PI/PO

### 3.1 能确认的事实

- routed STA 覆盖率为 95.64%，即有 4.36% 时序对象未被覆盖：`PHY/final_timing.rpt:8`。
- 综合映射阶段报告 `7602 PI 5003 PO (109 timing unconstrained)`：`SYN/run.log:1193-1197`。
- 这两个数字来自不同阶段、不同统计口径；现有报告没有给出 109 个对象的逐项名称，也不能把“4.36%”直接换算成“109”。`final_timing.rpt` 只列已分析的 clock/path group，没有未约束对象清单。

### 3.2 已定位的约束空洞

1. 顶层 SDC 只创建 `I_sys_clk` 与 MIPI pad clock，并对派生时钟重命名、分组；整个工程所有 SDC 中都没有 `set_input_delay` 或 `set_output_delay`：`P/td_project/camera_to_dsi_display.sdc:1-17`，以及 `D/src/sdc/ddr2.sdc:1-12`。因此复位、按键、相机 I2C/控制、HDMI 输出以及部分专用 MIPI/DDR I/O 不会自动获得普通外部 I/O 时序要求；其中专用硬核 I/O 可能由 IP 模型覆盖，但现有报告未逐项证明。
2. 相机 I2C 内部 `scl_clk` 是由 24 MHz 域中的寄存器分频产生，并直接用于多个 `posedge/negedge scl_clk` 时序块：`P/user_source/hdl_source/uics500_cfg/uii2c.v:72-81,109-188`。顶层以 `.CLK_DIV(24000000/100000-1)` 例化它：`P/user_source/hdl_source/design_top_wrapper.v:517-525`。该 fabric-generated clock 未出现在 SDC 或最终 Clock Summary 中，且 PHY 报告把它列为无时钟名的局部时钟网络：`PHY/route_clock_utilization.txt:61,71,199,242`。这很可能构成 109 个未约束对象的一部分，但报告没有逐项映射，不能给出精确数量。
3. 两个 `w128_d512_fifo` 分别跨越相机→DDR 和 DDR→HDMI：`P/user_source/hdl_source/video_in.v:55-65`、`P/user_source/hdl_source/video_out.v:137-151`。FIFO IP 自带的灰码指针 `set_max_delay` 位于 `P/user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl:1-17`，但最终 exception report 显示两组各 18 条、共 36 条约束均被顶层 `set_clock_groups` 覆盖并 **100% Ignored**：`PHY/camera_to_dsi_display_exception.timing:24-31,44-59`。这不属于“未声明时钟”的 109 个对象清单，但属于必须单独解决的 CDC 约束失效。

### 3.3 判定

- 正的 setup/hold 裕量仅适用于已覆盖且未被更高优先级例外忽略的路径。
- 在未生成 `report_unconstrained_paths`/等效 GUI 明细前，109 个对象的完整名称与 4.36% 的精确构成均为“仍未确认”。本次审查没有启动工具重新分析，以遵守只读现有产物的边界。
- 已确认的 `scl_clk` 未约束及 36 条 FIFO 灰码最大延迟被忽略，均应在正式上板验收前修复并重新 clean build。

## 4. PHY 警告定位与分级

| 警告 | 已定位网络 | 证据 | 判定 |
|---|---|---|---|
| `PHY-5060` | `O_cam_24m_syn_3`：120 个 clock sink + 1 个 data/control sink；`u_uicfgcs500/u_i2c/scl_clk`：1 个 clock sink + 2 个 data/control sink | `PHY/run.log:138-139` | 两者均为真实 mixed-fanout。`scl_clk` 同时作为内部时钟和生成 SCL 数据是 RTL 所写；`O_cam_24m` 同时送相机 pad 和内部 24 MHz 逻辑。不是工具误报。 |
| `PHY-5079` | 被标记的局部路由是 `pll_clk_24m` 的 `O_cam_24m_dup_1_created_gclkinst_auto_created_sclk_s_0_l_bk5_sclk_outnet`，80/81 clock/fanout、3 段 local wire；另一个未标记局部网络是 `u_uicfgcs500/u_i2c/scl_clk`，1/3、13 段 local wire | `PHY/run.log:1584-1596`；`PHY/route_clock_utilization.txt:70-71,239-242` | `O_cam_24m` 的 marked critical warning 需在上板前消除或获得工具/厂商可接受性说明。24 MHz 域在已覆盖路径上的裕量为 setup +37.028 ns、hold +0.022 ns，但这不覆盖其输出 pad 和所有 mixed-fanout 用法：`PHY/final_timing.rpt:41,58`。 |
| `PHY-5016` | 警告文本不携带网络名。它紧接在 DDR PLL0 `clkc[1]`→`u_mlclk_1` 和 `clkc[2]`→`u_mlclk_2` 的放置记录之后；这两个拓扑及 sink 名称见 `PHY/run.log:176-211`。DDR IP ADC 实际给 PLL、MLCLK、IOCLK 都指定了位置：`D/src/adc/ddr2.adc:52-62`。 | `PHY/run.log:198-211` | 只能把范围收敛到该放置阶段，不能从现有报告证明四条文本分别属于哪一条 net。顶层 PLL 的用户位置在 clock utilization 中也为 `None`，且 `O_cam_24m` 是直接 PLL→pad 的候选；现有证据不足以在两者之间作唯一归属。标记“仍未确认”，不单独据此声称板卡必然失败。 |

补充证据：顶层 `S_24m_clk` 来自 `u_PLL.clk1_out`，同时直接赋给 `O_cam_24m` 并驱动相机配置/AE：`P/user_source/hdl_source/design_top_wrapper.v:248-253,482-520`；`O_cam_24m` 固定到 L3：`P/user_source/constraints_source/pin.adc:7`。路由 DRC 报告“无多驱动、无异常时序路径、Bound Check Pass”：`PHY/run.log:1582-1605`。这说明没有已报告的放置/连线致命错误，但不解除上述 critical warning。

## 5. 与两套基线逐项对比

### 5.1 `project` 与 `vendor/lab_ex1`

以下六个 DDR 关键文件逐文件 SHA-256 完全一致：外层 `ph1p35_324_ddr_wrapper.v`、`Design.xml`、`ddr2.v`、`ph1p_ddrphy_clk_top.v`、`ph1p_ddrphy_pll0.v`、`ph1p_ddrphy_pll1.v`。其中：

- 两份 `Design.xml` 均为 `05F2DF14236DAE523772394418C4BFC68949FD9BC0C5A25FE9A5C82B815B3538`。
- 两份外层 DDR wrapper 均为 `891E2838AB36107B05BD23F67967F8EF3F9E9564F2FB022EC382F54E233E9E8D`。

路径：`project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/ph1p35_ddr/` 与 `vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/ph1p35_ddr/`。这证明 100 MHz 配置/50 MHz 连接矛盾及隐式 `dhi_clk` 均来自 vendor 基线，不是工作副本漂移。

vendor 的历史物理日志也包含相同 `PHY-5060`、四条 `PHY-5016` 和 `PHY-5079`：`vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display_Runs/phy_1/run.log:138-139,198-211,1587-1596`。它只能证明警告是继承的，不能证明板上可用。

### 5.2 `official_docs/2_Example/32_cs500_mipi_hdmi`

| 项目 | 当前/vendor lab_ex1 | 官方资料例程 32 | 结论 |
|---|---|---|---|
| DDR IP | `PH1P_SINGLE_PLL=0`、ref 100 MHz、DDR2-1066、`tCK=1876 ps` | `PH1P_SINGLE_PLL=1`、ref 50 MHz、DDR2-800、`tCK=2500 ps` | 是不同的合法配置组合，不能混用参数。例程 32 依据：`vendor/official_docs/2_Example/32_cs500_mipi_hdmi/td/al_ip/ddr_ip/Design.xml:13-15,49,76-85`。 |
| `Design.xml` SHA-256 | `05F2...3538` | `618F10495DD2CBCF0C9A43AC991BF3A0E7B9356ABECEDCBCCD1F54D54E6986B3` | 不是同版配置。 |
| 生成 PLL | 双 PLL；PLL0 `FIN=100`，PLL1 `FIN=133.3` | 单 PLL；`.FIN(REFCLK_FREQ)` 且传入 50.0 | 官方例程同样证明配置的 reference frequency 会进入原语 `FIN`：`O32/td/al_ip/ddr_ip/ddr_ip.v:81-89`、`O32/td/al_ip/ddr_ip/src/rtl/clk/ph1p_ddrphy_pll.v:69,78-79,177-178`。 |
| 顶层 DDR ref | 明确接 50 MHz `I_sys_clk`，但 IP 配 100 MHz | `system_top.v:86` 用未声明的 `I_ddr_clk`；综合把它当隐式 wire，最终 `ref_clk` 未连接 | 官方例程 32 本身不能作为可工作的 50 MHz 接线证明。依据：`O32/src/system_top.v:6,48,86`、`O32/td/test_Runs/syn_1/run.log:118,374`。 |
| 物理报告 | 本次有完整 route/timing/bitgen 报告 | 目录仅有 synthesis 日志，没有可供本次核对的 PHY/final timing 报告 | 不能拿例程 32 的历史源码存在性替代上板证据。 |

## 6. 已确认安全

- 本次 2026-09-21 构建已完成 route 与 bitgen，已覆盖路径 setup/hold 均无违例；依据：`PHY/final_timing.rpt:1-13,25-29`。
- 物理 DRC 未报告 multi-drive、abnormal timing path 或 bound error；依据：`PHY/run.log:1582-1605`。
- DDR 专用 PLL、MLCLK、IOCLK、DDR byte 实例均有生成 IP 自带的位置约束；依据：`D/src/adc/ddr2.adc:52-73`。
- `project` 与 vendor 原始 lab_ex1 的 DDR 配置及生成时钟 RTL 未发生漂移，见第 5.1 节哈希。

这里的“安全”仅表示已核对的构建/约束事实，不等于已经证明当前 bitstream 对板级 DDR 功能安全或可用。

## 7. 需要修复

1. 使 DDR IP 的 reference-frequency 配置、实际物理输入、PLL 分频/倍频、DDR 速度档和 SDC 完全一致；当前 100 MHz 配置接 50 MHz 是下载阻断项。应使用官方支持流程重新生成一致配置，不能只改一个数值或手工改生成 RTL。
2. 处理顶层异步 `set_clock_groups` 覆盖 FIFO 灰码 `set_max_delay` 的优先级问题，使 36 条约束实际生效并在 routed report 中验证。
3. 为 fabric-generated `scl_clk` 建立可验证的时序方案，或按受控 RTL 变更消除 fabric clock；随后重新检查 109 个 unconstrained PI/PO。
4. 解决或由安路工具/技术支持确认 `O_cam_24m` 的 `PHY-5060/PHY-5079` mixed-fanout 与局部时钟路由可接受性。
5. 显式声明 `dhi_clk`，并启用能阻止隐式 net 的检查；这是代码质量修复，不是本次频率错误根因。

## 8. 仍未确认

- 109 个 unconstrained PI/PO 的逐项名称，以及它们与最终 4.36% 未覆盖对象的精确对应关系；现有报告没有列表。
- 四条 `PHY-5016` 各自的唯一网络；日志不带 net name，只有相邻放置上下文。需要在不改工程的前提下由 Tang Dynasty 的 `analyze_clock -detail`/等效报告导出后再判断。
- PH1P35 集成 DDR IP 的专用用户手册/端口规范。现有 `IPUG035` 是 PH1A 系列，只能交叉确认参数语义和时钟架构。
- 当前 bitstream 的 PLL lock、`ddrphy_rdy`、DDR 初始化/训练、读写、摄像头配置、MIPI 接收与 HDMI 输出；均未上板测试。
- 例程 32 的 50 MHz/DDR2-800 配置是否有另一个完整且接线正确的官方工程；当前归档版本的 `ref_clk` 未连接。

## 9. 是否允许下载当前 bitstream 做短时间基线测试

**否，当前状态为 NO-GO。**

直接原因：

1. DDR PLL0 的实际输入与 `.FIN` 声明不一致，实际 VCO 约 533.3 MHz，低于 PH1P35 800 MHz 下限；DDR 是摄像头到 HDMI 帧缓存主链路，不能旁路为“无关功能”。
2. 两个视频异步 FIFO 共 36 条灰码跨域最大延迟约束被全部忽略。
3. `O_cam_24m` 仍有 marked critical local-routing warning，109 个未约束对象尚未逐项封闭。

在完成一致的 DDR IP/物理参考时钟方案、重新 clean build、确认 FIFO CDC 约束生效、导出未约束对象清单并复核 critical warning 之前，不应下载当前 bitstream，也不能把当前 clean build 记为板级基线通过。
