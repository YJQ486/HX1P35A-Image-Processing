# HX1P35A / SC520CS 图像处理

当前集成候选：**室内 AE + 四模式 + AWB A/B/C**，1280×720，目标器件 PH1P35MDG324、Speed -3。用户已观察 C 上板，与 A 接近、可能略好；**偏色仍未解决，当前候选不是最终稳定性/色度签核版本。** 用户观察未独立核验加载文件 SHA。本轮不操作下载器或 Flash。

唯一当前工程入口：`qa/sc520cs_frame_awb_trial_20261016/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`，top `design_top_wrapper`。公开索引为 [release/current.json](release/current.json)。该完整工程含许可未明的厂商文件，仅保留本地；公开仓库提供自研源、自检和精确依赖清单，**克隆后不能直接构建完整摄像头镜像**。请先阅读[依赖与获取说明](docs/DEPENDENCIES.md)。旧 `project/` SC500CS 基线不是当前入口。

功能：短按依次切换彩色、灰度、二值化和 Sobel；约 1 秒长按依次切换 A 原 AWB、B 单位增益、C 完整帧四像素统计 AWB。模式在有效帧边界提交。室内 AE 在 AWB 前进行主体加权测光，保留曝光/增益上限、NACK 停止和状态面板；不承诺暗室达到上限后仍能增亮，也不把它称为 HDR。

硬件依据为 HX1P35A / PH1P35MDG324、SC520CS、2 lane RAW10、DDR 帧缓存、HDMI。开发板精确 PCB 修订号、适配板和线缆仍须按实物及原理图核对；手册连接器和部分管脚表存在疑点，不从文字猜引脚。软件证据为 Tang Dynasty 6.2.168116、Icarus 12.0(devel)、ModelSim Intel FPGA Starter 2020.3；公开检查脚本要求 Python 3.11+。

|路径|用途|
|---|---|
|`qa/sc520cs_frame_awb_trial_20261016/rtl/custom/`|当前自研 RTL；保持候选原路径，不改工程输入|
|同候选下的 5 个 `tb_*.v`、`sim/custom/tb_custom_processing_top.v`|公开必要自检|
|`scripts/verify_current.py`、`scripts/test_current.py`|公开/本地依赖核对及当前源回归|
|`release/`|唯一候选、全部 .al 条目、源/IP/脚本哈希、bit 来源及精简证据|
|`docs/`|当前分析、构建说明、QA、许可和实物记录|
|本地 `vendor/`、`project/`、其余 `qa/`、`qa/_local_archive/`、`qa/_local_backups/`|厂商材料、旧候选、失败运行及恢复材料，默认不上 GitHub|

在仓库根目录运行：

```powershell
python scripts/verify_current.py
python scripts/test_current.py --iverilog-bin D:/iverilog/bin --full
# 完整本地依赖恢复后：
python scripts/verify_current.py --local
```

构建原链、约束加载、脚本保护边界和手动上板步骤见[当前构建说明](docs/CURRENT_BUILD.md)；数据接口见[工程分析](docs/PROJECT_ANALYSIS.md)。本次未改 RTL、IP、引脚或 TD 工程输入，未重跑历史全部构建。原链 syn_6 → run_route_11_gray_csa → final 查询 → checked bitgen 的源绑定复核通过。

选定 `sc520cs_frame_awb.bit`：**1,789,539 字节**，SHA256 `794946D5664CA984C8033C62786BD026BE0DF223317D808743B6A2D367E83371`；完整相对路径见 current.json。因厂商 IP 分发许可未明，本次 bit 和视频均只留本地，不创建 Release。工具已建模路径 setup +0.103 ns / hold +0.020 ns、覆盖 98.75%；外部 I/O delay、PLL/hard PHY/DDR 及告警仍有边界，不能等同全部时序或板级通过。

[QA 报告](docs/QA_REPORT.md)区分本轮检查、历史工具证据及[用户实物观察](docs/BOARD_VALIDATION.md)。Flash 无 PC 冷启动、长期稳定性和全部板级验收尚未通过。整理恢复说明见[本地恢复记录](docs/CLEANUP_AND_RECOVERY.md)，旧成果从当前公开版本退出，Git 历史保留。
