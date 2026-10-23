# AWB 阶段演示基线（2026-10-17）

2026-10-17 选定 `frame_awb` 作为阶段演示和回退版本，保留四模式、自动曝光及 A/B/C 白平衡。演示时手动选择 C，接受当时的室内亮度和轻微偏色限制，暂停 AE/AWB 画质调参。

`release/current.json` 保留该选择，最终验收尚未完成。后续 Logo、红色检测、稳定性修复及 2026-10-19 暗红候选独立登记，见[版本总览](../README.md)。2026-10-18 亮度核查针对已有上板反馈的 `stable`，不改变本页的版本范围。

|要点|说明|
|---|---|
|演示操作|复位默认彩色/A；长按约 1 秒依次到 C，每档至少等 20 帧，建议 3 秒|
|保留原因|已有工程、配置文件和历史观察，可用于比较与回退|
|画质结论|C 与 A 接近，可能略好；偏色未解决|
|验证缺口|现场文件指纹、完整模式实物记录、20～30 分钟和独立启动|
|与新版本的关系|bitstream 校验值及测试数据仅适用于 AWB 阶段，不适用于后续候选|

以下为该阶段的源码清单、bitstream 校验值、视频来源和验证计划；后续 Logo、检测与暗红候选状态见[验证报告](QA_REPORT.md)。


对应候选为 `qa/sc520cs_frame_awb_trial_20261016`，原候选与 A/B/C 对照均保留。

## 文件、构建来源与演示控制

工程入口、顶层与构建来源见 [current.json](../release/current.json)；70 条工程记录见 [active_sources.csv](../release/active_sources.csv)，394 项源码/IP/依赖哈希见 [dependencies.csv](../release/dependencies.csv)。2026-10-17 运行 `python scripts/verify_current.py --local`：394 项匹配、0 错误，选定 bitstream 匹配；未重新构建或重跑 RTL 仿真。

- 工程：`qa/sc520cs_frame_awb_trial_20261016/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`，顶层 `design_top_wrapper`。
- bitstream：`qa/sc520cs_frame_awb_trial_20261016/run_bitgen_frame_awb_checked/sc520cs_frame_awb.bit`，1,789,539 字节。
- SHA-256：`794946D5664CA984C8033C62786BD026BE0DF223317D808743B6A2D367E83371`。
- 既有构建：TD 6.2.168116，`syn_6 → run_route_11_gray_csa → final → run_bitgen_frame_awb_checked`。
- 复位仍默认 RGB/A；该阶段不改默认值。演示时长按约 1 秒依次 A→B→C，确认面板为 C；每次切换等待至少 20 帧，建议 3 秒。
- 短按依次彩色→灰度→二值化→Sobel 边缘检测→彩色。A 原 AWB、B 单位增益、C 完整帧四像素统计 AWB 均保留。

## 视频与实物反馈

逐文件大小和实测 SHA-256 见 [阶段证据清单](../release/stage_baseline_20261017.json)。视频与 bitstream 保留本地，不扩大公开分发范围。

|材料|路径与可支持结论|限制|
|---|---|---|
|历史四模式演示|`docs/board_tests/20261009/four_mode_demo.mp4`；5,172,750 字节；SHA-256 `FD9EA53A01ECA50D68781E79B9331A3C10AB7E3412BCF52C72654743F7BDBC9E`|早于 AWB 阶段基线，不作为该基线 bitstream 的验收|
|历史 A/B/A 翻拍|候选下 `video_review/original_awb_ab_demo.mp4`；1,686,211 字节；SHA-256 `95956691DF2019FCD2196BA71828568137191442430E5C38C3F8F43161CEBBA1`|已从 metadata 指向的原视频复制并核对 SHA-256；约 33.067 秒，不能代替 C 或连续运行测试|
|截图和索引|候选下 `video_review/metadata.json`、`contact_sheet.jpg`、`frame_00.jpg` 至 `frame_11.jpg`|保留原索引；仅定性比较，不作精确色度测量|
|C 上板反馈|[板测记录](BOARD_VALIDATION.md)：开发者反馈 C 与 A 接近、可能略好；该阶段接受现有画质限制|无独立加载 SHA-256、新 C 视频和持续时长记录；不追加未经验证的通过结论|

## 已知限制与验证计划

20～30 分钟稳定性测试为 **not tested，待板级测试负责人完成**。按 [板测记录](BOARD_VALIDATION.md)填写时长、异常和切换结果，空项不视为通过。

偏色仍存在，2026-10-17 阶段演示接受该限制，当时暂停画质优化。在 2026-10-17 阶段冻结时，“安路”Logo、全模式实物验收、Flash 无 PC 冷启动尚未完成。已建模时序 setup/hold WNS 为 +0.103/+0.020 ns、覆盖率 98.75%，不等于外部 I/O、PLL/PHY/DDR 或板级全覆盖。历史无间隙 SOF FIFO 丢字反例和异常帧恢复限制继续保留，详见 [QA 报告](QA_REPORT.md)。

2026-10-17 当时计划的下一项比赛功能为“安路”Logo OSD；扩展项另保留简单目标检测与结果叠加缺口，详见 [逐项完成表](CONTEST_CHECKLIST.md)。该阶段冻结记录不包含 RTL 修改、构建、硬件下载或 Flash 写入。

## 历史提交与备份

既有整理提交 `b07f832`、文档提交 `14800f3` 及完整备份仍在。2026-10-17 远端 main 与本地更新前 HEAD 均为 `14800f3d162800df992de859b0f59cd54e48e28d`，因此跳过重复整理。已重新通过 `git bundle verify`；完整备份完成记录仍在 `qa/_local_backups/pre_cleanup_20261016/COMPLETE.json`。未重新计算整个 43 GB 快照，因此该次复核不构成完整备份的重新逐文件验证。

原有 4 个历史仿真暂存文件保持原暂存状态，不混入本次阶段基线提交。旧候选、失败证据、未跟踪/忽略成果及备份保留；不强推、不清空 QA。恢复说明见 [CLEANUP_AND_RECOVERY.md](CLEANUP_AND_RECOVERY.md)。
