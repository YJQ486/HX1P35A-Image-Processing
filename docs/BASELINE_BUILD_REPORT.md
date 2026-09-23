# 未修改 lab_ex1 基线构建报告

> 构建日期：2026-09-21  
> 工具：Tang Dynasty V6.2.168116，安装路径 `D:\TD`  
> 工程：`D:\FPGA\HX1P35A_Image\project\lab_ex1_mipi_hdmi_SC500_720P\lab_ex1_mipi_hdmi\td_project\camera_to_dsi_display.al`  
> 执行方式：用户在 Tang Dynasty 6.2 GUI 中执行真实 clean build；Codex 未重新运行构建，只读取本次产物。  
> 结论：**synthesis、place、route、timing、bitgen 均完成；最终 setup/hold 通过。**

## 1. 构建结果

| 阶段 | 状态 | 关键结果 | 证据路径 |
|---|---|---|---|
| Synthesis | pass | `opt_gate` 完成；setup WNS `+0.860 ns`，hold WNS `+0.114 ns` | `project/.../camera_to_dsi_display_Runs/syn_1/flow.status`、`camera_to_dsi_display_gate.ts` |
| Place | intermediate warning | setup WNS `+1.593 ns`；hold WNS `-0.270 ns`，541 个 hold 违例端点 | `project/.../camera_to_dsi_display_Runs/phy_1/place_flow.status` |
| Route + hold fix | pass | setup WNS `+1.408 ns`；hold WNS `+0.020 ns`；TNS 均为 0，违例端点均为 0 | `project/.../camera_to_dsi_display_Runs/phy_1/route_flow.status` |
| Bitgen | pass | `Generate bitstream completely`；生成普通和压缩 bitstream | `project/.../camera_to_dsi_display_Runs/phy_1/run.log` 第 1752–1767 行 |
| Blocking errors | pass | `syn_1/run.logw` 与 `phy_1/run.logw` 中均无 ERROR/FATAL；无 license/decrypt/black-box 错误 | 两个 run 的 `run.logw` |

最终实现报告由 V6.2.168116 于 `Mon Sep 21 16:37:59 2026` 生成，Top 为 `design_top_wrapper`，Device 为 `PH1P35MDG324`、Speed 3。依据：`phy_1/final_timing.rpt` 第 1–13 行。

## 2. 本次 bitstream

### 2.1 主 bitstream

- 完整路径：`D:\FPGA\HX1P35A_Image\project\lab_ex1_mipi_hdmi_SC500_720P\lab_ex1_mipi_hdmi\td_project\camera_to_dsi_display_Runs\phy_1\camera_to_dsi_display.bit`
- 文件大小：`1,789,539 bytes`
- 修改时间：`2026-09-21 16:38:08.368 +08:00`
- SHA-256：`5D799FF7AA649676CE2F90F5AD657FB75C3EA76E2C03BD57EAEEA8809093DD78`

### 2.2 同次生成的压缩 bitstream

- 完整路径：`D:\FPGA\HX1P35A_Image\project\lab_ex1_mipi_hdmi_SC500_720P\lab_ex1_mipi_hdmi\td_project\camera_to_dsi_display_Runs\phy_1\camera_to_dsi_display_compress.bit`
- 文件大小：`1,348,529 bytes`
- 修改时间：`2026-09-21 16:38:08.180 +08:00`
- SHA-256：`2E318F223910AA7541072FD0082DC8EC092685045773A4067977BB71B7C38669`

两个时间戳与 `.bitgen.begin.f`（16:38:04）和 `.bitgen.end.f`（16:38:08）一致，不是 2026-09-10 的历史 bitstream。

## 3. 最终资源占用

| 资源 | 使用 | 可用 | 利用率 |
|---|---:|---:|---:|
| LUT6 | 9,865 | 21,216 | 46.50% |
| REG / slice register | 13,313 | 42,432 | 31.37% |
| SLICE | 12,358 | 21,216 | 58.25% |
| ERAM20K | 40 | 108 | 37.04% |
| DSP | 8 | 40 | 20.00% |
| PLL | 3 | 6 | 50.00% |
| GCLK | 9 | 32 | 28.12% |
| IO | 58 | 160 | 36.25% |

补充专用资源：DDR byte 6/12（50.00%）、MIPI RX 1/2（50.00%）、MIPI TX 0/2、IOCLK 4/18（22.22%）、SCLK 19/48（39.58%）、MLCLK 2/6（33.33%）。依据：`phy_1/camera_to_dsi_display_phy.area` 第 4–39 行。

注意：`route.qor` 的 `#slices=12,358` 是最终实现数量；综合 `gate.qor` 中的 `#slices=3,391` 是综合阶段估算，不能替代最终实现占用。

## 4. 最终时序

### 4.1 全局结果

| 检查 | 最差裕量 | TNS | 违例端点 | 结论 |
|---|---:|---:|---:|---|
| Setup | `+1.408 ns` | `0.000 ns` | 0 | pass |
| Hold | `+0.020 ns` | `0.000 ns` | 0 | pass，但余量很小 |
| Period check | `+12.200 ns` | — | — | pass |

全局最差 setup 路径属于 `HDMI_SERIAL_CLK`（375.094 MHz），最差 setup `+1.408 ns`；全局最差 hold `+0.020 ns` 同时出现在 MIPI RX/ERAM 路径和 HDMI pixel/ERAM 路径。依据：`phy_1/final_timing.rpt` 第 25–29、1173–1185、4186–4198、8976–8998 行。

### 4.2 全部报告时钟

下表直接抄录最终 `Clock Summary`。`SWNS/HWNS=0.000` 的 local/MLCLK 行没有可报告的时序端点，不能解释为“刚好零裕量”或“已充分覆盖”。

| ID | 时钟 | 约束频率 MHz | Fanout | SWNS ns | HWNS ns |
|---|---|---:|---:|---:|---:|
| clk0 | `MIPI_RX_BYTE_CLK` | 59.995 | 4,757 | 8.365 | 0.020 |
| clk1 | `u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk` | 66.667 | 2,485 | 5.542 | 0.023 |
| clk2 | `HDMI_PIXEL_CLK` | 75.002 | 908 | 4.674 | 0.020 |
| clk3 | `sys_clk_50m` | 50.000 | 93 | 15.607 | 0.086 |
| clk4 | `pll_clk_24m` | 23.810 | 88 | 37.028 | 0.022 |
| clk5 | `HDMI_SERIAL_CLK` | 375.094 | 42 | 1.408 | 0.054 |
| clk6 | `u_ph1p35_324_ddr_wrapper/u_ddr2/mcu_clk` | 25.397 | 28 | 31.928 | 0.054 |
| clk7 | `pll_clk_100m` | 100.000 | 8 | 8.040 | 0.054 |
| clk8 | `u_ph1p35_324_ddr_wrapper/u_ddr2/ctl_clk` | 66.667 | 6 | 0.000 | 0.000 |
| clk9 | `u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk` | 266.667 | 6 | 0.000 | 0.000 |
| clk10 | `mipi_rx_ck_pad` | 239.981 | 1 | 0.000 | 0.000 |
| clk11 | `...u_PH1P_LOGIC_DPHY_MIPI_RX.tif_c16_in` | 59.995 | 1 | 0.000 | 0.000 |
| clk12 | `u_ph1p35_324_ddr_wrapper/u_ddr2/ref_clk` | 66.667 | 1 | 0.000 | 0.000 |
| clk13 | `...u_PH1P_LOGIC_DPHY_MIPI_RX.io_clk_pad_p` | 239.981 | 0 | 0.000 | 0.000 |

依据：`phy_1/final_timing.rpt` 第 32–76 行。

### 4.3 未约束与例外路径

- 最终 STA coverage 为 `95.64%`，不是 100%。依据：`phy_1/final_timing.rpt` 第 8 行。
- 综合 mapper 报告 `Collect 7602 PI 5003 PO (109 timing unconstrained) for mapping`。这里的 109 是 timing-unconstrained PI/PO 对象数量，不应误写成 109 条最终路径。依据：`syn_1/run.log` 第 1196 行。
- `final_timing.rpt` 没有给出完整的未约束路径清单或最终路径数量，因此“未约束路径为 0”**仍未确认**。
- `camera_to_dsi_display_exception.timing` 记录两组 `set_max_delay`，每组 18 条、均被 `set_clock_groups` 忽略；它们没有造成当前违例，但应纳入 CDC/约束审查。

## 5. DDR 与关键时钟问题

### 5.1 `dhi_clk` 隐式 wire：仍存在

本次新综合日志明确记录：

`undeclared symbol 'dhi_clk', assumed default net type 'wire'`

位置为 `user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v(83)`；同一 wrapper 把 `dhi_clk` 赋给 `O_ddr_clk`。依据：`syn_1/run.log` 第 228–231 行，以及 wrapper 第 60–83 行。该问题没有阻断综合或 bitgen，但属于 DDR 用户时钟接口的可维护性/连接风险，上板前应明确声明并复核。

### 5.2 DDR 100 MHz IP 参数与 50 MHz 实际连接：仍存在

- 新综合 elaboration 明确使用 `PLL0_REFCLK_FREQ=100.0`。依据：`syn_1/run.log` 第 441、443、447、451–454 行。
- wrapper 仍将 `.ref_clk(I_sys_clk)`、`.apb_pclk(I_sys_clk)`；顶层 `I_sys_clk` 在最终 STA 中为 `sys_clk_50m = 50.000 MHz`。依据：wrapper 第 78–83 行、`final_timing.rpt` 第 40 行。
- 设计中另有 `pll_clk_100m = 100.000 MHz`，但 wrapper 的 DDR `I_sys_clk` 端口并未接该时钟。依据：`design_top_wrapper.v` 第 488–493、757–762 行及 `final_timing.rpt` 第 44 行。
- 最终报告列出的 DDR 内部 `ref_clk=66.667 MHz`、`usr_clk=66.667 MHz`、`ddr_clk=266.667 MHz` 是实现工具传播出的内部时钟，不能反向证明外部 50 MHz 输入满足一个按 100 MHz 参数生成的 DDR IP。

结论：该冲突并未被成功构建消除，仍是上板前必须解决或由官方 IP 配置依据明确豁免的问题。

## 6. 警告分类

### 6.1 统计

| 阶段 | ERROR/FATAL | CRITICAL-WARNING | 普通 WARNING | 主要代码 |
|---|---:|---:|---:|---|
| Synthesis | 0 | 0 | 1,004 | SYN-5013×790、HDL-5317×79、SYN-5011×54、HDL-5007×42、HDL-5314×20、其余×19 |
| Physical | 0 | 3 | 10 | PHY-5060×2、PHY-5079×1、PHY-5088×6、PHY-5016×4 |

统计依据：本次 `syn_1/run.logw`、`phy_1/run.logw`。同一警告可能来自生成 IP 的不同位/实例，因此按日志记录数统计。

### 6.2 阻断性错误

**无。** 未发现 ERROR/FATAL、license/decrypt/black-box、未布通、setup/hold violation 或 bitgen 失败。该结论只限构建，不代表功能或上板通过。

### 6.3 上板前需要解决或明确接受的问题

1. DDR 参考时钟 100 MHz 参数与 50 MHz 接线冲突；见 5.2。
2. `dhi_clk` 隐式 wire；见 5.1。
3. STA coverage 95.64%，且有 109 个 timing-unconstrained PI/PO 对象；必须补充约束覆盖审查。
4. 最终 hold WNS 仅 `+0.020 ns`，虽通过但裕量非常小，不建议作为稳定量产/比赛演示余量直接接受。
5. 两条 `PHY-5060 CRITICAL-WARNING`：`O_cam_24m_syn_3` 同时驱动 120 个 clock pin 和 1 个 data/control pin；`u_uicfgcs500/u_i2c/scl_clk` 同时驱动 1 个 clock pin 和 2 个 data/control pin。依据：`phy_1/run.logw` 第 11–12 行。
6. 一条 `PHY-5079 CRITICAL-WARNING`：标记的 `pll_clk_24m` 使用 local routing；最终 CTS 表显示其 80/81 fanout、3 段 local wire。依据：`phy_1/run.log` 第 1584–1596 行。
7. `PHY-5016` 四条 PLL clock-to-IO 警告，以及 `PHY-5088` 的 buffer/clock-net 级联警告，需要结合 `analyze_clock -detail` 复核；本阶段未运行额外分析命令。
8. 关键端口宽度警告：`I_lane_invert` 4→2、`O_mc_app_wdf_mask` 16→32、`O_raw_tready` 32→1，以及相机 I2C 配置宽度差异。依据：`syn_1/run.logw` 第 19–23、105 行。
9. `raw10_unpacket_2lane.v` 有 103 条 undriven 相关记录，包括 `I_camera_black_level`、FIFO/RAW8 内部网；需要确认是禁用分支被优化还是会影响活动数据通路。依据：`syn_1/run.logw` 第 1791 行起。

### 6.4 普通/生成代码警告

- `demosaic.v` 注释内再次出现 `/*`。
- divider、FIFO、BRAM、DDR 生成代码中存在未连接的可选端口/未驱动位。
- 三个 RAM 实例的 `RAM_STYLE/ROM_STYLE` 设置被工具回退为 `AUTO`。
- DDR/HDMI 加密或生成 RTL 中有匿名网、宽度占位、未使用 lane/byte 的警告。

这些警告不阻断本次 bitgen，但只有确认它们属于未用功能或生成模板后，才能列入正式 waiver。

## 7. 验证边界

| 项目 | 状态 |
|---|---|
| 构建环境预检 | pass |
| GUI clean build | pass（用户实际执行，Codex 读取证据） |
| 最终 setup/hold | pass |
| RTL 仿真 | not tested |
| DDR 校准/读写 | not tested |
| MIPI 摄像头输入 | not tested |
| HDMI 输出 | not tested |
| Download/上板 | not tested；本阶段禁止执行 |
| QSPI 固化与断电启动 | not tested；本阶段禁止执行 |

因此该 bitstream 是“可追溯的构建产物”，不是“已验证可上板运行的发布产物”。
