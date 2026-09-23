# 视频通路接口实测契约

范围：此文档只记录对现有 `lab_ex1`、`lab_ex2`、`lab_ex3` 源码的只读追踪结果；不表示当前工程已经上板验证。源码路径均为绝对路径，行号以当前工作区文件为准。

## 结论与推荐插点

推荐把自研像素处理放在 ISP 内的 **AWB 输出之后、`data_96bit_to_128bit` 之前**。这是 96-bit、每拍 4 个 RGB888 像素的连续流，且官方 `lab_ex2` 已在同一位置放置 `edge_detect_96`：AWB 输出接到边缘模块，再接重打包器，见 [lab_ex2 isp_top.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/isp_top.v:84) 的 84–132 行。自研实现 `custom_video_mode_select` 遵循这一四像素接口，但尚未加入任何工程。

`lab_ex1` 的真实数据链如下：

`mipi_dphy_rx` → `csi_unpacket_2lane` → `raw10_unpacket_2lane` → `uial2axis` → `isp_top(demosaic → data128_96 → AWB → data_96bit_to_128bit)` → `video_in` → 异步 FIFO/DDR → `video_out` → `hdmi_mixer` → `hdmi_tx`。

MIPI、CSI、RAW10、AXIS 与 ISP 实例见 [lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:531) 的 531–669 行；DDR 写读链见同文件 672–790 行；HDMI 时序、混合器、发送器见 794–865 行。

不建议直接在 `isp_top` 的 128-bit 输出和 `video_in` 之间放置单像素模块：`data_96bit_to_128bit` 把连续的 96-bit 流重新分段为 128-bit 字，见 [data_96bit_to_128bit.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/data_96bit_to_128bit.v:39) 的 39–75 行；`video_out` 再按 24-bit 边界跨 128-bit 字拆出像素，见 [video_out.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/video_out.v:174) 的 174–198 行。

## 已确认的处理接口

| 项目 | 已确认事实 | 依据 |
| --- | --- | --- |
| 处理时钟 | AWB、官方边缘模块和自研推荐插点均使用 `S_csi_rx_clk` / `axi4s_video_aclk`。实际频率仍未确认。 | [lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:655) 655–669；[lab_ex2 isp_top.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/isp_top.v:102) 102–119 |
| 复位 | `S_rst_n` 是低有效，直接等于 `S_pll_lock`；自研模块使用同样的低有效异步复位。 | [lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:217) 217–218；[lab_ex2 edge_detect_96.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/edge_detect_96.v:99) 99–113 |
| 原始格式与尺寸 | `raw10_unpacket_2lane` 输出 40-bit RAW10；`uial2axis` 参数为 1280×720、40-bit。 | [lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:593) 593–625 |
| RGB 顺序 | AWB 把每个 24-bit 像素解为 `R=[23:16]`、`G=[15:8]`、`B=[7:0]`；四 lane 输入由高到低为 `[95:72]`、`[71:48]`、`[47:24]`、`[23:0]`。 | [awb.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/isp/awb/awb.v:99) 99–118；[lab_ex2 edge_detect_96.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/edge_detect_96.v:22) 22–32 |
| 每拍像素数 | 推荐插点是 96-bit = 4×RGB888；边缘例程也把每拍分为 4 像素。128-bit DDR 写流不是整数像素拍。 | [awb.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/isp/awb/awb.v:28) 28–38；[lab_ex2 edge_detect_96.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/edge_detect_96.v:22) 22–25 |
| 分辨率 | ISP、边缘模块、HDMI VTC 都配置为 1280×720。HDMI 总帧为 1650×750。 | [lab_ex1 isp_top.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/isp/isp_top.v:49) 49–54；[lab_ex2 edge_detect_96.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/edge_detect_96.v:1) 1–4；[lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:794) 794–811 |
| 帧/行标记 | `uial2axis` 在第一组有效数据上产生 `tuser`，在每行第 320 组有效数据上产生 `tlast`（1280/4）。AWB 的输出 `tlast` 由有效流下降沿生成，不能假定它必与 `tvalid` 同拍；`tuser` 是帧开始。 | [uial2axis.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/uial2axis/uial2axis.v:40) 40–79；[awb.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/isp/awb/awb.v:473) 473–485 |
| 停顿/反压 | 推荐插点没有可用的 `ready` 反压契约：`isp_top` 把 `O_tready` 声明为输入，顶层仅连到未驱动的 `S_ISP_O_tready`；`video_in` 的 FIFO 写使能直接等于 `I_camera_valid`。自研模块不得插入气泡、不得改变 `valid` 的拍数。 | [lab_ex1 isp_top.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/isp/isp_top.v:1) 1–15；[lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:81) 81–85、655–690；[video_in.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/video_in.v:55) 55–72 |

## HDMI 域和现有例程插点

`lab_ex3` 的 OSD 在 DDR 读出之后、`hdmi_tx` 之前，在 `S_hdmi_pixel_clk` 域的 `hdmi_mixer` 内完成；顶层连接见 [lab_ex3 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex3_osd_SC500_720P/lab_ex3_osd/user_source/hdl_source/design_top_wrapper.v:741) 的 741–792 行。该模块以 `I_video_de` 作为读使能，见 [lab_ex3 hdmi_mixer.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex3_osd_SC500_720P/lab_ex3_osd/user_source/hdl_source/hdmi_mixer.v:471)；同步和图像数据均寄存两拍后输出，见 820–845 行；正常模式以 OSD 命中结果覆盖延迟图像，见 900–905 行。

HDMI 像素时钟连接为 `S_hdmi_pixel_clk`，而当前生成的 PLL RTL 注释报告 `clk4_out=75.000000 MHz`（不是 XML 请求值 74.25 MHz），见 [PLL.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/ip_source/PLL/PLL.v:10) 10–18 和 [PLL Design.xml](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/ip_source/PLL/Design.xml:43) 43–59。此差异不影响本阶段独立 RTL，但上板集成前必须单独处置。

## 必须保持的关系

1. 对每个输入拍（包括 `valid=0` 时的同步标记），自研模块输出 `rgb`、`valid`、`de`、`hsync`、`vsync`、`frame_start`、`line_end` 都固定延迟一拍。
2. 在推荐插点实际接入时，`frame_start` 应仅映射为 `tuser`，`line_end` 应仅映射为 `tlast`；`de/hsync/vsync` 在该接口不存在，**仍未确认**其正确映射，因此不能把保留这些端口的通用核心直接接线。第二轮新增的专用适配器只使用前述四个真实流信号。
3. 模式请求仅在 `i_valid && i_frame_start` 时采样；首拍使用新模式，随后本帧锁定。这样既不混合一帧模式，也不增加或删除有效拍。

## 第二轮：真实 96-bit 适配器契约

`custom_axis96_mode_adapter` 是当前可接入推荐插点的模块。它**只有**下表列出的真实流端口；特意不含 `de`、`hsync`、`vsync`，以免把本接口中不存在的信号伪造成来源。端口定义见 [custom_axis96_mode_adapter.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_axis96_mode_adapter.v:4) 的 4–18 行。

| 上游 / 下游 | 适配器端口 | 时钟域与语义 | 延迟 |
| --- | --- | --- | --- |
| AWB `O_tdata` / 重打包器 `I_96b_data` | `i_tdata[95:0]` → `o_tdata[95:0]` | `S_csi_rx_clk`；4 个 `{R,G,B}` RGB888 像素。官方连线位置见 [lab_ex2 isp_top.v](D:/FPGA/HX1P35A_Image/vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/isp_top.v:102) 的 102–132 行。 | 1 个 `i_clk` 上升沿 |
| AWB `O_tvalid` | `i_tvalid` → `o_tvalid` | 无 backpressure；不得增加/删除有效拍。 | 1 个 `i_clk` 上升沿 |
| AWB `O_tuser` | `i_tuser` → `o_tuser` | 帧首，仅在 `tvalid && tuser` 的首个有效拍采样控制。 | 1 个 `i_clk` 上升沿 |
| AWB `O_tlast` | `i_tlast` → `o_tlast` | 行结束标记；仅逐拍转发，不以它改变数据节拍。 | 1 个 `i_clk` 上升沿 |

在有效帧首拍，适配器同时锁存规范化的 `mode_req`（`00` 旁路、`01` 灰度、`10` 二值化、其余归旁路）和 `threshold`；首拍立即使用这对值，随后整帧只使用已锁存值。实现及同步标记同拍寄存见 [custom_axis96_mode_adapter.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_axis96_mode_adapter.v:50) 的 50–84 行。原通用核心也已采用同一“帧首锁存阈值”规则，见 [custom_video_mode_select.v](D:/FPGA/HX1P35A_Image/rtl/custom/custom_video_mode_select.v:55) 的 55–93 行。

适配器内部没有 ready 端口，也不缓存或停顿输入。这与官方 AWB→重打包连接和 `video_in` 直接以 valid 写 FIFO 的关系一致；真实来源依据见本文“停顿/反压”条目。

## 仍未确认

- `S_csi_rx_clk` 的实际频率：源码只显示它由 MIPI D-PHY IP 输出，未发现本工程可直接证明的频率值。[lab_ex1 design_top_wrapper.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:531) 531–567。
- 推荐插点处 `de/hsync/vsync` 的准确生成/映射：该处只有 `tvalid/tuser/tlast`，没有这些端口。不能猜测为 `tvalid` 或 HDMI VTC 信号。
- AWB 输出 `tlast` 与打包器/DDR 写数据的端到端对齐：打包器没有 `tlast` 输入，而顶层单独从 AWB 转接 `O_tlast`；本阶段不修改也不依赖该标记控制数据打包。[lab_ex1 isp_top.v](D:/FPGA/HX1P35A_Image/project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/isp/isp_top.v:95) 95–106。
