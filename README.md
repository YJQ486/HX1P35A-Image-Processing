# HX1P35A / SC520CS 图像处理

基于安路 HX1P35A 开发板的实时图像处理工程，采用 SC520CS 摄像头输入，经 FPGA 图像处理与 DDR 帧缓存后输出 HDMI 视频，分辨率为 1280 × 720。

当前集成版本包含室内自动曝光（AE）、四种显示模式和三种白平衡（AWB）方案。C 方案已上板观察，效果与 A 接近，可能略有改善，**偏色问题尚未解决**。长期稳定性、Flash 独立启动及完整板级验收仍待验证。

## 功能

|功能|说明|
|---|---|
|显示模式|彩色、灰度、二值化、Sobel 边缘检测；短按按键依次切换|
|白平衡对照|A：原 AWB；B：单位增益；C：完整帧四像素并行统计 AWB。长按约 1 秒切换|
|室内自动曝光|在 AWB 前进行主体加权测光，保留曝光与增益限幅、NACK 停止机制|
|状态显示|显示曝光、增益、白平衡分支及相关运行状态|

模式在有效帧边界切换。AE 达到当前曝光或增益上限后，画面仍可能偏暗。

## 平台与工具

|项目|配置|
|---|---|
|开发板 / FPGA|HX1P35A / PH1P35MDG324，Speed -3|
|摄像头接口|SC520CS，2 lane RAW10|
|视频链路|MIPI → ISP → DDR → HDMI|
|FPGA 开发工具|Tang Dynasty 6.2.168116|
|仿真工具|Icarus Verilog 12.0(devel)；ModelSim Intel FPGA Starter 2020.3|
|检查脚本|Python 3.11 及以上|

开发板 PCB 版本、适配板及线缆连接应结合实物、原理图和工程约束核对，手册中的部分连接器及管脚表项存在待核实之处。

## 工程入口与仓库结构

当前集成工程入口为：

```text
qa/sc520cs_frame_awb_trial_20261016/
└─ lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al
```

顶层模块为 `design_top_wrapper`。版本、构建来源及 bit 信息见 [current.json](release/current.json)。本地 `project/` 保存的是旧 SC500CS 基线。

|目录|内容|
|---|---|
|`qa/sc520cs_frame_awb_trial_20261016/rtl/custom/`|当前版本的自研 RTL|
|当前候选目录下的测试平台、`sim/custom/`|公开自检所需的 Verilog 测试平台|
|`scripts/`|依赖校验与回归测试脚本|
|`release/`|工程清单、依赖哈希、构建与验证记录|
|`docs/`|设计说明、构建方法、QA 及实物测试记录|

完整工程包含厂商例程和 IP。由于尚未取得明确的公开分发许可，这部分文件仅保留在本地；**公开仓库不能单独构建完整摄像头镜像**。依赖获取与恢复方法见[依赖说明](docs/DEPENDENCIES.md)。旧候选、原始日志和历史产物保存在本地 QA 与备份目录。

## 检查与构建

在仓库根目录执行：

```powershell
# 校验公开源码
python scripts/verify_current.py

# 运行自研模块回归，包含完整帧 AWB 测试
python scripts/test_current.py --iverilog-bin D:/iverilog/bin --full

# 恢复完整本地依赖后，校验工程文件及选定 bit
python scripts/verify_current.py --local
```

仿真工具路径可通过命令行、`IVERILOG_BIN` 或 `PATH` 指定。TD 构建流程、约束加载和手动板测步骤见[构建说明](docs/CURRENT_BUILD.md)。

## 验证状态

当前源已通过 7 组回归；公开文件的独立导出通过 6 组基础回归。现有 TD 构建的已建模路径结果为 setup WNS **+0.103 ns**、hold WNS **+0.020 ns**，时序覆盖率 **98.75%**。外部 I/O 时序、PLL、硬 PHY 和 DDR 等仍有未完成的验证项目。

选定文件为 `sc520cs_frame_awb.bit`，大小 1,789,539 字节：

```text
SHA256 794946D5664CA984C8033C62786BD026BE0DF223317D808743B6A2D367E83371
```

bit 和原始演示视频暂未公开。C 方案的上板结论来自实物观察记录，加载文件的 SHA 尚未单独核验。详细结果与限制见 [QA 报告](docs/QA_REPORT.md)和[板级测试记录](docs/BOARD_VALIDATION.md)。

## 文档

- [工程结构与接口](docs/PROJECT_ANALYSIS.md)
- [构建与测试方法](docs/CURRENT_BUILD.md)
- [依赖与公开范围](docs/DEPENDENCIES.md)
- [QA 报告](docs/QA_REPORT.md)
- [板级测试记录](docs/BOARD_VALIDATION.md)
- [归档与恢复说明](docs/CLEANUP_AND_RECOVERY.md)
