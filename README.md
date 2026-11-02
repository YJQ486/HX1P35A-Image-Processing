# HX1P35A 实时图像处理系统

基于安路 HX1P35A 开发板（PH1P35MDG324）的实时数字图像处理系统。SC520CS 摄像头经 MIPI CSI-2 输入，FPGA 完成去马赛克、白平衡、图像处理和目标检测，经 DDR2 帧缓存后以 1280×720@60 Hz 输出到 HDMI，并叠加安路 Logo、状态面板和检测框。

## 功能

|功能|说明|操作|
|---|---|---|
|视频采集与显示|SC520CS RAW10 → ISP → DDR2 帧缓存 → HDMI 1280×720|上电自动运行|
|四种显示模式|彩色、灰度、铅笔素描、Sobel 边缘检测|短按模式键（B9）循环切换|
|铅笔素描|白纸底，物体轮廓为黑色笔画，暗处叠加灰色阴影；去底量随亮度增加，抑制亮处噪点|第 3 个模式|
|自动曝光（AE）|帧统计 + 闭环调节传感器曝光和增益，室内主体优先|自动|
|白平衡 A/B/C|A：原 ISP 白平衡；B：单位增益对照；C：整帧灰度世界|长按模式键约 1 秒循环切换|
|红、蓝目标检测|按颜色和区块密度找出主要红色、蓝色区域，画框并显示 `RED TARGET` / `BLUE TARGET`|自动|
|OSD|右上角安路 Logo；左上角 AE/AWB 状态面板|自动|
|复位|C7 复位整个系统，恢复彩色模式和白平衡 A|按 C7|

## 最终版本

|项目|内容|
|---|---|
|bitstream|`sc520cs_sketch4_sram_20261102.bit`，1,789,539 字节|
|SHA-256|`3F61830838E738E7A88A798066EF5D2A16408F5C0DDD14151F44921CE52A9894`|
|工具与器件|Tang Dynasty 6.2.168116，PH1P35MDG324，Speed -3|
|资源|LUT6 17081/21216（80.5%），Slice 18583/21216（87.6%），ERAM 61/108，DSP 17/40|
|时序|setup WNS +0.103 ns，hold WNS +0.020 ns，TNS 均为 0|

bitstream 包含厂商 IP，未随仓库发布；[release/final.json](release/final.json) 记录其校验值以及构建时全部 77 个输入文件的 SHA-256。

## 验证状态

|层级|结果|
|---|---|
|模块仿真|`tb/` 下 7 个自检测试全部通过，`python scripts/run_tests.py` 可复现|
|构建|clean synthesis、place、route 各一次；时序、CDC、复位和映射审计全部通过，剩余违例 0|
|上板（SRAM）|2026-11-02 铅笔素描模式在暗室和补光条件下经开发者确认；本镜像其余功能和 Flash 冷启动未逐项记录，验收步骤见 [上板测试](docs/BOARD_TEST.md)|

已知问题：启动后偶发整帧亮度闪烁，按 C7 或重新插拔 HDMI 线后恢复，根因未确定；逆光场景高光过曝；暗环境下弱边缘和红蓝目标较难检出。详见 [上板测试](docs/BOARD_TEST.md#已知问题)。

## 仓库内容

```
hdl/        自研 RTL（16 个文件，与最终 bitstream 所用源码逐字节一致）
tb/         自检测试平台（7 个）
scripts/    run_tests.py 运行全部仿真；make_logo_rom.py 由官方文件生成 Logo 数据
docs/       设计、构建、验证和上板文档
release/    最终版本元数据与源码校验值
```

完整工程还需要安路官方例程中的顶层、MIPI、DDR2、HDMI 等厂商派生文件和 IP。这些材料的再分发许可尚未确认，未放入仓库；修改内容和恢复方法见 [构建说明](docs/BUILD.md)。

## 文档

|文档|内容|
|---|---|
|[系统设计](docs/ARCHITECTURE.md)|数据通路、时钟与复位、各模块算法和接口|
|[构建说明](docs/BUILD.md)|依赖、工程恢复、构建流程和 Logo 数据生成|
|[验证报告](docs/VERIFICATION.md)|仿真、时序、审计结果和检查器调整|
|[上板测试](docs/BOARD_TEST.md)|操作说明、验收清单、已有记录和已知问题|
|[赛题对照](docs/CONTEST.md)|基础、扩展、进阶要求与实现情况|
|[开发记录](docs/HISTORY.md)|主要问题、排查过程和方案取舍|

## 快速开始

```bash
python scripts/run_tests.py
```

需要 Icarus Verilog（`iverilog`、`vvp`）和 Python 3。
