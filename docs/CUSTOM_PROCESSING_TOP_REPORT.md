# 四模式 `custom_processing_top` 独立验证报告

## 范围与接口

本轮只新增自研 RTL、独立 testbench、独立 PH1P35 `opt_gate` 工程；未接入或修改 `project/`、`vendor/`、官方 IP、相机配置、ADC/SDC，也未执行 place、route、bitgen、Download 或上板。插点依据见 `docs/LAB_EX1_INTEGRATION_PREP.md` 第 1–4 节：AWB → 本模块 → `data_96bit_to_128bit`。

`rtl/custom/custom_processing_top.v` 的输入为 `i_clk=S_csi_rx_clk`（当前基线报告的目标 59.995 MHz）、低有效异步 `i_rst_n`、`i_mode_req[1:0]`、`i_threshold[7:0]`、`i_tdata[95:0]`、`i_tvalid/i_tuser/i_tlast`；输出为 `o_tdata[95:0]`、`o_tvalid/o_tuser/o_tlast`。每拍依次装载 `[95:72]`、`[71:48]`、`[47:24]`、`[23:0]` 四个 `{R,G,B}` 像素。`tuser` 表示有效 SOF；`tlast` 是行尾，也允许 `tvalid=0,tlast=1`。这里没有 `ready/de/hsync/vsync`。

| 模式 | 输出 | 输入边沿 N → 对应输出边沿 | 实现 |
|---|---|---:|---|
| `00` | RGB 原样 | N+1，两级寄存 | `bypass_d1/d2` |
| `01` | 灰度三通道复制 | N+1，两级寄存 | `Y=(77R+150G+29B+128)>>8`；`gray_d1/d2` |
| `10` | 灰度 `>= threshold` 为白 | N+1，两级寄存 | `binary_d1/d2` |
| `11` | Sobel 三通道复制 | N+1，Sobel 内两级寄存 | `abs(Gx)+abs(Gy)` 饱和到 255；沿用 Sobel 的一行一像素空间偏移与边界策略 |

“两拍”指输入被第一级采样、再由第二级输出；按边沿编号为 N 到 N+1，没有第三个输出寄存器。`custom_sobel_4px` 无条件接收整个输入流，其 `o_tvalid/o_tuser/o_tlast` 作为统一两拍标记；四条数据路径、`mode_d1/d2` 均与其对齐，最终为组合 mux。无效输出拍强制 `o_tdata=0`。仅在 `i_tvalid && i_tuser` 采样模式与阈值，SOF 首拍使用新值，帧内请求变化不影响当前帧。实现见 `rtl/custom/custom_processing_top.v`；Sobel 行缓存语义见 `rtl/custom/custom_sobel_4px.v`。

## 功能仿真

实际命令：`& .\sim\custom\run_processing_top_iverilog.ps1`。脚本保存 Icarus 版本、两组完整 `iverilog -g2005 -Wall` 编译命令、`vvp` 命令、完整输出与退出码于 `sim/custom/processing_top_iverilog_evidence.txt`。使用 Icarus Verilog 12.0 (devel)，两组编译退出码与运行退出码均为 **0**。

| 配置 | 覆盖 | 结果 |
|---|---|---|
| 默认 1280×720 参数 | 连续 320 个有效拍/行；每种模式的 6 行、跨帧 SOF、无效行尾、帧中改请求、复位 | `valid=19201 markers=19262 sof=11 eol=60 reset=4 hardcoded=4 errors=0`；PASS |
| 16×6 参数 | 十个完整小帧的首末行/列；均匀场、水平/垂直边缘、跨 4-pixel 边界脉冲、非对称图案 | `valid=241 markers=302 sof=11 eol=60 reset=4 hardcoded=10 errors=0`；PASS |

`sim/custom/tb_custom_processing_top.v` 使用独立整数参考模型计算灰度、阈值和 3×3 Sobel；另外固定校验黑、白、红 `0x4d`、绿 `0x95`、蓝 `0x1d`、阈值 127/128/129 以及小尺寸 Sobel 检查点。逐拍比较数据与三个标记的两级延迟、无效数据清零；错误非零或超时均以 `$fatal(1)` 失败。默认配置只驱动前 6 行，完整帧边界由 16×6 配置覆盖。`-Wall` 的唯一 Icarus 提示为既有 RTL 文件和新顶层没有 `timescale`；testbench 自身有 `timescale`，该提示不是功能失败（证据文件的 Compile output）。

## 独立 PH1P35 综合

实际命令：`& .\qa\custom_processing_synth_check\run_td_synthesis.ps1`，退出码 0，`.opt_gate.end.f` 存在。Tang Dynasty **V6.2.168116**；器件 **PH1P35MDG324、Speed -3**；独立时钟约束 16.668 ns / 59.995 MHz。配置的最终步骤是 `opt_gate`，见 `qa/custom_processing_synth_check/settings.cfg`；没有运行实现流程。五个实际综合源文件依次为：

1. `rtl/custom/custom_rgb_to_gray.v`
2. `rtl/custom/custom_gray_threshold.v`
3. `rtl/custom/custom_sobel_4px.v`
4. `rtl/custom/custom_processing_top.v`
5. `qa/custom_processing_synth_check/custom_processing_synth_top.v`（仅为 151 I/O 的综合观察 harness）

来源：`qa/custom_processing_synth_check/custom_processing_synth_check.prj`、`td_20260923_201329.log`。以下为 **gate.area** 口径，不混用 `gate.qor`：

| 资源 | 四模式顶层 | 旧独立 Sobel | 证据 |
|---|---:|---:|---|
| LUT | 1,315 | 1,039 | 两工程 `*_gate.area` |
| REG | 431 | 155 | 同上 |
| SLICE | 1,190 | 976 | 同上 |
| ERAM20K | **3** | 3 | 同上；`u_sobel` hierarchy 占 3 |
| DRAM LUT | **0** | 0 | 同上 |
| DSP | **12** | 12 | 同上；`SYN-2601` |

TD 将共享的四路灰度计算保留为 12 个 DSP，未因模式并联增至 24；`u_sobel` 的三块 ERAM20K 仍成功推断。独立综合的最差 setup 数据路径为 `u_dut/u_sobel/ramread1_syn_11.clkb` → `u_dut/u_sobel/o_tdata_reg[24].d`，9.781 ns、10 级逻辑；估算 SWNS **+6.823 ns**、HWNS **+0.415 ns**，Fmax 101.574 MHz，STA coverage **62.35%**。依据 `qa/custom_processing_synth_check/custom_processing_synth_check_gate.timing`；这是仅有时钟约束的 **opt_gate 估算**，不是 place/route 后的时序闭合，输入输出路径也未完整约束。

全部 TD warning（`qa/custom_processing_synth_check/td_20260923_201329.logw`）：

1. `SYN-5025 WARNING: Using 0 for all undriven pins and nets`。发生在 Optimize RTL / Uniform Instance；日志未给对象名。已导出 RTL、elaborate、gate 网表到同一 QA 目录检查，但仍未能唯一定位具体对象；**未 waiver**，集成前继续核查。
2. `SYN-6021 CRITICAL-WARNING: 151 out of 151 logical ports has no user assigned specific location constraint.` 该独立观察 harness 故意没有 ADC，禁止拿它 bitgen 或下载；实际集成必须使用经核对的板级约束。

`*_rtl.area` 报 `#LATCH 0`；本轮日志未出现 black box、隐式 wire、位宽截断、多驱动、异步读 RAM 或无法推断 RAM 的诊断。没有这些诊断不等于板级已验证；`SYN-5025` 的对象仍未确认。

## 判定与下一步

四模式顶层已满足独立 RTL 功能和 PH1P35 `opt_gate` 资源检查，**可以进入“本顶层连接真实 96→128 转换器”的独立链路仿真**。尚未接入 lab_ex1；真实转换器的 frame_start、valid、无效行尾/`tlast` 与复位契约仍须该下一阶段核对。任何完整工程 place/route、bitgen 或下载之前，还需处理 `docs/LAB_EX1_INTEGRATION_PREP.md` 所列 DDR 参考时钟/PLL、FIFO CDC、未约束路径、相机时钟与板级复位等基线阻塞项。本报告不声称板级视频或冷启动通过。
