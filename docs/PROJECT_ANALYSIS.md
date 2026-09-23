# HX1P35A 比赛工程分析（含官方资料交叉核对）

## 0. 范围、方法与结论边界

本报告只分析现有文件，没有修改 RTL、厂商 IP 或引脚/时序约束，也没有运行仿真、重新综合、重新布局布线、下载或上板测试。仓库中的既有日志和 bitstream 只能证明某次工具流程曾产生输出，不能证明当前硬件能稳定显示、能从 Flash 冷启动，或当前源文件与输出镜像完全一致。

实际工作区为 `D:\FPGA\HX1P35A_Image`。`vendor/` 中三套例程均已解包，不存在待解压的 lab ZIP；因此未解压、覆盖或改动任何例程原文件。`docs/reference/synthesis-optimization.zip` 已只读检查目录结构，内容仅为 `synthesis-optimization/README.md` 和 `synthesis-optimization/SKILL.md`，与三套板级例程无关，原压缩包保持不变。【依据：`vendor/`；`docs/reference/synthesis-optimization.zip`】

`project/lab_ex1_mipi_hdmi_SC500_720P/` 与 `vendor/lab_ex1_mipi_hdmi_SC500_720P/` 各有 313 个文件，逐文件 SHA-256 相同。当前 `project/` 不是一个删减后的最小工程，而是 lab_ex1 的完整副本，可以作为后续工作区；`vendor/` 应继续保持只读基线。【依据：`project/lab_ex1_mipi_hdmi_SC500_720P/`；`vendor/lab_ex1_mipi_hdmi_SC500_720P/`】

## 1. 资料与工程清单

### 1.1 比赛与硬件资料

- 赛题 PPT 共 29 页。基础要求是四项中至少完成三项，扩展要求至少一项；所有功能必须集成为同一个最终设计，并固化到板上实现脱离 PC 上电运行。【依据：`docs/reference/赛题解析二 .pptx`，第 5、6、26 页】
- 代码更新说明写明三套 SC500CS 工程统一更新为原厂 1280×720@60 fps HD 配置，lab_ex1 额外保留 1920×1080@30 fps 寄存器表。【依据：`vendor/代码更新说明.txt`】
- 开发板手册标称器件为 PH1P35MDG324，用户时钟为 C4/50 MHz，并列出 MIPI、HDMI、按键、Flash 和 DDR 相关说明。【依据：`docs/reference/新HX1P35A开发板手册-HDL版2604(1).pdf`，PDF 第 5、6、12-15、19、22-25 页】
- 2026-09-21 新加入的 `vendor/official_docs/` 已补充开发板原理图、SC500CS 数据手册/模组原理图、PH1P35 MIPI 指南、HDMI/FIFO 资料以及 PH1A DDR 参考手册；完整版本、页码、SHA-256 和重复文件关系见 `docs/OFFICIAL_DOC_INDEX.md`。仍缺 PH1P 专用 DDR 用户手册、FPC 接触面/插入方向图，以及完整 QSPI 固化操作流程。

### 1.2 三套例程

| 例程 | 顶层模块 | Tang Dynasty 工程 | 器件 | 实际用途 |
|---|---|---|---|---|
| lab_ex1 | `design_top_wrapper` | `vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al` | PH1P35MDG324 | SC500CS 2-lane MIPI RAW10 采集，经 demosaic/AWB、DDR 帧缓存后输出 1280×720 HDMI |
| lab_ex2 | `design_top_wrapper` | `vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/td_project/camera_to_dsi_display.al` | PH1P35MDG324 | 在 lab_ex1 的 ISP 输出路径中加入 `edge_detect_96`，再写 DDR 和输出 HDMI |
| lab_ex3 | `design_top_wrapper` | `vendor/lab_ex3_osd_SC500_720P/lab_ex3_osd/td_project/camera_to_dsi_display.al` | PH1P35MDG324 | 保留 lab_ex1 的采集/DDR 路径，在 DDR 读出后的 `hdmi_mixer` 叠加 Logo、字符和帧计数 |

三份 `.al` 都显式指定 `<MODULE>design_top_wrapper</MODULE>` 和 `<Device>PH1P35MDG324</Device>`。工程源列表分别有 52、53、53 项，逐项检查均存在，没有发现 `.al` 引用的缺失源文件。【依据：三套例程各自的 `td_project/camera_to_dsi_display.al`】

三套例程的工程文件名都叫 `camera_to_dsi_display.al`，但顶层输出实际是 HDMI/TMDS，不是 DSI；这是遗留命名，不能据文件名推断接口。【依据：三套例程各自的 `td_project/camera_to_dsi_display.al` 和 `user_source/hdl_source/design_top_wrapper.v`】

## 2. lab_ex1 的真实数据通路

### 2.1 模块连接与接口契约

| 顺序 | 源 -> 目的 | 数据/标记 | 时钟域 | 依据 |
|---|---|---|---|---|
| 1 | `I_sys_clk` -> `PLL` | 50 MHz 板载输入 | `I_sys_clk` | `.../lab_ex1_mipi_hdmi/user_source/constraints_source/pin.adc`；`.../td_project/camera_to_dsi_display.sdc`；`.../user_source/hdl_source/design_top_wrapper.v` |
| 2 | `PLL` -> 相机配置 | `S_24m_clk` 驱动相机 MCLK、I2C 配置和 AE | 23.809524 MHz | `.../user_source/ip_source/PLL/PLL.v`；`.../user_source/hdl_source/design_top_wrapper.v` |
| 3 | MIPI Pads -> `mipi_dphy_rx_ph1p_mipiio_wrapper` | DPHY0、`LANE_NUM=2`、每 lane 每拍 1 byte，输出 16-bit `S_hs_rx_data` 和 `S_hs_rx_valid` | LP 控制 100 MHz；数据为 DPHY 产生的 `S_csi_rx_clk` | `.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/hdl_source/mipi_dphy_rx/mipi_dphy_rx_ph1p_mipiio_wrapper.sv` |
| 4 | DPHY -> `csi_unpacket_2lane` | 16-bit MIPI 字节流转 32-bit CSI payload；输出 frame-start、frame-end、valid | `S_csi_rx_clk` | `.../user_source/hdl_source/isp/csi_unpacket_2lane.v`；`.../user_source/hdl_source/design_top_wrapper.v` |
| 5 | CSI -> `raw10_unpacket_2lane` | 32-bit packed RAW10 转 40-bit，即每拍 4 个 10-bit Bayer 像素 | `S_csi_rx_clk` | `.../user_source/hdl_source/isp/raw10_unpacket_2lane.v` |
| 6 | RAW10 -> `uial2axis` | 40-bit/4 像素；`tuser` 为帧首，`tlast` 为每行末，`tvalid` 为像素组有效；1280 宽时每行 320 拍 | `S_csi_rx_clk` | `.../user_source/hdl_source/isp/uial2axis.v`；`.../user_source/hdl_source/design_top_wrapper.v` |
| 7 | `uial2axis` -> `isp_top` | 不裁剪，原样传入；BGGR demosaic 后为 4 个 RGB888 像素/96 bit，经 AWB，再连续打包为 128-bit | `S_csi_rx_clk` | `.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/hdl_source/isp/isp_top.v`；`.../user_source/hdl_source/isp/data128_96/data128_96.v`；`.../user_source/hdl_source/awb.v`；`.../user_source/hdl_source/isp/data96_128/data96_128.v` |
| 8 | `isp_top` -> `video_in` -> DDR | 128-bit 连续打包 RGB888；异步 FIFO 从 CSI/ISP 域跨到 DDR 用户域；四帧槽基址为 0、7,000,000、14,000,000、21,000,000 | `S_csi_rx_clk` -> `S_ddr_clk` | `.../user_source/hdl_source/video_in.v` |
| 9 | `video_in`/`video_out` -> `mc_to_user_interface` -> `ph1p35_324_ddr_wrapper` | 25-bit地址、128-bit 数据；当前仲裁写优先，读写请求在同一用户接口复用 | `S_ddr_clk` | `.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/hdl_source/mc_to_user_interface.v`；`.../user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v` |
| 10 | DDR -> `video_out` | 128-bit 帧数据经异步 FIFO 还原为连续 24-bit RGB888 像素 | `S_ddr_clk` -> 75 MHz HDMI pixel clock | `.../user_source/hdl_source/video_out.v` |
| 11 | `uivtc` + `video_out` -> `hdmi_mixer` -> `hdmi_tx` | 1280×720 active，1650×750 total；`DE` 有效期取像，24-bit RGB，输出 TMDS 正端口 | 75 MHz pixel / 375 MHz serial | `.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/hdl_source/hdmi_mixer.v`；`.../user_source/hdl_source/hdmi_tx.v`；`.../user_source/ip_source/PLL/PLL.v` |

以上省略号均指 `vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi`。

### 2.2 分辨率、帧率和像素格式

- 当前激活的相机配置是 SC500CS 1280×720、2-lane MIPI、RAW10，寄存器表注释给出约 480 Mbps/lane；寄存器 `0x3208..0x320B` 也写成 1280×720。顶层实例化的是 `uicfgcs500_720p`，其内部使用 `uics500reg_720p60`。【依据：`vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/user_source/hdl_source/uics500_cfg/uics500reg_720p60.v`；同目录 `uicfgcs500_720p.v`；`.../user_source/hdl_source/design_top_wrapper.v`】
- 输入 Bayer 顺序由 demosaic 参数写死为 `BGGR`。demosaic 后每像素为 24-bit RGB888，AWB 代码按 `[23:16]=R`、`[15:8]=G`、`[7:0]=B` 处理；DDR 中按连续 24-bit 像素流打包进 128-bit 字，不是每像素固定占 32 bit。【依据：`.../user_source/hdl_source/isp/isp_top.v`；`.../user_source/hdl_source/awb.v`；`.../user_source/hdl_source/isp/data96_128/data96_128.v`；`.../user_source/hdl_source/video_out.v`】
- HDMI VTC 参数是 1280×720 active、1650×750 total。PLL 实际输出 75 MHz pixel clock 和 375 MHz serial clock，因此按这些总时序计算的刷新率约为 60.606 Hz，并非标准 74.25 MHz 下的精确 60 Hz。工程和更新说明称“720p60”，但实际时钟应在显示器兼容性测试中单独确认。【依据：`.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/ip_source/PLL/PLL.v`；`vendor/代码更新说明.txt`】
- 名为 `S_24m_clk` 的相机时钟实际是 23.809524 MHz，不是精确 24 MHz；寄存器表按“24 MHz MCLK”描述。是否满足 SC500CS 时钟容差需要数据手册确认，而当前资料缺少该手册。【依据：`.../user_source/ip_source/PLL/PLL.v`；`.../user_source/hdl_source/uics500_cfg/uics500reg_720p60.v`】

### 2.3 复位、启动与 CDC 现状

- 外部 `I_rst_n` 只直接复位 PLL；全局 `S_rst_n` 和 HDMI reset-n 直接等于 PLL lock。CSI、ISP、DDR 用户接口、视频输入/输出均以此作为复位释放条件。【依据：`.../user_source/hdl_source/design_top_wrapper.v`】
- DDR 的 `O_init_calib_complete` 只进入调试状态寄存器，没有门控 `video_in`、`video_out` 或 `mc_to_user_interface`。因此源码无法证明 DDR 校准完成前不会发起访问。【依据：`.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v`】
- `video_in` 和 `video_out` 使用双时钟 FIFO 完成 CSI/DDR、DDR/HDMI 跨域；但顶层对 PLL lock 的释放没有显示的各时钟域同步器。帧首从 CSI 域延长后在 DDR 域三级采样，HDMI vsync 也直接在 DDR 域采样。【依据：`.../user_source/hdl_source/video_in.v`；`.../user_source/hdl_source/video_out.v`】
- 顶层没有形成有效的 ISP backpressure：`isp_top` 的 ready 输入接到一个未见驱动的 wire，ready 输出悬空；视频输入 FIFO 的 full/afull 也未用于回压。当前设计依赖固定吞吐率，不能从接口本身证明拥塞安全。【依据：`.../user_source/hdl_source/design_top_wrapper.v`；`.../user_source/hdl_source/isp/isp_top.v`；`.../user_source/hdl_source/video_in.v`】
- DPHY 的 lane error 已产生，但 `video_in.I_mipi_rx_error` 被固定接为 0，现有帧缓冲切换不会根据真实 MIPI lane error 丢弃坏帧。【依据：`.../user_source/hdl_source/design_top_wrapper.v`】

## 3. lab_ex2、lab_ex3 的可复用内容

### 3.1 lab_ex2

优先复用：

- `user_source/hdl_source/isp/edge_detect_96.v`：输入/输出均为每拍 4 个 RGB888 像素的 96-bit 流，参数为 1280×720、阈值 80；先灰度化，再用两组邻域结果生成黑白 RGB888，输出 `{out0,out0,out1,out1}`。【依据：`vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/edge_detect_96.v`】
- lab_ex2 的 `isp_top.v` 集成方式：`demosaic -> data128_96 -> AWB -> edge_detect_96 -> data_96bit_to_128bit -> video_in/DDR`。这是明确的 DDR 前像素处理插入点。【依据：`vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/isp/isp_top.v`；同例程 `design_top_wrapper.v`】

不要直接当作当前有效链路复用：

- `image_correction.v` 虽在 lab_ex2 目录和 `.al` 源列表中，但顶层明确旁路它，直接把 1280×720 stream 送入 ISP；注释说明旧模块是固定 1024×600 crop。它不是当前 lab_ex2 的活动处理级。【依据：`vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge/user_source/hdl_source/design_top_wrapper.v`；同例程 `td_project/camera_to_dsi_display.al`】

### 3.2 lab_ex3

优先复用：

- `anlogic_logo_rom.v`：160×160 Logo 像素 ROM，由 `hdmi_mixer` 按地址读取，像素为 1-bit alpha + 24-bit color。【依据：`vendor/lab_ex3_osd_SC500_720P/lab_ex3_osd/user_source/hdl_source/anlogic_logo_rom.v`；同例程 `hdmi_mixer.v`】
- `osd_char_lib.v`：供“安路”、`CNT:` 和十进制帧计数使用的字符行位图。【依据：`vendor/lab_ex3_osd_SC500_720P/lab_ex3_osd/user_source/hdl_source/osd_char_lib.v`；同例程 `hdmi_mixer.v`】
- lab_ex3 的 `hdmi_mixer.v` OSD 段：在 DDR 已读出的 RGB888 与 VTC 同步信号对齐后叠加 160×160 Logo 和动态字符/帧计数，再送 `hdmi_tx`。OSD 位于帧缓存之后，不在相机/ISP 写 DDR 路径中。【依据：`vendor/lab_ex3_osd_SC500_720P/lab_ex3_osd/user_source/hdl_source/hdmi_mixer.v`；同例程 `design_top_wrapper.v`】

### 3.3 共享厂商 IP

三套 `user_source/ip_source/` 的对应文件内容相同，lab_ex1 已经带齐共同依赖，无需从 lab_ex2/lab_ex3 再覆盖：PLL、`w128_d512_fifo`、`w155_d512_fifo`、`w40_d512_fifo`、AWB delay RAM、divider 和 MCU；三套也都带相同的 MIPI DPHY wrapper、DDR2 controller/PHY 生成物和 HDMI 1.4b transmitter 加密核。【依据：三套例程的 `user_source/ip_source/` 逐文件 SHA-256 对比；三套 `.al` 源列表】

其中 `w128_d512_fifo` 用于 `video_in/video_out`，`w155_d512_fifo` 用于 `mc_to_user_interface`，divider 用于 AWB。`w40_d512_fifo` 只在遗留/注释代码中出现；`ps_wrapper/MCU` 没有被当前顶层实例化。后续最小化应先确认工具的真实 elaborated source list，再决定是否移除，不能仅凭目录存在就认为 IP 在活动数据通路中。【依据：lab_ex1 的 `video_in.v`、`video_out.v`、`mc_to_user_interface.v`、`awb.v`、`raw10_unpacket.v`、`ps_wrapper.v` 和 `design_top_wrapper.v`】

由于 lab_ex1 与 lab_ex2/lab_ex3 的 `design_top_wrapper.v`、`video_in.v`、`hdmi_tx.v`、相机寄存器表等还有版本差异，建议只移植上述算法/OSD模块和明确的连接改动，不要用 lab_ex2 或 lab_ex3 整棵目录覆盖 lab_ex1。【依据：三套 `user_source/` 逐文件 SHA-256 对比】

## 4. PPT、手册、约束与工程的不一致

### 4.1 官方资料加入后的核对结论（2026-09-21）

本节是当前结论；后面的原始差异表保留为首次分析记录。若二者冲突，以本节和 `docs/OFFICIAL_DOC_INDEX.md` 为准。

| 项目 | 当前结论 | 依据 |
|---|---|---|
| 开发板型号和版本 | 官方原理图文件名为 **HX1P35B_FT_40P**，封面标题为 **PH1P35_FT V1**，日期 2025-04-03，FPGA 为 PH1P35MDG324。器件型号与三套工程一致；实物是否同版仍要核对 PCB 丝印。 | `vendor/official_docs/3_原理图/开发板原理图/HX1P35B_FT_40P_1.pdf`，PDF 第 1 页；三套 `.al` 的 Device 节点。 |
| MIPI 40Pin/42Pin | 已解决计数口径：板端 J9 是 **40 个电气触点**，另有 2 个固定/接地脚编号 41、42。可称 40P 连接器，不应把固定脚解释成额外信号。 | `vendor/official_docs/3_原理图/开发板原理图/HX1P35B_FT_40P_10.pdf`，PDF 第 1 页。 |
| 相机 24Pin/26Pin | SC500CS 模组 J1 是 **24 个电气触点**，另有 2 个固定接地脚编号 25、26。 | `vendor/official_docs/4_芯片手册/SC500摄像头/SC500CS板原理图.pdf`，PDF 第 1 页。 |
| FPC 方向 | **仍未确认**。现有原理图给出了管脚号和网络名，但没有 FPC 同面/异面、金手指朝向或插入方向图；不能仅凭编号下结论。 | 同上两份连接器原理图；未发现机械插接示意。 |
| MIPI lane 和极性 | lab_ex1 的 LANE_NUM=2，实际启用传感器 D0、D1 到 FPGA DPHY0 lane0、lane1；lane_invert=4'b0000，原理图网络保持 P/N。模块输出拼字把 lane1 放低字节、lane0 放高字节，这是核内并行打包顺序，不是物理差分对互换。 | 开发板原理图 `_3.pdf`、`_10.pdf` 第 1 页；SC500CS 板原理图第 1 页；SC500CS 数据手册第 18 页；lab_ex1 `design_top_wrapper.v` 第 531–567 行、`ph1p_mipiio_rx_wrapper.v` 第 239–269/480–506 行、`mipi_dphy_rx_ph1p_mipiio_wrapper.sv` 第 60 行附近。 |
| SC500CS I2C | 7 位地址为 0x36（SID 低）；SID 高时为 0x10。lab_ex1 的 CAM_ID=8'h6c 是 0x36 左移后的 8 位写地址表达。I2C Fast-mode 上限 400 kHz。 | `SC500CS_数据手册_V1.8.pdf` 第 13–15 页；lab_ex1 `uicfgcs500_720p.v` 第 17 行。 |
| SC500CS MCLK | EXTCLK 允许 6–40 MHz，占空比 45–55%，高/低时间至少 5 ns。lab_ex1 PLL 输出 23.809524 MHz，在允许范围内；但模组原理图修订注记写“无晶振，主机提供 27M”，寄存器表注释按 24M，三者口径不同。允许范围明确，但该 720p 表是否对 23.809524 MHz 做了精确 PLL/帧率适配仍需实测或原厂寄存器说明。 | 数据手册第 19、33 页；SC500CS 板原理图第 1 页修订说明；lab_ex1 PLL 配置及 `design_top_wrapper.v` 第 482–483 行。 |
| PWDN/复位与上电 | 传感器 XSHUTDN/PWDNB 低有效，低时为硬复位且 I2C 不响应；软件复位为 0x0103[0]=1。模组的 MIPI_CSI_nRST 脚未接，板端 PWDNB 经电平转换连接 XSHUTDN。数据手册上电序列要求各电源间隔、EXTCLK/PWDNB 和 I2C 起始延时；lab_ex1 只把 O_cam_rst 常置 1，没有独立时序状态机。 | 数据手册第 11、13 页；模组原理图第 1 页；开发板原理图 `_3.pdf`、`_10.pdf` 第 1 页；lab_ex1 顶层第 482 行。 |
| RAW/lane 模式 | SC500CS 支持 1/2 lane 和 RAW8/RAW10；默认寄存器值对应 2 lane、RAW10，lab_ex1 的 720p 表未覆盖这些 lane/polarity 默认项。 | 数据手册第 15、16、18 页；lab_ex1 `uics500reg_720p60.v`。 |
| DDR 板级时钟 | 原理图确认板上既有 C4 的 50 MHz 单端系统时钟，也有 K5/L5 的 100 MHz 差分 DDR 时钟，P=K5、N=L5。它解决了旧手册 P/N 标注问题，但没有解决 lab_ex1 应接哪一路。 | 开发板原理图 `_2.pdf`、`_8.pdf`，各 PDF 第 1 页。 |
| DDR ref_clk | **仍未确认且存在实质冲突**：lab_ex1 DDR Design.xml 配置 PH1P_REF_CLK=100、PLL0_REFCLK_FREQ=100；生成 wrapper 却把受 50 MHz 约束的 I_sys_clk 直接接 ref_clk。官方示例 32 的 DDR IP 配 50 MHz，但它的 I_ddr_clk 在 system_top 中未声明/未驱动，不能作为正确连接证据。不能自行改接 100 MHz 差分或 PLL 输出。 | lab_ex1 `ph1p35_ddr/ddr2/Design.xml` 第 13–14、83 行附近，`ph1p35_324_ddr_wrapper.v` 第 79 行；开发板原理图；官方示例 32 `src/system_top.v` 第 86 行及其 DDR `Design.xml`。 |
| DDR ref_clk/dhi_clk/校准信号 | 根据实际生成核，ref_clk 是 DDR IP 参考输入；dhi_clk 由 DDR IP 输出并被 wrapper 当作 DDR 用户/pAXI 接口时钟；ddrphy_rdy 被导出为 O_init_calib_complete。PH1A 手册说明“校准完成”代表 PHY 初始化/训练完成后进入用户模式，但当前没有 PH1P DDR 专用手册，故 dhi_clk 精确频率和 PH1P 端口契约仍未确认。 | lab_ex1 `ddr2.v` 第 12、23、27 行和 `ph1p35_324_ddr_wrapper.v` 第 60–61 行；`IPUG035_安路科技PH1A系列FPGA_DDR3用户手册_V1.4.pdf` 第 21–22、28、31–32 页。 |
| HDMI IP 时钟 | 官方 APUG092 要求 pixel clock 和 5× serial clock；AXIS 视频与核心视频逻辑在 pixel clock 域，输入视频行需连续。lab_ex1 的 75/375 MHz 满足 5×关系，但 75 MHz 不是标准 720p 74.25 MHz，必须以接收端兼容性/实测为准。 | `APUG092_安路科技FPGA_HDMI_1.4b发送IP用户手册及例程源码_V1.0.zip` 内 `doc/APUG092_HDMI1.4b_Transmitter_V1.0.docx` §2.2、表 2-2；lab_ex1 PLL 和 `hdmi_tx.v`。 |
| PH1P MIPI D-PHY | UG1316 明确 RX 可配置 lane swap、HS/LP 状态，输出数据位于 o_fabric_div4_8_clk 域；端口和复位要求应以 UG1316 加实际 PH1P wrapper 为准。PH1A 的 UG921 只能参考。 | `UG1316_PH1P_MIPI_User_Guide.pdf` 第 8、16–21、38 页；实际 wrapper。 |
| FIFO IP | wrst/rrst 为异步高有效，srst 为同步高有效，rst 为异步置位/同步释放；异步 FIFO 不应对其两时钟简单设置 clock_groups/false_path，否则核内 Gray-code set_max_delay 可能失效。 | `IPUG012_安路科技软核FIFO用户手册_V3.0.pdf`（内页 v3.1）第 7、9、17–18 页。 |
| KEY | 原理图标号 KEY0–KEY3 分别为 D5/A9/B9/C7；如果用户界面称 KEY1–KEY4，需明确它是同一组按键的人类序号偏移。lab_ex1 的 I_button[1:0]=N2/J14，并非这四个 KEY。 | 开发板原理图 `_3.pdf` 第 1 页；lab_ex1 `pin.adc`。 |
| JTAG | TCK=P15、TDI=R13、TDO=T13、TMS=L14，解决旧手册把 TCK/TDI 都写 R13 的冲突。 | 开发板原理图 `_3.pdf` 第 1 页。 |
| QSPI/冷启动 | DS1300 支持 MSPI x1/x2/x4；板上模式电阻为 M[2:0]=001，板上有配置 SPI Flash。但当前两份软件流程只明确 bit 下载和下载器连接，没有给出 Flash 擦除/地址/映像/校验/断电启动流程，故仍不能声称具备可靠固化流程。 | `DS1300_PH1P_Datasheet.pdf` 第 34、38 页；开发板原理图 `_3.pdf`、`_8.pdf` 第 1 页；两份软件流程 PDF。 |
| 官方示例 32 | 与三套比赛例程不是同版本。它的顶层、源集、约束和多份同名 IP 文件不同，而且顶层时钟命名和 DDR 输入本身有悬空/不一致，禁止用它覆盖比赛例程。 | `docs/OFFICIAL_DOC_INDEX.md` 第 4 节；官方示例 32 的 `test.al`、`system_top.v`、`timing.sdc`、`pin.adc`。 |

### 4.2 首次分析记录

| 项目 | 实际发现 | 结论/处理 |
|---|---|---|
| 例程分辨率 | PPT 第 17、18 页仍写 lab_ex2/lab_ex3 为 1024×600；三个实际顶层、VTC、ISP 和更新说明均为 1280×720 | PPT 的例程分辨率说明已过期，以当前工程为准。【依据：`docs/reference/赛题解析二 .pptx` 第 17、18 页；`vendor/代码更新说明.txt`；三套 `design_top_wrapper.v`】 |
| MIPI 接口针数 | PPT 第 10 页写板端 FPC40，PPT 第 11 页写 40P 转 24P 软线；手册第 13 页写板端 42 脚 FPC，并出现不合理的“40 组差分数据线” | 无原理图时不能确认连接器针数、转接板方向和 lane 顺序。【依据：`docs/reference/赛题解析二 .pptx` 第 10、11 页；开发板手册 PDF 第 13 页】 |
| MIPI lane | 手册列 4 组 data lane；当前工程 DPHY 实例只启用 2 lane，顶层 pad 仍声明 4 组 | 当前逻辑是 2-lane；未启用 pad 与实际 FPC 连接必须由原理图确认。【依据：开发板手册 PDF 第 13 页；lab_ex1 `design_top_wrapper.v` 和 `mipi_dphy_rx_ph1p_mipiio_wrapper.sv`】 |
| FPGA 资源数 | PPT：38184 LUT、42432 DFF；手册：38189 LUT、42434 DFF | 不应用二者作为提交资源数据，最终应引用当前器件/工具的实际报告。【依据：PPT 第 8 页；开发板手册 PDF 第 5 页】 |
| Flash 容量单位 | PPT 写 QSPI Flash 128MB、SPI Flash 64MB；手册写 N25Q128 为 128Mb，并另列 GD25WQ128 | PPT 至少存在 MB/Mb 风险；不要据此规划镜像容量。【依据：PPT 第 10 页；开发板手册 PDF 第 19、22 页】 |
| JTAG 表 | 手册把 TCK 和 TDI 同时列为 R13 | 该表存在重复引脚，不能用于约束。【依据：开发板手册 PDF 第 11 页】 |
| DDR 差分时钟表 | 手册第 25 页两端都标为 `LVDS_N`，分别为 L5/K5 | 极性标签明显不完整，不能据此写约束。【依据：开发板手册 PDF 第 24、25 页】 |
| DDR 参考时钟 | 手册称板上有 100 MHz 差分 DDR 时钟；DDR IP 的 `Design.xml` 也声明 100 MHz ref；但当前顶层无该差分输入，`ph1p35_324_ddr_wrapper` 把受 50 MHz 约束的 `I_sys_clk` 直接接到 DDR `ref_clk` | 这是最需要向厂商核实的工程/配置矛盾。不要猜测应改接哪个时钟。【依据：开发板手册 PDF 第 24、25 页；lab_ex1 `ph1p35_ddr/ddr2/Design.xml`、`ph1p35_324_ddr_wrapper.v`、`design_top_wrapper.v`、`pin.adc`、`camera_to_dsi_display.sdc`】 |
| HDMI 引脚 | 工程约束的正端 G16/F17/H14/C17 与手册表一致；负端由差分输出资源处理，没有在顶层 ADC 中单列 | 已确认正端一致，但完整 TMDS 极性仍应以原理图和厂商差分资源规则为准。【依据：lab_ex1 `pin.adc`；开发板手册 PDF 第 14、15 页】 |
| 按键 | 手册列 KEY1-4 为 D5/A9/B9/C7；例程只约束 `I_button[1:0]` 到 N2/J14，并将其用于 AE 控制 | 例程按键不是按手册表直接映射的四个板载 KEY；其物理来源不明，需原理图确认。【依据：开发板手册 PDF 第 22、23 页；lab_ex1 `pin.adc` 和 `design_top_wrapper.v`】 |
| 工程元数据 | 三份 `.al` 的保存路径含 `anlogic_example_SC520CS`，实际目录和相机模块为 SC500CS | 这是遗留路径字符串，导入工程时应注意绝对路径污染，但不据此改相机型号。【依据：三套 `camera_to_dsi_display.al`；三套 `uics500_cfg/`】 |
| 1080p 备用表 | 更新说明说 lab_ex1 保留 1080p30 表；该表注释又说默认“不加入工程源文件列表”，但实际 lab_ex1 `.al` 已把它列入，顶层仍只实例化 720p 配置 | 1080p 模块被编译但未实例化；不能视为可切换模式。【依据：`vendor/代码更新说明.txt`；lab_ex1 `uics500reg_1080p30.v`、`uicfgcs500_720p.v`、`camera_to_dsi_display.al`】 |

三套例程的 `pin.adc`、空的 `user_source/constraints_source/timing.sdc` 和实际使用的 `td_project/camera_to_dsi_display.sdc` 哈希完全相同。`.al` 把 `pin.adc` 和项目目录下的 `camera_to_dsi_display.sdc` 加入 `constraint_1`；空的 `timing.sdc` 没有被加入工程。【依据：三套 `camera_to_dsi_display.al`、`pin.adc`、`td_project/camera_to_dsi_display.sdc`】

## 5. 缺失项与待确认信息

### 5.1 官方资料核对后的剩余缺口（当前）

1. **实物板卡版本**：资料已确定原理图为 HX1P35B_FT_40P / PH1P35_FT V1，但尚无实物 PCB 正反面丝印和 BOM/ECN 证据，不能保证手中板与 2025-04-03 图纸完全一致。
2. **FPC 机械方向**：已解决 40+2 和 24+2 的电气触点计数，但仍缺同面/异面 FPC 型号、连接器触点朝向、插入方向照片或机械图。这会直接阻止安全连接相机。
3. **PH1P DDR 专用文档或已知正确工程**：当前只有 PH1A IPUG035 和存在悬空连接的 official 示例 32。仍需能明确 lab_ex1 生成核 ref_clk 频率/类型、dhi_clk 频率及 ddrphy_rdy 时序的 PH1P 文档或厂家答复。
4. **SC500CS 720p 寄存器表的时钟依据**：传感器允许 6–40 MHz，23.809524 MHz 在电气范围内；但寄存器表按 24M 注释、模组图写主机 27M。仍需确认该表在 23.809524 MHz 下的精确帧率/MIPI 速率和 PLL 设置。
5. **相机上电/复位的板级实现说明**：数据手册给出低有效 XSHUTDN 和上电间隔，但 lab_ex1 只常置高；需确认配置期间 FPGA IO 状态、板上电源稳定时间和是否由外部电路满足时序。
6. **QSPI 固化操作手册**：缺 Flash 器件选择、映像格式、地址、擦除、Program/Verify、保护位和冷启动验证步骤。现有“Download bit”流程只足以规划易失下载测试。
7. **当前工具链可用性**：尚未在本阶段检查本机是否安装/授权 TD v6.2.168116、PH1P35 器件库和相应 MIPI/DDR/HDMI IP，也没有执行 clean build。
8. **当前验证证据**：没有本次 clean build 日志、生成 bitstream 的时间戳/SHA-256、当前 timing/resource 报告、ILA/ChipWatcher 数据、上板照片/视频、掉电重启记录。

### 5.2 首次分析时列出的缺失项（历史）

按阻塞程度排序：

1. **开发板原理图和准确板卡版本**：用于解决 FPC 40/42 针、MIPI lane 顺序/极性、DDR 100 MHz 差分时钟、按键和 JTAG 表冲突。【依据：`docs/reference/` 中未发现原理图；PPT 第 12 页承诺提供原理图】
2. **SC500CS 模组与转接板资料**：需要模组版本、24P/40P 转接原理图、FPC A/B 面和插入方向、上电时序、I2C 地址、MCLK 容差、2-lane RAW10 时序/速率。现有寄存器表不能替代硬件连接说明。【依据：PPT 第 11 页；`vendor/.../uics500_cfg/`】
3. **DDR IP 的官方配置说明或已知可工作的原始工程说明**：必须解释 100 MHz IP ref 设置与 50 MHz 实际连接，以及 `dhi_clk` 的真实频率和地址单位。【依据：lab_ex1 `ph1p35_ddr/ddr2/Design.xml`、`ph1p35_324_ddr_wrapper.v`】
4. **HDMI/MIPI/DDR/FIFO IP 手册**：PPT 第 19 页只列名称，文件未提供；加密 IP 端口和差分引脚行为不能猜测。【依据：PPT 第 19 页；`docs/reference/` 文件清单】
5. **可复现构建说明**：当前没有根目录 README、工具安装路径、license/器件库说明或一键构建脚本。既有日志显示曾用 Tang Dynasty v6.2.168116，但本次没有重跑。【依据：lab_ex1 `td_project/camera_to_dsi_display_Runs/syn_1/run.log` 和 `phy_1/run.log`；根目录文件清单】
6. **验证资产**：未发现视频链路自检 testbench；也没有相机画面、HDMI 稳定时长、Logo、模式切换、Flash 冷启动的照片/视频/记录。【依据：`vendor/`、`project/`、`docs/` 文件清单】

## 6. 以 lab_ex1 建立最小可运行工程的下一步

### 6.1 当前建议顺序（官方资料核对后）

详细操作与验收门槛见 `docs/BASELINE_BUILD_CHECKLIST.md`。本阶段不执行这些会改动工程或产生构建产物的动作。

1. **冻结基线并记录哈希**：保持 `vendor/lab_ex1_mipi_hdmi_SC500_720P` 只读；未来在一次性工作副本中进行 clean build。构建前再次确认它与当前 `project/lab_ex1_mipi_hdmi_SC500_720P` 的 313 个文件逐文件 SHA-256 相同。
2. **确认工具前提**：确认 TD v6.2.168116、PH1P35MDG324 器件库、许可证和生成 IP 均可用；确认工程顶层是 design_top_wrapper，活动约束是工程 `.al` 实际引用的 pin.adc 与 camera_to_dsi_display.sdc。
3. **先做未修改 clean build**：只在新工作副本清除历史 Runs/best_result 或使用工具的 Clean/Reset 功能；完整运行综合、布局布线和 bitgen。保留完整日志、warnings、资源、setup/hold、生成 bitstream 的 SHA-256。历史 bitstream/日志不得计入本次验收。
4. **建立构建闸门**：出现缺 IP、许可证、绝对路径、未约束端口、时钟定义失败、DDR 参考时钟警告或 timing violation 时停止，不进入上板。build 成功也只证明工具实现完成，不证明硬件链路正确。
5. **上板前解决硬阻塞**：核对实物板版本和 FPC 插接方向；从 PH1P DDR 官方资料/厂家确认 ref_clk 的来源和频率；确认相机 23.809524 MHz/寄存器表及上电复位时序。未经确认不得靠试插 FPC 或猜测改 DDR 时钟。
6. **先做易失下载 smoke test**：按软件流程第 20–22 页和 PH1P35 烧写说明第 1–3 页配置 AL-LINK-FT 后，只下载本次 clean build 的 bit 文件；依次验证时钟、I2C ID/ACK、MIPI HS/frame、DDR 校准、DDR 读写和 HDMI。
7. **最后才做 QSPI 固化**：拿到明确的 PH1P35/板卡 Flash 操作说明后，执行擦除、编程、校验和完全断电冷启动；不能把 SRAM/JTAG 下载成功记为非易失启动成功。

### 6.2 首次分析给出的路线（历史）

当前建议的“最小可运行”定义是：SC500CS 2-lane RAW10 1280×720 -> demosaic/AWB -> DDR 帧缓存 -> 1280×720 RGB888 HDMI；暂不加入 edge、OSD、模式切换和 1080p。

1. **冻结基线**：保持 `vendor/` 不动，以当前与 vendor 完全相同的 `project/lab_ex1_mipi_hdmi_SC500_720P/` 为工作工程。工程入口是 `project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`。
2. **先补硬件证据**：取得原理图和转接板/SC500CS 资料，核对板号、FPC 方向、2-lane 顺序、MCLK、I2C、复位/掉电和电源时序。没有这些资料前不改 MIPI IP 或 pin ADC。
3. **解决 DDR ref 阻塞项**：向例程提供方确认 DDR IP 应使用板上 100 MHz 差分时钟、PLL 100 MHz，还是 50 MHz `I_sys_clk`。得到官方依据后再决定修改；当前不能凭猜测改端口或时钟。
4. **补全启动条件设计评审**：确认 DDR 校准完成是否必须门控帧 FIFO、仲裁器和 HDMI 读请求；确认 PLL lock 的异步释放是否需要各域同步。此步骤先形成接口/时序决定，再进入 RTL 修改。
5. **在相同工具版本全量重建**：用 Tang Dynasty v6.2.168116 打开 `.al`，核对器件、顶层、52 项源列表和两个活动约束文件，从 clean run 重新综合、布局布线和生成 bitstream，保存 warnings、资源和每个时钟域的 timing。不要把仓库现有 bitstream 当作本次 clean build 结果。
6. **分段上板检查**：先验证相机 MCLK/I2C 配置完成，再确认 MIPI HS、连续 frame-start、每行 400 个 32-bit CSI payload word、720 行、DDR calibration、DDR 读写和 HDMI 锁定。现有顶层包含若干“seen”调试寄存器，但 `hdmi_mixer.DEBUG_MODE` 当前为 0，且 ChipWatcher 实例被注释；具体观测方式要在下一阶段设计，不能声称已观测。
7. **最小画面稳定后再集成**：从 lab_ex2 只引入 `edge_detect_96` 及其在 AWB 后/DDR 前的连接；从 lab_ex3 引入 `anlogic_logo_rom`、`osd_char_lib` 及 DDR 后 `hdmi_mixer` OSD 路径。最终再加入按键选择，并在帧边界切换，保持单 bitstream。
8. **最后做提交 QA**：分别记录 live camera、处理后 HDMI、安路 Logo、切换稳定性和断开 PC 后 Flash 冷启动。文件存在、历史 timing 或历史 bitstream 均不能替代这些板上证据。

## 7. 当前证据状态

官方资料索引和版本核对已经完成，见 `docs/OFFICIAL_DOC_INDEX.md`。这提高了“可安排 clean build”的资料完备度，但没有改变任何编译或上板状态。

| 检查项 | 状态 | 证据与解释 |
|---|---|---|
| 三套例程源列表完整 | pass（文件层面） | `.al` 分别引用 52/53/53 项，均存在 |
| 顶层/器件/活动约束已定位 | pass（文件层面） | 三套 `.al`、`pin.adc`、`camera_to_dsi_display.sdc` |
| 历史综合/布局布线输出 | 已发现，未重跑 | lab_ex1 现有日志显示 Tang Dynasty v6.2.168116 曾完成 bitgen；`final_timing.rpt` 记录 global setup slack 1.408 ns、hold slack 0.020 ns。只作为历史文件证据，不证明当前 clean build 或板上功能 |
| RTL 仿真 | not tested | 未发现 testbench，本次未运行仿真 |
| 摄像头到 HDMI 实机画面 | not tested | 无板上观察记录 |
| edge、OSD 实机效果 | not tested | 仅确认源码连接位置 |
| 单 bitstream 模式整合 | not tested | 三个例程仍是三套独立工程 |
| Flash 冷启动 | not tested | 有历史 bitstream 和下载器说明，但无完整 QSPI 擦除/编程/校验流程，也无断电重启观察记录 |
| official_docs 完整性 | documented | 4,017 个文件；目录树 SHA-256、相关文档版本/页码和示例对比见 `docs/OFFICIAL_DOC_INDEX.md` |
| 未修改 lab_ex1 clean build | not run | 本阶段禁止改工程并未调用 TD；需按 `docs/BASELINE_BUILD_CHECKLIST.md` 执行 |
| 上板前硬阻塞 | open | DDR ref_clk 冲突、FPC 插接方向、实物板版本、相机时钟/上电时序和 QSPI 固化流程尚未闭环 |

历史工具结果依据：`vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display_Runs/phy_1/run.log`、同目录 `final_timing.rpt` 和 `best_result/`。本报告不把这些结果表述为仿真通过或上板通过。
