# HX1P35A / SC520CS 实时图像处理工程

工程面向 HX1P35A 平台的 FPGA 图像处理比赛，实现 SC520CS 摄像头采集、实时图像处理、DDR 帧缓存和 HDMI 显示。主要功能包括彩色、灰度、二值化和 Sobel 边缘检测，以及自动曝光（AE）、自动白平衡（AWB）对照、屏幕信息叠加（OSD）和红色区域检测。

输出有效分辨率为 **1280 × 720**。设计重点为像素处理、行帧标记对齐、跨时钟域传递（CDC）和连续视频输出。本文按截至 2026-10-19 的本地记录说明版本与验证状态；历史数据不视为本次重新测试结果。

## 硬件与工具平台

|项目|配置与来源|
|---|---|
|开发板 / FPGA|HX1P35A / PH1P35MDG324，Speed -3|
|摄像头输入|SC520CS，2 lane RAW10|
|有效输出|1280 × 720，HDMI|
|开发工具|Tang Dynasty 6.2.168116|
|版本依据|`release/current.json` 记录 AWB 阶段基线；后续候选另有独立报告|

## 功能概述

|功能|实现与控制方式|验证依据及范围|
|---|---|---|
|摄像头显示|采集摄像头视频并通过 HDMI 输出|已有视频和开发者上板反馈；最终文件与现场加载记录仍需对应|
|四种显示模式|彩色、灰度、二值化、Sobel 边缘检测，短按按键切换|已有源码、仿真及历史演示；拟验收候选的完整板测记录待补|
|自动曝光（AE）|根据画面明暗调整摄像头曝光和增益|已集成，但室内仍可能偏暗|
|三种白平衡（AWB）|用 A/B/C 三种方案比较画面偏色情况|C 已有上板观察，与 A 接近，可能略好；偏色未解决|
|Logo 和运行信息|右上角显示“安路”图形，左上角显示调试信息|Logo 候选已有上板成功反馈，逐项验收待补|
|红色区域框选|叠加黄色包围框和 `RED TARGET` 标签|原版本有贴边包围框异常扩展问题；修复版已完成工具检查并收到上板反馈，实际效果与长时间稳定性待补记录|

红色区域检测依据像素颜色、块密度和跨帧确认规则工作，不具备物体类别识别能力；红色背景可能被选中。

## 系统架构

![从摄像头采集到 HDMI 显示，以及自动曝光反馈](docs/diagrams/video_overview.png)

<details>
<summary>流程图的可编辑源码</summary>

图形来源：[生成脚本](scripts/render_doc_diagrams.py)中的 `video_overview` 定义；使用 Pillow 和固定中文字体生成。

</details>

框线、文字和 Logo 属于后续检测版本。自动曝光从白平衡之前的画面统计明暗；红色检测从白平衡之后、四种显示效果之前的彩色画面取样。灰度模式不改变检测模块的彩色输入来源。接线细节见[系统设计](docs/PROJECT_ANALYSIS.md)。

## 操作与控制

|操作|结果|
|---|---|
|短按模式键|彩色 → 灰度 → 二值化 → Sobel 边缘检测 → 彩色|
|长按约 1 秒|白平衡 A → B → C → A|
|复位|恢复彩色和 A；阶段演示使用 C 时，需要重新长按选到 C|

A 是原有白平衡算法；B 采用单位增益，作为算法对照；C 根据完整画面的统计调整红、蓝通道。每次切换后至少等待 20 帧，建议等待约 3 秒后比较。曝光与白平衡均受限幅约束，不能保证所有照明条件下达到目标亮度或消除偏色。

## 版本关系

各候选独立保存，用于功能比较和版本回退。**`release/current.json` 对应 AWB 阶段基线；`stable` 为稳定性修复候选名称，不代表最终稳定性验收通过。**

|版本|主要用途|应该看哪份记录|
|---|---|---|
|`frame_awb`|保留的阶段演示基线：四模式、自动曝光、A/B/C 白平衡|[阶段基线](docs/STAGE_BASELINE.md)；`release/current.json` 仍指向它|
|`logo_osd`|在基线上加入官方 Logo|[Logo 报告](docs/SC520CS_LOGO_OSD_REPORT.md)|
|`red_target`|加入红色框选；实际视频发现靠边时框突然变大|[原检测报告](docs/SC520CS_RED_TARGET_REPORT.md)|
|`red_stability`|采用密度区域筛选，抑制相离红色像素引起的包围框异常扩展|[修复报告](docs/SC520CS_RED_STABILITY_REPORT.md)|
|`dark_red`|2026-10-19 暗红召回试验候选，仅降低最低 R 门槛；板级待测|[暗红检测报告](docs/SC520CS_DARK_RED_REPORT.md)|

2026-10-18 的[亮度核查](docs/SC520CS_BRIGHTNESS_BASELINE_AUDIT.md)记录了 `stable` 上板反馈，现场加载文件的 SHA-256 尚未独立核验。2026-10-19 本地新增暗红后继候选 `qa/sc520cs_dark_red_trial_20261019`，已完成记录所述仿真和工具构建，板级效果为 `not tested`，详见[暗红检测报告](docs/SC520CS_DARK_RED_REPORT.md)。2026-10-19 版本说明依据本地 `RELEASE_DARK_RED.md`、`dark_release_summary.json` 和 bitstream 清单补充，发布基线未调整。

## 已知限制与后续验证

偏暗根因未确定，偏色仍保留为已知限制。检测坐标未绑定 DDR 帧槽，移动目标可能存在显示延迟；历史无间隙 SOF 条件下的 FIFO 丢字反例及仿真模型边界继续保留。

后续验证包括修复版边界检测、各模式与按键、20～30 分钟连续运行，以及 Flash 固化后脱离电脑的断电冷启动。这些项目没有记为通过。各阶段测试数据见[验证报告](docs/QA_REPORT.md)，比赛要求见[完成表](docs/CONTEST_CHECKLIST.md)。

## 文档索引

|复核内容|文档入口|
|---|---|
|文档分工与阅读顺序|[阅读指南](docs/READING_GUIDE.md)|
|术语定义与指标解释|[术语与指标说明](docs/GLOSSARY.md)|
|模块职责、数据通路与接口|[系统设计](docs/PROJECT_ANALYSIS.md)|
|验证证据及已知限制|[验证报告](docs/QA_REPORT.md)|
|文件校验、构建与依赖恢复|[构建与测试](docs/CURRENT_BUILD.md)、[依赖说明](docs/DEPENDENCIES.md)|
|板级验证方法与记录|[板级测试记录](docs/BOARD_VALIDATION.md)|
|历史归档与恢复|[归档与恢复](docs/CLEANUP_AND_RECOVERY.md)|

## 工程入口与构建条件

公开仓库提供自研 Verilog 模块、测试程序、检查脚本和文档。完整摄像头工程还依赖厂商例程与 IP；这些材料尚未确认公开分发许可，保留在本地。**公开仓库支持源码校验和相应模块测试，不包含独立构建完整摄像头 bitstream 所需的全部依赖。** bitstream 文件和原始演示视频也未公开。

```text
HX1P35A_Image/
├── README.md                         # 项目入口
├── docs/                             # 设计、报告、使用与测试说明
├── qa/sc520cs_frame_awb_trial_20261016/
│   └── rtl/custom/                   # 公开的阶段基线自研模块
├── sim/custom/                       # 公开模块测试
├── scripts/                          # 文件校验与测试脚本
└── release/                          # 版本、文件指纹与历史验证清单
```

后续候选的完整目录和详细日志保留在本地，文档以“本地证据”标识；这些路径不属于公开仓库的完整复现材料。

在仓库根目录执行，需 Python 3.11 或以上：

```powershell
# 检查公开源码是否与阶段清单一致
python scripts/verify_current.py

# 运行阶段基线的模块测试；按本机安装位置调整工具路径
python scripts/test_current.py --iverilog-bin D:/iverilog/bin --full

# 仅在已有完整本地依赖时，检查依赖及选定 bit
python scripts/verify_current.py --local
```

上述脚本对应 `release/current.json` 中的 AWB 阶段基线，不覆盖后续 `stable` 或暗红候选的完整验收。构建流程、工具版本和适用范围见[构建与测试](docs/CURRENT_BUILD.md)。

硬件平台为 HX1P35A / PH1P35MDG324，摄像头为 SC520CS，开发工具为 Tang Dynasty 6.2.168116。工程入口为 `qa/sc520cs_frame_awb_trial_20261016/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`，顶层模块为 `design_top_wrapper`。线缆方向、板卡版本和引脚应结合实物及原理图核对，现有资料中的不一致之处仍保留为待确认项。

<details>
<summary>保留的 AWB 阶段基线文件指纹</summary>

`sc520cs_frame_awb.bit` 为 1,789,539 字节，未公开。它与后续检测版本不同，详细来源见[阶段基线](docs/STAGE_BASELINE.md)。

```text
SHA256 794946D5664CA984C8033C62786BD026BE0DF223317D808743B6A2D367E83371
```

</details>
