# 官方资料索引与版本核对

> 范围：D:\FPGA\HX1P35A_Image\vendor\official_docs  
> 建立日期：2026-09-21  
> 本文仅做只读盘点、版本/哈希核对和资料定位；未覆盖 vendor/lab_ex1、vendor/lab_ex2、vendor/lab_ex3 或 project。

## 1. 完整性清单

official_docs 共 4,017 个文件、661,829,188 字节。

为便于以后确认资料包是否发生变化，本文使用以下目录树摘要：

- 文件按相对路径（统一为 / 分隔符）排序；
- 对每个文件计算 SHA-256；
- 将“相对路径 + NUL + 文件 SHA-256 + LF”串联后再计算 SHA-256；
- 当前树摘要：fcee96746a791266568aa44bc97530a73ebb8e5dbea345210f88a63551a92cfe。

顶层清单：

| 路径 | 文件数 | 主要内容 |
|---|---:|---|
| vendor/official_docs/2_Example | 3,904 | 36 组示例目录，包含源文件、工程文件、IP 生成物和历史结果 |
| vendor/official_docs/3_原理图 | 12 | HX1P35B_FT_40P 板卡原理图 10 页文件，以及 SC500CS 模组资料 |
| vendor/official_docs/4_芯片手册 | 75 | PH1P35、SC500CS 及其他器件资料 |
| vendor/official_docs/6_PH1P35数据手册 | 24 | DS1300、DS1301、UG1316、参考 IP 资料和原始 ZIP |
| vendor/official_docs/安路软件使用完整流程.pdf | 1 | TD 工程、仿真、约束、编译与下载基本流程 |
| vendor/official_docs/（必看）PH1P35烧写程序的使用方法.pdf | 1 | PH1P35 下载器驱动和 AL-LINK-FT 连接配置 |

文件类型统计（完整目录）：

| 扩展名 | 数量 | 扩展名 | 数量 |
|---|---:|---|---:|
| .log | 1,042 | .f | 496 |
| .v | 322 | .logw | 269 |
| .db | 176 | .txt | 175 |
| .timing | 132 | .ts | 100 |
| .status | 98 | .area | 96 |
| .qor | 96 | .prj | 79 |
| .tcl | 77 | .xml | 77 |
| .cfg | 77 | .html | 72 |
| .bat | 69 | .bit | 67 |
| .pdf | 54 | .docx | 38 |
| .adc | 37 | .al | 35 |

这些历史 .bit、日志、时序和面积文件只证明资料包带有旧产物，不代表当前环境可 clean build，也不代表当前板卡已测试通过。

## 2. 与本项目直接相关的官方文档

### 2.1 开发板原理图

| 文件 | 版本/日期 | 用途 | 重要位置 | SHA-256 |
|---|---|---|---|---|
| vendor/official_docs/3_原理图/开发板原理图/HX1P35B_FT_40P_1.pdf | PH1P35_FT V1；2025-04-03 | 封面、板卡名称、FPGA 型号 | PDF 第 1 页 | f2e94b9c419c21eda7fbcf5b2c470b8744e6af6c33adc370bf0a2ff00cee0618 |
| .../HX1P35B_FT_40P_2.pdf | 同一套图纸 | DDR3 与差分参考时钟 | PDF 第 1 页；DDR100M_P=K5、DDR100M_N=L5 | 539284dbf41f47e293fb2232a72dbbad7008dee438b62ed316d6bc9f4932a2e7 |
| .../HX1P35B_FT_40P_3.pdf | 同一套图纸 | FPGA Bank、按键、JTAG、MIPI 控制与 D-PHY 固定管脚 | PDF 第 1 页 | 7e122628feade09ffc39d76eca112fa3504a14aadd02e07ba62a227595f4171d |
| .../HX1P35B_FT_40P_4.pdf | 同一套图纸 | FPGA 供电/去耦 | PDF 第 1 页 | 8ff685d5254cd470bc2c8437e777ba5ac94681093fbc65b4fedf4c94598ce3ed |
| .../HX1P35B_FT_40P_5.pdf | 同一套图纸 | 板上外设连接 | PDF 第 1 页 | 21c5ca5581b83d481a43b9fd94ef4c1c814a5b1c1a60f6bf9737acba95637122 |
| .../HX1P35B_FT_40P_6.pdf | 同一套图纸 | 板上外设连接 | PDF 第 1 页 | 36fcb60d96a1c2d93ae5744254be10356d280708ac1d0201d761dcffb6d7d610 |
| .../HX1P35B_FT_40P_7.pdf | 同一套图纸 | 板上外设连接 | PDF 第 1 页 | 0abd6cb77d9597f5fea904d2d3616f42267a6d3d10a725b9f42c8b47f4c0e900 |
| .../HX1P35B_FT_40P_8.pdf | 同一套图纸 | 50 MHz、100 MHz 差分晶振及 SPI Flash | PDF 第 1 页 | 403e6dc2bf4952c060f3f5b5e0ccc9533e840e2c096c7c9563bc1a4a654c935c |
| .../HX1P35B_FT_40P_9.pdf | 同一套图纸 | 电源部分 | PDF 第 1 页 | 139882bd3050d459b23d7226376e809cafb82f11d25306a15192eabfe0aa77f4 |
| .../HX1P35B_FT_40P_10.pdf | 同一套图纸 | J9 MIPI 连接器 40 个电气触点及 2 个固定/接地脚 | PDF 第 1 页 | 733fd56e68cff04d62daa3c96e7cbfe80d24498a81e20406354cbf4e36a875fa |

原理图封面给出的准确名称是 HX1P35B_FT_40P，图纸标题是 PH1P35_FT V1，器件为 PH1P35MDG324。是否与手中实物完全同版，仍需核对板上丝印。

### 2.2 PH1P35 数据手册

| 文件 | 版本/日期 | 页数 | 用途与重要页码 | SHA-256 |
|---|---|---:|---|---|
| vendor/official_docs/4_芯片手册/PH1P35/DS1300_PH1P_Datasheet.pdf | DS1300 v1.2；2025.08 | 186 | 配置模式：PDF 第 34 页；MSPI x1/x2/x4、Dual/MultiBoot：第 38 页；管脚/电气特性按对应章节 | 5ee95577d31bc2cd14347231be3648d545904c8a2775e6b59d621b73fd1111cd |
| vendor/official_docs/4_芯片手册/PH1P35/DS1301_PH1P_PinOut.pdf | DS1301 v1.1；2025.04 | 14 | PH1P35 封装和专用管脚核对 | f41d134f51a548890f6176e0bb3d5c1a27a784ee6e3e569ed33e238ea59a8258 |
| vendor/official_docs/4_芯片手册/PH1P35/UG1316_PH1P_MIPI_User_Guide.pdf | UG1316 v0.2；2024.07 | 40 | RX 架构：第 8 页；HS/LP 和 lane swap：第 16–18 页；参数/端口：第 19–21 页；GPLL/MLCLK 条件：第 38 页 | 01957909cb1b9bbf4df4a6264c42fa5208216b118dc2d02a72bd7dd01fb39e44 |

上述三个文件在 vendor/official_docs/6_PH1P35数据手册 中存在逐字节相同副本，SHA-256 相同，不应作为两个独立版本解释。

### 2.3 SC500CS 摄像头与转接板

| 文件 | 版本/日期 | 页数 | 用途与重要页码 | SHA-256 |
|---|---|---:|---|---|
| vendor/official_docs/4_芯片手册/SC500摄像头/SC500CS_数据手册_V1.8.pdf | SmartSens Preliminary V1.8；2021-09-26 | 43 | 特性/供电：第 2 页；引脚：第 9–10 页；上电时序：第 11 页；PWDNB/XSHUTDN/I2C 地址：第 13–14 页；模式：第 15 页；MIPI：第 16、18 页；EXTCLK：第 19、33 页 | db987ece862285785498910ca410b35841cd43e57c5293f3a6052c47d34de814 |
| vendor/official_docs/4_芯片手册/SC500摄像头/SC500CS板原理图.pdf | 模组修订说明含 v3/v4 | 2 | 24 个电气触点、2 个固定接地脚；电源、XCLK、PWDNB、MIPI 网名：第 1 页 | 08326089d808033572aa0e03f3477446b71308f2daee22dc8f8d9a9b4ad8fae2 |
| vendor/official_docs/4_芯片手册/SC500摄像头/6504镜头.pdf | 图纸版本见文件 | 1 | 镜头机械资料 | 8eecceab6a5f97962ac4f62ea2d5593654026f74dcba96d82146cf8174979347 |

重复关系：

- vendor/official_docs/3_原理图/摄像头SC500CS/SC500CS_数据手册_V1.8.pdf 与上述 V1.8 数据手册 SHA-256 相同。
- vendor/official_docs/3_原理图/摄像头SC500CS/SC500CS.pdf 与上述 SC500CS板原理图.pdf SHA-256 相同。

### 2.4 参考 IP 资料

| 文件 | 实际版本 | 页数 | 适用性与重要页码 | SHA-256 |
|---|---|---:|---|---|
| vendor/official_docs/6_PH1P35数据手册/参考IP设计资料文档/IPUG012_安路科技软核FIFO用户手册_V3.0.pdf | 文档内页为 IPUG012 v3.1；2026.01 | 20 | 端口：第 7 页；复位：第 9 页；生成文件：第 17 页；异步 FIFO 约束警告：第 18 页 | cd90123bed6086e470b772d8c917e3559c28e33e403a5b8ba0c0146e68a911a3 |
| .../IPUG035_安路科技PH1A系列FPGA_DDR3用户手册_V1.4.pdf | IPUG035 v1.4；2025.07 | 54 | 参考时钟设置：第 13–18 页；初始化/用户模式：第 21–22、28、31–32 页 | a360334e63d91a1600d25ad85c31931b46874907611775871631d15367957e1b |
| .../UG921_安路科技PH1A系列FPGA_MIPI_DPHY用户指南_V1.8.pdf | UG921 v1.8；2025.10 | 27 | 仅 PH1A 系列参考，不可替代 PH1P 的 UG1316 | f560ee05173ab13af503696d1c784e6b087bc0c5d3095e8db568c34d40e4c6ab |
| .../APUG010_安路科技FPGA_SDRAM控制器设计指导_V1.1.pdf | APUG010 v1.1 | 13 | SDRAM 控制器参考，不是本项目 DDR3 控制器 | b1d4724d6717052cda1f0716b50755201ab614966b767123525688926e0a88f2 |
| .../APUG011_安路科技FPGA_SDRAM控制器设计指导_V1.2.pdf | APUG011 v1.2 | 17 | SDRAM 控制器参考，不是本项目 DDR3 控制器 | e20d0365d3647377a019653befce3000e00f29b69b7e9c65f92b4c062b37b9c4 |
| .../APUG013_...UDP...zip | ZIP，内部版本见包内文档 | — | 以太网参考，与当前视频主链非直接依赖 | 03e965a0a5aca4dbc1ba809e693c581526fd999103e12c3d99f99f611727de2b |
| .../APUG092_安路科技FPGA_HDMI_1.4b发送IP用户手册及例程源码_V1.0.zip | APUG092 v1.0；2024.09 | ZIP 25 项 | 包内 doc/APUG092_HDMI1.4b_Transmitter_V1.0.docx 的 §2.2、表 2-2 说明像素时钟/5 倍串行时钟及 AXIS 视频端口 | 291584bf601af7b946951b672f086c7985ecb154357cd121585124468264907c |

原始包 vendor/official_docs/6_PH1P35数据手册/参考IP设计资料文档.zip 已保留，SHA-256 为 d9983085802717556765b0fdb9ebf78dc49c8eed0bdc172c04c48e10d06567fd。包内 7 个顶层资料与旁边已解压目录对应文件逐字节相同；本次只核对结构和哈希，未改包、未覆盖工程。

重要限制：IPUG035 和 UG921 的标题明确为 PH1A 系列。它们可用于解释通用概念，不能作为 lab_ex1 中 PH1P DDR/MIPI 生成核端口的最终规格。PH1P MIPI 应以 UG1316 和实际生成文件为准；PH1P DDR 专用用户手册在当前资料中未找到。

### 2.5 软件、下载器与启动

| 文件 | 页数 | 用途与重要页码 | SHA-256 |
|---|---:|---|---|
| vendor/official_docs/安路软件使用完整流程.pdf | 26 | 新建工程/选器件：第 3 页；语法/展开检查：第 7 页；仿真：第 8–16 页；IO 约束与编译：第 17–19 页；Tools→Download、添加 bit、Run：第 20–22 页 | 1d352d483cc0dd6c4b5d79423d1c7f70305c504bdfeb9a962702ee20d6f2ce22 |
| vendor/official_docs/（必看）PH1P35烧写程序的使用方法.pdf | 3 | WinUSB 驱动和 USB_A VID/PID 0403:6042：第 1 页；AL-LINK-FT、Local Host、端口 5555：第 2 页；未识别/OCCUPIED 处理：第 3 页 | ec8dd1b2de83a3c2968d506e1fe42c2dbdd0c7dd361e831e0ca126240a9ef6ef |

上述流程明确覆盖 SRAM/JTAG bitstream 下载器连接，但没有明确给出 QSPI 擦除、映像格式、起始地址、Program/Verify 以及断电重启验证步骤。因此“下载 bit 文件”不能自动等同于“已经固化到 Flash”。

## 3. 2_Example 完整目录清单

| 示例目录 | 文件数 | 与本项目关系 |
|---|---:|---|
| 0_cnt1s | 77 | 基础计数 |
| 1_breath_led | 77 | LED |
| 2_key_led | 81 | 按键/LED |
| 3_seg_LDE7S | 83 | 数码管 |
| 4_seg_led_static_top | 82 | 数码管 |
| 5_seg_SCAN | 70 | 数码管扫描 |
| 6_cnt10 | 77 | 计数 |
| 7_seg_led | 67 | 数码管 |
| 8_key_sw | 66 | 按键 |
| 9_MUX_buzz | 70 | 蜂鸣器 |
| 10_PLL_TEST | 92 | PLL 参考 |
| 11_Di_TRemble | 80 | 按键消抖 |
| 12_MUL_4B | 80 | 乘法器 |
| 13_music | 109 | 音频 |
| 14_ps2_piano | 72 | PS/2 |
| 15_VGA | 68 | VGA |
| 16_uart_rs232 | 68 | UART |
| 17_DC_MOTO | 96 | 电机 |
| 18_sd_card_audio | 108 | SD/音频，含 FIFO 例程 |
| 19_ball_top | 179 | VGA/图像显示 |
| 20_i2sound_wm8731 | 104 | 音频 |
| 21_liushuideng | 102 | LED |
| 22_jiaotong | 83 | 状态机 |
| 23_SCAN_4X4KEY | 109 | 矩阵键盘 |
| 24_VGA_shiyan9_B | 145 | VGA |
| 25_seg70_small16x16 | 98 | 显示 |
| 26_LCD2004_A | 96 | LCD |
| 27_DAC_SIN | 137 | DAC |
| 28_adda_direct | 116 | ADC/DAC |
| 29_DA2_10B | 118 | DAC |
| 30_LCD_ATK | 75 | LCD |
| 31_GPS | 110 | GPS |
| 32_cs500_mipi_hdmi | 237 | SC500/MIPI/DDR/HDMI，最相关 |
| 33_HX4S20_Etherent_test_01_02_final_1000 | 399 | 以太网 |
| 33_ethernet_udp_led | 240 | 以太网 |
| 示例介绍 | 33 | 示例说明 |

没有从目录名或说明中找到可直接作为 PH1P35 QSPI 固化流程的独立示例。Flash 启动仍需专用官方流程确认。

## 4. 官方示例 32 与三套比赛例程对比

### 4.1 工程版本与整体哈希

| 工程 | 顶层 | 工程文件 | 文件数/字节 | 目录树 SHA-256 |
|---|---|---|---:|---|
| official_docs/2_Example/32_cs500_mipi_hdmi | system_top | td/test.al | 237 / 26,760,292 | 6ef04ef5b650f9354c65379e1a597f6425d35ca214ddf2140d1b3e8177119517 |
| vendor/lab_ex1 | design_top_wrapper | lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al | 313 / 91,098,458 | d1f1462f855bfb96da2e96bd2295f1eb1fab29175e37cec0dd9cc29b8c6f8bb8 |
| vendor/lab_ex2 | design_top_wrapper | lab_ex2_edge/td_project/camera_to_dsi_display.al | 321 / 92,278,830 | 4597c0d08b704c4e3e905f9b44b1e82375592b598346c832df0dc3b26951cf0d |
| vendor/lab_ex3 | design_top_wrapper | lab_ex3_osd/td_project/camera_to_dsi_display.al | 324 / 107,846,475 | b172a471c7873767cb10fa19625818c0c622f31c87a4b0cea7e973ddd4bae218 |

official 示例 32 的 test.al 记录 Project Version 3.2、TD 6.2.168116、器件 PH1P35MDG324；比赛三例程的工程版本也是 TD 6.2.168116 系列，但顶层、文件集和大量生成 IP 配置不同。

### 4.2 文件级对比

以 HDL、约束、工程和 IP 配置等 129 个相关文件为样本：

| 对比对象 | 内容完全相同 | 同名文件 | 同名但哈希不同 |
|---|---:|---:|---:|
| 示例 32 vs lab_ex1 | 34 | 68 | 36 |
| 示例 32 vs lab_ex2 | 34 | 69 | 37 |
| 示例 32 vs lab_ex3 | 34 | 69 | 37 |

完全相同的部分主要包括部分加密 MIPI/HDMI 核、mipi_dphy_rx_ph1p_mipiio_wrapper.sv、csi_unpacket_2lane.v、SC500GainTbl、部分 I2C/视频时序和 DDR RTL。不同的同名文件包括 pin.adc、timing.sdc、pll.v/xml、DDR Design.xml、ph1p_mipiio_rx_wrapper.v、raw10_unpacket_2lane.v、hdmi_tx.v、uii2c.v 和 AWB 等。

结论：official 示例 32 不是 lab_ex1/2/3 的逐版本副本，不能覆盖比赛例程。

### 4.3 示例 32 自身的可疑点

- vendor/official_docs/2_Example/32_cs500_mipi_hdmi/td/test.al 指定顶层 system_top。
- vendor/official_docs/2_Example/32_cs500_mipi_hdmi/src/system_top.v 第 5–6 行的输入名是 I_sys_clk_25m，注释却写 50M。
- 同目录 timing.sdc 对 I_sys_clk 建立 40 ns 时钟，名称与顶层端口不一致；pin.adc 则把 I_sys_clk_25m 绑定 C4。
- system_top.v 第 86 行把 I_ddr_clk 传入 DDR wrapper，但顶层没有 I_ddr_clk 端口或明确驱动；因此它是隐式、未驱动网络。
- 该示例 DDR Design.xml 的 PH1P_REF_CLK 和 PLL0_REFCLK_FREQ 都为 50 MHz，但悬空连接使它不能证明板上 DDR 的正确参考时钟接法。

因此该示例只能作为文件/版本/实现思路参考，不能作为可直接替换的 clean-build 基线。

## 5. 快速结论索引

| 问题 | 当前结论 | 最直接依据 |
|---|---|---|
| 板卡型号/版本 | 原理图为 HX1P35B_FT_40P / PH1P35_FT V1 / 2025-04-03 / PH1P35MDG324；实物丝印仍需核对 | 开发板原理图 _1.pdf 第 1 页 |
| MIPI 40Pin 或 42Pin | 40 个电气触点，另有 2 个固定/接地脚编号 41/42 | 开发板原理图 _10.pdf 第 1 页 |
| 摄像头 24Pin 或 26Pin | 24 个电气触点，另有 2 个固定接地脚编号 25/26 | SC500CS板原理图.pdf 第 1 页 |
| FPC 接触面/插入方向 | 仍未确认 | 当前原理图只给电气编号，没有 A/B 面或插入示意 |
| 启用的 MIPI lane | 物理 D0、D1；P/N 保持；lab_ex1 lane_invert=0000 | 板原理图 _3/_10；相机原理图第 1 页；SC500 数据手册第 18 页；lab_ex1 顶层第 531–567 行 |
| I2C 地址 | 7 位 0x36；lab 表使用 8 位写地址 0x6C | SC500 数据手册第 13–14 页；uicfgcs500_720p.v 第 17 行 |
| MCLK | 允许 6–40 MHz、45–55% 占空比；lab 实际约 23.809524 MHz，位于允许范围 | SC500 数据手册第 19、33 页；lab PLL 配置 |
| PWDN/复位 | XSHUTDN/PWDNB 低有效；低时不响应 I2C；模组 nRST 脚未接 | SC500 数据手册第 13 页；模组原理图第 1 页 |
| DDR 参考时钟 | 仍未确认；lab IP 配 100 MHz 但接 50 MHz；板上同时有 50 MHz 单端和 100 MHz 差分 | lab DDR Design.xml、wrapper；开发板原理图 _2/_8 第 1 页 |
| KEY/JTAG/DDR CLK 引脚 | KEY0–3=D5/A9/B9/C7；JTAG TCK/TDI/TDO/TMS=P15/R13/T13/L14；DDR100 P/N=K5/L5 | 开发板原理图 _2/_3 第 1 页 |
| QSPI 冷启动 | 芯片和板卡支持 MSPI/QSPI，但缺失具体烧写/校验流程 | DS1300 第 34、38 页；开发板原理图 _3/_8；烧写说明第 1–3 页 |
