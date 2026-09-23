# 自研图像处理 RTL 计划

本阶段新增 RTL 仅位于 `D:\FPGA\HX1P35A_Image\rtl\custom\`，没有加入 Tang Dynasty 工程、没有修改官方例程或厂商 IP。

## 第一批模块

| 文件 / 模块 | 输入与输出 | 行为 / 延迟 |
| --- | --- | --- |
| `custom_rgb_passthrough.v` / `custom_rgb_passthrough` | 96-bit 四 lane RGB888 | 组合直通，0 拍。 |
| `custom_rgb_to_gray.v` / `custom_rgb_to_gray` | 一个 `{R,G,B}` 像素到 8-bit 灰度 | 组合，0 拍；`Y=(77R+150G+29B+128)>>8`。系数和舍入在源码注释中固定。 |
| `custom_gray_threshold.v` / `custom_gray_threshold` | 8-bit 灰度、阈值到 8-bit 0/255 | 组合，0 拍；相等时输出 255。 |
| `custom_video_mode_select.v` / `custom_video_mode_select` | 96-bit 四 lane RGB、六个同步/边界标记与模式请求 | 统一寄存 1 拍；旁路、灰度、二值化三种模式。 |
| `custom_axis96_mode_adapter.v` / `custom_axis96_mode_adapter` | 96-bit `tdata`、`tvalid/tuser/tlast` 与控制输入 | 真实 AWB 插点适配器；所有流信号 1 拍，帧首原子锁存模式和阈值。 |

模式编码为 `00=旁路`、`01=灰度`、`10=二值化`；未定义值按旁路显示。`i_mode_req` 只在有效帧首拍采样，帧首拍本身采用新模式。设计依据是官方 `lab_ex2` 的 4×RGB888 流位置和通道顺序：[lab_ex2 isp_top.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/isp_top.v:84) 的 84–132 行、[edge_detect_96.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/edge_detect_96.v:22) 的 22–32 行。

## 集成边界

未来最低风险接入方式是：在项目工作副本中新建一个自定义 ISP 顶层（或在非官方副本中在 AWB 与 `data_96bit_to_128bit` 间实例化 `custom_axis96_mode_adapter`），让 `awb_O_tdata/tvalid/tuser/tlast` 经适配器到打包器。官方边缘例程恰好是该拓扑的可读参考，[lab_ex2 isp_top.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/isp_top.v:102) 的 102–132 行。

在此之前必须解决两项接口适配，而不是臆测接线：

1. 适配器的 `tuser/tlast/tvalid` 映射已经明确；`de/hsync/vsync` 在此位置不存在，因此真实适配器没有这些端口。通用核心仍保留它们，供未来有这些真实标记的接口使用，不能拿来直接接此插点。
2. 模式请求的物理来源、跨 `S_csi_rx_clk` 域同步和复位后的默认模式尚未定义；本 RTL 只定义同步域内输入契约。

不改变 `valid` 节拍和不接受 backpressure 是必要条件，因为 `video_in` 无 ready 输入且用 `I_camera_valid` 直接写 FIFO。[video_in.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/video_in.v:55) 的 55–72 行。

## 验证策略

`sim/custom/tb_custom_axis96_mode_adapter.v` 是当前主自检：它驱动 3 个连续帧、每帧一条 320 拍（1280 像素）有效行，帧之间没有无效拍；验证帧中模式/阈值改变仅在下一帧生效、首末拍 `tuser/tlast`、一拍数据/标记延迟、启动与中途异步复位。固定硬编码灰度值为黑 `00`、白 `ff`、红 `4d`、绿 `95`、蓝 `1d`，阈值覆盖 `127/128/129`。测试向量和检查器见 [tb_custom_axis96_mode_adapter.v](D:/FPGA/HX1P35A_Image/sim/custom/tb_custom_axis96_mode_adapter.v:7) 的 7–12、97–158、181–260 行。

实际结果（2026-09-22）：Icarus Verilog 12.0 实际编译并运行真实适配器测试，编译退出 `0`、运行退出 `0`，输出 `PASS: adapter checks valid=961 marker=963 reset=4 errors=0`。证据文件 [iverilog_evidence.txt](D:/FPGA/HX1P35A_Image/sim/custom/iverilog_evidence.txt) 保存版本、完整编译命令、完整运行输出、PASS/FAIL 与退出状态。ModelSim Ase 2020.3 的上一轮只完成编译；其命令行运行仍受本机受限环境的临时文件/RPC socket 限制，故未把它标为通过。

可复现 Icarus 命令（先把 `TMP`、`TEMP` 指向 `D:\FPGA\HX1P35A_Image\sim\custom\tmp`）：

```powershell
& D:\FPGA\HX1P35A_Image\sim\custom\run_iverilog.ps1
```

脚本在运行结束时删除 `.tmp_iverilog/` 与其中的 `.vvp`；`work/`、`tmp/`、`VSOUT*`、ModelSim 数据库和 `.vvp` 都是生成物，既不作为源码也不作为测试通过证据。唯一保留的本轮运行证据是文本 [iverilog_evidence.txt](D:/FPGA/HX1P35A_Image/sim/custom/iverilog_evidence.txt)。

## AWB 无效行尾补测

第二轮补测增加了官方 AWB 风格的行尾事件：输入 `tvalid=0, tlast=1`，同时故意把 `mode_req` 从二值化改成灰度、把阈值从 128 改成 3。一拍后检查 `o_tvalid=0, o_tlast=1`，活动模式和阈值仍为二值化/128；总有效数据计数仍严格为 961。向量见 [tb_custom_axis96_mode_adapter.v](D:/FPGA/HX1P35A_Image/sim/custom/tb_custom_axis96_mode_adapter.v:227)。重新运行 [run_iverilog.ps1](D:/FPGA/HX1P35A_Image/sim/custom/run_iverilog.ps1) 后，编译/运行退出状态均为 0，最终输出仍为 `PASS: adapter checks valid=961 marker=963 reset=4 errors=0`；完整文本见 [iverilog_evidence.txt](D:/FPGA/HX1P35A_Image/sim/custom/iverilog_evidence.txt)。

## 独立 Sobel 架构

新增 `custom_sobel_4px`，默认参数为 1280×720，输入输出均为真实 96-bit 四 RGB888 像素流和 `tvalid/tuser/tlast`，没有 `de/hsync/vsync` 或 ready。端口与默认参数见 [custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_sobel_4px.v:6)。

每拍四像素处理方式：

1. 四个 RGB888 lane 先并行转为 8-bit 灰度。
2. 每条历史行分为四个 320×8-bit bank；两条历史行共八个 bank，即默认逻辑容量 `2×4×320×8=20,480 bit`。定义见 [custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_sobel_4px.v:28)。该结构避免一个 RAM 同拍承担四个独立地址；是否映射为 PH1P35 ERAM 仍须以后由真实综合报告确认。
3. 每个 bank 地址对应一个四像素组。lane0 的窗口使用上一拍 lane2、lane3 和本拍 lane0；lane1 使用上一拍 lane3 与本拍 lane0、lane1；lane2/3 使用本拍相邻值。因此上一拍 lane3 到下一拍 lane0 是同一连续像素序列，不存在四像素字边界断窗。窗口连接见 [custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_sobel_4px.v:116)。
4. `Gx/Gy` 使用显式 13-bit 有符号中间量，幅值为 `abs(Gx)+abs(Gy)`，大于 255 时饱和为 255，见 [custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_sobel_4px.v:88)。输出为三通道相等的 RGB888 边缘强度。

### 坐标、边界和延迟

这是无 ready、无停顿接口上的因果窗口。输出流坐标 `(x,y)` 对应源窗口中心 `(x-1,y-1)`，因此视觉结果相对标记向右、向下各偏移一个像素；这是设计契约，不是未记录的误差。输出首两行以及首组 lane0/lane1 被置零；源图最后一行和最后一列属于边界，不进入有效中心序列。掩码实现见 [custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_sobel_4px.v:130)。若后续要求严格保持几何坐标，则需要可证明足够的行/帧消隐期用于尾部 flush，或引入更深缓冲，当前真实接口尚未证明这一条件。

从输入在时钟边沿 N 被采样到相同位置的 `o_tdata/o_tvalid/o_tuser/o_tlast` 在 N+1 有效，固定寄存延迟为 1 拍；空间窗口历史另为一行一像素。`tvalid=0,tlast=1` 的行尾拍只复位水平历史并推进行号，输出仍为 `o_tvalid=0,o_tlast=1`，不会写行缓存。时序实现见 [custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_sobel_4px.v:144)。复位不循环清空行 RAM；新帧前两行被边界掩码覆盖并自然重写缓存。

## Sobel 自检结果

[tb_custom_sobel_4px.v](D:/FPGA/HX1P35A_Image/sim/custom/tb_custom_sobel_4px.v:1) 以 16×6 参数实例化同一 RTL，以整数模型独立计算 3×3 Sobel，并覆盖：全黑、全白、水平边缘、垂直边缘、单点脉冲、每行首尾、无额外空闲的帧切换、真实无效 `tlast` 行尾和中途异步复位。固定检查点包括两种均匀图、水平/垂直饱和边缘以及脉冲的上方和中心行，共 6 项；测试定义见 207–239 行。

运行 [run_sobel_iverilog.ps1](D:/FPGA/HX1P35A_Image/sim/custom/run_sobel_iverilog.ps1) 的真实结果：

- Icarus Verilog 12.0；
- 默认 1280×720 RTL 单独 elaboration/编译退出状态 0；
- 参数化 testbench 编译退出状态 0；
- 仿真退出状态 0；
- `PASS: sobel checks valid=150 marker=188 reset=4 hardcoded=6 errors=0`。

完整版本、两条编译命令、运行命令、全部输出和退出状态保存在 [sobel_iverilog_evidence.txt](D:/FPGA/HX1P35A_Image/sim/custom/sobel_iverilog_evidence.txt)。脚本结束后删除 `.tmp_sobel_iverilog/` 和 `.vvp`。本结果仅证明独立 RTL 功能仿真；未加入 Tang Dynasty 工程，未综合、未验证 ERAM 推断/时序，未下载或上板。
