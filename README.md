# HX1P35A 图像处理实验

本项目面向安路 HX1P35A 开发板（FPGA：PH1P35MDG324），目标是在 SC500CS MIPI 摄像头到 DDR 帧缓存、HDMI 显示的例程链路中加入可切换的自研图像处理。计划的插点是 AWB 输出与 `data_96bit_to_128bit` 之间的 96-bit RGB888 流，每拍四个像素。实际板卡和接口依据见 [视频接口说明](docs/VIDEO_PIPELINE_INTERFACE.md)与[集成准备](docs/LAB_EX1_INTEGRATION_PREP.md)。

## 当前自研内容

- `rtl/custom/`：RGB 直通、定点灰度、参数化二值化、三模式 AXIS96 适配器，以及四像素并行 Sobel。Sobel 使用两拍固定延迟，行缓存由独立 PH1P35 综合实验确认映射为 ERAM。
- `sim/custom/`：Icarus 自检平台、运行脚本和文本证据。现有适配器测试结果为 `errors=0`；Sobel 测试结果为 `valid=173 marker=216 reset=4 hardcoded=7 errors=0`。
- `qa/`：独立 RAM 模板与 Sobel `opt_gate` 检查工程的可重复运行源码、脚本、TD 项目文件和配置。Sobel 独立综合的 `gate.area` 口径为 LUT 1039、REG 155、SLICE 976、ERAM20K 3、DRAM LUT 0、DSP 12；这不是完整工程的资源或布局布线结果。详见 [综合报告](docs/CUSTOM_SOBEL_SYNTH_REPORT.md)。

计划中的四模式 `custom_processing_top`（直通、灰度、二值化、Sobel）尚未编写，也尚未接入 lab_ex1。完整视频工程没有针对自研模块执行 place/route、bitgen、下载或上板测试。

## 复现范围

在原工作机上可运行 `sim/custom/run_iverilog.ps1` 与 `sim/custom/run_sobel_iverilog.ps1`。脚本目前使用 `D:\iverilog\bin`；`qa/` 的 TD 脚本使用 `D:\TD`。迁移到其他电脑时，需要先调整这些本机工具路径。独立 TD 检查目标为 PH1P35MDG324、Speed -3，工具版本为 Tang Dynasty 6.2.168116；运行步骤见 [综合报告](docs/CUSTOM_SOBEL_SYNTH_REPORT.md)。

公开仓库候选范围不包含官方例程、厂商 IP、原理图、官方 PDF、当前完整工程或任何历史 bitstream。因此，仅凭本仓库不能构建摄像头到 HDMI 的完整镜像。`docs/` 中的历史报告保留了证据路径和结果；其引用的部分厂商文件与原始 TD 日志不随公开仓库提供。

## 板级状态

未修改 lab_ex1 曾在本机完成一次 GUI clean build 和 bitgen，但当前 bitstream **禁止直接下载到开发板**。复核发现 DDR IP 配置的 100 MHz 参考输入实际接入 50 MHz，相关 PLL VCO 计算值低于器件手册范围；两个异步 FIFO 的 36 条灰码跨域最大延迟约束被忽略，另有未约束时序对象和相机 24 MHz 关键路由告警。自研 RTL 集成后还必须重新完成完整工程构建与验证。详情见[基线上板就绪性审查](docs/BASELINE_BOARD_READINESS.md)与[集成准备](docs/LAB_EX1_INTEGRATION_PREP.md)。

目前未验证摄像头实时画面、HDMI 输出、DDR 校准/读写、按键模式切换或 QSPI 断电启动。历史 bitstream、历史日志和源码存在不构成这些测试通过的证据。
