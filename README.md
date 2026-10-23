# HX1P35A / SC520CS 实时图像处理工程

本工程在 HX1P35A FPGA 上完成 SC520CS 摄像头采集、实时图像处理、DDR 帧缓存和 HDMI 显示，输出有效分辨率为 **1280 × 720**。支持彩色、灰度、二值化和 Sobel 边缘检测，并在独立后继版本中加入“安路”Logo、红色区域框选和文字标注。

仓库提供自研 Verilog、模块测试、检查脚本和工程说明。完整摄像头 bitstream 的构建还需要未公开的厂商例程、IP 及对应本地修订；bitstream 和原始视频也保留在本地。可直接校验仓库源码并运行相应模块测试，完整工程的恢复条件见[依赖说明](docs/DEPENDENCIES.md)。

本文的功能与测试状态依据截至 2026-10-19 的记录。`release/current.json` 保留 AWB 阶段演示基线，后续候选各有独立报告。

## 功能与操作

|功能|使用方式|已有结果|
|---|---|---|
|摄像头采集与显示|SC520CS → FPGA → HDMI|有历史视频和上板反馈，最终加载文件仍需与现场记录对应|
|四种显示模式|短按模式键，依次切换彩色 → 灰度 → 二值化 → Sobel 边缘检测 → 彩色|已有源码、仿真和历史演示，拟验收候选的逐项板测待补|
|自动曝光（AE）|根据画面明暗调整曝光和增益|已集成，室内偏暗原因尚未确定|
|白平衡（AWB）对照|长按约 1 秒，依次切换 A → B → C → A|C 已有上板观察，与 A 接近、可能略好；偏色仍在|
|Logo 与运行信息|右上显示“安路”图形，左上显示状态面板|Logo 候选已有上板成功反馈，完整验收待补|
|红色区域检测|黄色包围框和 `RED TARGET` 标签|原算法曾出现贴边异常扩展；修复版有工具结果和上板反馈，实际改善与长期表现待补记录|

A 使用原白平衡算法，B 使用单位增益作对照，C 根据完整帧统计调整红、蓝通道。切换后至少等待 20 帧，建议约 3 秒再比较。复位恢复彩色/A；阶段演示使用 C 时需手动重新选择。曝光与白平衡均有限幅，现有方案仍有亮度和偏色限制。

红色检测依据颜色、块密度和连续帧确认规则选择区域，红色背景也可能被选中，不具备物体类别识别能力。

## 系统通路

![从摄像头采集到 HDMI 显示，以及自动曝光反馈](docs/diagrams/video_overview.png)

<details>
<summary>流程图的可编辑源码</summary>

图形来源：[生成脚本](scripts/render_doc_diagrams.py)中的 `video_overview` 定义；使用 Pillow 和固定中文字体生成。

</details>

自动曝光在白平衡之前统计明暗；红色检测在白平衡之后、四模式处理之前读取彩色像素，因此切换灰度等模式不会改变检测输入。检测框、文字和 Logo 在 DDR 读出后叠加，属于后续候选的功能。模块接口和时钟关系见[系统设计](docs/PROJECT_ANALYSIS.md)。

|平台项目|配置|
|---|---|
|开发板 / FPGA|HX1P35A / PH1P35MDG324，Speed -3|
|摄像头|SC520CS，2 lane RAW10|
|显示|1280 × 720，HDMI|
|开发工具|Tang Dynasty 6.2.168116|
|工程顶层|`design_top_wrapper`|

## 版本与验证状态

各候选独立保存，便于比较和回退。`stable` 是稳定性修复候选的名称，完整稳定性验收仍未完成。

|版本|主要变化|记录入口|
|---|---|---|
|`frame_awb`|保留的阶段演示基线：四模式、AE、A/B/C；`release/current.json` 指向此版本|[阶段基线](docs/STAGE_BASELINE.md)|
|`logo_osd`|在阶段基线上加入官方 Logo|[Logo 报告](docs/SC520CS_LOGO_OSD_REPORT.md)|
|`red_target`|加入红色区域框选；视频确认贴边时包围框异常扩展|[原检测报告](docs/SC520CS_RED_TARGET_REPORT.md)|
|`red_stability`|用密度区域筛选抑制相离红区造成的联合框扩展|[修复报告](docs/SC520CS_RED_STABILITY_REPORT.md)|
|`dark_red`|2026-10-19 暗红召回试验，仅降低最低 R 门槛；板级待测|[暗红报告](docs/SC520CS_DARK_RED_REPORT.md)|

2026-10-18 的[亮度核查](docs/SC520CS_BRIGHTNESS_BASELINE_AUDIT.md)登记了 `stable` 上板反馈，现场加载 SHA-256 尚未独立核验。暗红候选 `qa/sc520cs_dark_red_trial_20261019` 的仿真和构建结果来自本地 `RELEASE_DARK_RED.md`、`dark_release_summary.json` 与 bitstream 清单，板级效果为 `not tested`，发布基线未调整。

尚待完成的项目包括修复版边界检测、模式与按键逐项板测、20～30 分钟连续运行，以及 Flash 固化后脱离电脑的断电冷启动。检测坐标未绑定 DDR 帧槽，移动目标可能出现框滞后；历史无间隙 SOF 条件下的 FIFO 丢字反例仍保留。测试数据和模型限制见[验证报告](docs/QA_REPORT.md)，比赛要求见[完成表](docs/CONTEST_CHECKLIST.md)。

## 文件校验与模块测试

在仓库根目录执行，需 Python 3.11 或以上；仿真工具路径按本机安装位置调整。

```powershell
# 检查公开源码是否与阶段清单一致
python scripts/verify_current.py

# 运行阶段基线的模块测试；按本机安装位置调整工具路径
python scripts/test_current.py --iverilog-bin D:/iverilog/bin --full

# 仅在已有完整本地依赖时，检查依赖及选定 bit
python scripts/verify_current.py --local
```

这些脚本对应 AWB 阶段基线，不覆盖后续候选的完整验收。完整工程入口为 `qa/sc520cs_frame_awb_trial_20261016/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`；构建步骤、历史脚本绑定及复现条件见[构建与测试](docs/CURRENT_BUILD.md)。板卡版本、引脚和线缆方向仍须结合实物与原理图核对，资料中的不一致项保持待确认。

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

标注“本地证据”的候选目录和日志路径用于原工作机追溯，仓库未提供其完整内容。

## 文档入口

|阅读目标|文档|
|---|---|
|选择阅读顺序、查术语|[阅读指南](docs/READING_GUIDE.md)、[术语与指标](docs/GLOSSARY.md)|
|了解实现与接口|[系统设计](docs/PROJECT_ANALYSIS.md)|
|核对验证结果和比赛缺口|[验证报告](docs/QA_REPORT.md)、[比赛完成表](docs/CONTEST_CHECKLIST.md)|
|运行检查、恢复依赖|[构建与测试](docs/CURRENT_BUILD.md)、[依赖说明](docs/DEPENDENCIES.md)|
|执行并记录实物测试|[板级测试记录](docs/BOARD_VALIDATION.md)|
|追溯旧文件与暂存状态|[归档与恢复](docs/CLEANUP_AND_RECOVERY.md)|

<details>
<summary>AWB 阶段基线文件指纹</summary>

`sc520cs_frame_awb.bit` 为 1,789,539 字节，未公开。该指纹仅对应 AWB 阶段基线，来源见[阶段基线](docs/STAGE_BASELINE.md)。

```text
SHA256 794946D5664CA984C8033C62786BD026BE0DF223317D808743B6A2D367E83371
```

</details>
