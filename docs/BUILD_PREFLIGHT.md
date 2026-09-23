# 未修改 lab_ex1 构建环境预检

> 更新日期：2026-09-21  
> 工程：`D:\FPGA\HX1P35A_Image\project\lab_ex1_mipi_hdmi_SC500_720P\lab_ex1_mipi_hdmi\td_project\camera_to_dsi_display.al`  
> 本次操作边界：仅检查新生成的构建产物并更新本文档；未修改 RTL、厂商 IP、XML、相机寄存器、ADC、SDC 或工程配置，未执行 Download/烧录。

## 1. 预检结论

| 检查项 | 状态 | 结论与证据 |
|---|---|---|
| Tang Dynasty 安装 | pass | `D:\TD`；本次 `syn_1/run.log` 与 `phy_1/run.log` 均记录 `Tang Dynasty V6.2.168116`。 |
| 版本兼容性 | pass | 工具实际版本与工程要求的 `6.2.168116` 完全一致。证据：`project/.../camera_to_dsi_display_Runs/syn_1/flow.status`。 |
| 器件库 | pass | 本次成功导入并实现 `PH1P35MDG324`、Speed 3。证据：`syn_1/flow.status`、`phy_1/route_flow.status`。 |
| 加密 IP/许可证 | pass（对本工程构建） | MIPI、DDR、HDMI、FIFO 相关源/IP 已完成综合、布局布线和 bitgen；本次日志无 license、decrypt、black-box 错误。证据：`syn_1/run.log`、`phy_1/run.log`。 |
| 命令行构建入口 | pass（未在本次复跑） | GUI 已重新生成有效的 `run.bat`，调用 `D:/TD/bin/td_commands_prompt.exe`；`settings.cfg` 已含 `ph1_35p.db`、`PH1P35MDG324`、`design_top_wrapper`、ADC/SDC 列表。证据：`syn_1/run.bat`、`syn_1/settings.cfg`、`phy_1/run.bat`、`phy_1/settings.cfg`。 |
| clean synthesis | pass | `opt_gate` 完成，综合 WNS 为 setup `+0.860 ns`、hold `+0.114 ns`。证据：`syn_1/flow.status`、`camera_to_dsi_display_gate.ts`。 |
| place/route | pass | place 后 hold 曾为 `-0.270 ns`，route/fix_hold 后变为 `+0.020 ns`；最终无 setup/hold 违例。证据：`phy_1/place_flow.status`、`route_flow.status`。 |
| bitgen | pass | 日志记录 `Generate bitstream completely`，普通和压缩 bit 文件均于 2026-09-21 16:38:08 生成。证据：`phy_1/run.log` 第 1752–1767 行及两个 `.bit` 文件。 |
| RTL 仿真 | not tested | 本阶段未运行仿真。 |
| 上板/摄像头/HDMI | not tested | 本阶段未连接或下载到开发板。 |
| QSPI 冷启动 | not tested | 本阶段未执行固化或断电启动验证。 |

## 2. 工作工程确认

| 项目 | 状态 | 证据 |
|---|---|---|
| Device | pass | `PH1P35MDG324`；`syn_1/flow.status`。 |
| Top | pass | `design_top_wrapper`；`syn_1/flow.status`。 |
| 活动源/IP 展开 | pass | 新 run 成功完成 elaboration、opt_rtl、opt_gate；未出现缺文件或 black-box 错误。`syn_1/run.log`。 |
| pin.adc 加入 | pass | `syn_1/settings.cfg` 的 `ADCList` 指向 `../../../user_source/constraints_source/pin.adc`，综合实际执行 `read_adc` 一次。 |
| 主 SDC 加入 | pass | `syn_1/settings.cfg` 的 `SDCList` 指向 `../../camera_to_dsi_display.sdc`，综合实际执行 `read_sdc` 三次（主 SDC 与 IP SDC/TCL）。 |
| 旧电脑绝对路径 | pass（已由 GUI 元数据重定位） | GUI 保存时把 `.al` 首行 `Project Path` 从旧 `C:/Users/Cczzzzzq/...` 改为当前 `D:/FPGA/.../td_project`；这是 project descriptor 的一行路径元数据变化。 |
| RTL/IP/约束基线 | pass | 主 SDC SHA-256 `457379...5c0d`、pin.adc `99c31a...8dbe`、DDR `Design.xml` `05f2df...5318`、`ddr2.xml` `1c0928...720`，均与构建前记录一致。 |
| `.al` 字节级 vendor 一致性 | fail（仅路径元数据） | 当前 project `.al` SHA-256 为 `5fc8d3...a9df`，vendor 为 `019b57...53cc`；只差 `<Project ... Path="...">` 一行，未发现源清单、器件、Top 或约束配置差异。 |

## 3. 本次 run 产物时间链

| 阶段 | 开始/关键时间 | 结束/产物时间 | 证据 |
|---|---:|---:|---|
| syn_1 | 2026-09-21 16:34:46 | 16:35:55 | `syn_1/run.log`、`.opt_gate.end.f` |
| place | 16:35:55 | 16:37:15 | `phy_1/place_flow.status`、`.opt_place.end.f` |
| route/fix_hold | 16:37:15 | 16:38:04 | `phy_1/route_flow.status`、`.opt_route.end.f` |
| bitgen | 16:38:04 | 16:38:08 | `phy_1/run.log`、`.bitgen.end.f`、两个 `.bit` |

时间戳连续且晚于历史 2026-09-10 产物，因此本报告没有把历史日志或历史 bitstream 当成本次结果。

## 4. 仍需上板前处理的预检项

1. DDR IP 以 `PLL0_REFCLK_FREQ=100.0` elaboration，但 wrapper 仍把 50 MHz `I_sys_clk` 接到 `.ref_clk`；构建成功不证明 DDR 输入频率合法。
2. `dhi_clk` 仍为隐式 wire；新综合日志明确报告 `undeclared symbol 'dhi_clk', assumed default net type 'wire'`。
3. 最终 STA coverage 只有 `95.64%`，综合 mapping 还报告 `109 timing unconstrained` 的 PI/PO 对象；最终报告未给出完整未约束路径清单，不能宣称“无未约束路径”。
4. 最终 hold WNS 仅 `+0.020 ns`，并有 3 条物理时钟 `CRITICAL-WARNING`；虽不阻断 bitgen，但应在上板前审查。
5. 尚未执行 RTL 仿真、DDR 校准观测、MIPI 数据接收、HDMI 显示、Download 或 QSPI 冷启动。

详细 QoR、时钟和警告分类见 `docs/BASELINE_BUILD_REPORT.md` 与 `docs/QA_REPORT.md`。
