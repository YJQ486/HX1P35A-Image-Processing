# 阶段演示基线（2026-10-17）

用户接受当前室内亮度和轻微偏色，暂停 AE/AWB 画质优化。选定 `qa/sc520cs_frame_awb_trial_20261016` 为阶段演示基线，演示选 C，保留 A/B/C 对照及所有原候选。此决定不代表最终稳定性验收。

## 源码、bit 与演示方法

工程入口、顶层与构建来源见 [current.json](../release/current.json)；70 条工程记录见 [active_sources.csv](../release/active_sources.csv)，394 项源码/IP/依赖哈希见 [dependencies.csv](../release/dependencies.csv)。2026-10-17 运行 `python scripts/verify_current.py --local`：394 项匹配、0 错误，选定 bit 匹配；未重新构建或重跑 RTL 仿真。

- 工程：`qa/sc520cs_frame_awb_trial_20261016/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`，顶层 `design_top_wrapper`。
- bit：`qa/sc520cs_frame_awb_trial_20261016/run_bitgen_frame_awb_checked/sc520cs_frame_awb.bit`，1,789,539 字节。
- SHA256：`794946D5664CA984C8033C62786BD026BE0DF223317D808743B6A2D367E83371`。
- 既有构建：TD 6.2.168116，`syn_6 → run_route_11_gray_csa → final → run_bitgen_frame_awb_checked`。
- 复位仍默认 RGB/A；本轮不改默认值。演示时长按约 1 秒依次 A→B→C，确认面板为 C；每次切换等待至少 20 帧，建议 3 秒。
- 短按依次彩色→灰度→二值化→Sobel→彩色。A 原 AWB、B 单位增益、C 完整帧四像素统计 AWB 均保留。

## 已有实物材料

逐文件大小和实测 SHA 见 [阶段证据清单](../release/stage_baseline_20261017.json)。视频与 bit 保留本地，不扩大公开分发范围。

|材料|路径与可支持结论|限制|
|---|---|---|
|历史四模式演示|`docs/board_tests/20261009/four_mode_demo.mp4`；5,172,750 字节；SHA `FD9EA53A01ECA50D68781E79B9331A3C10AB7E3412BCF52C72654743F7BDBC9E`|早于当前基线，不作为当前 bit 的验收|
|历史 A/B/A 翻拍|候选下 `video_review/original_awb_ab_demo.mp4`；1,686,211 字节；SHA `95956691DF2019FCD2196BA71828568137191442430E5C38C3F8F43161CEBBA1`|已从 metadata 指向的原视频复制并核对 SHA；约 33.067 秒，不能代替 C 或长稳测试|
|截图和索引|候选下 `video_review/metadata.json`、`contact_sheet.jpg`、`frame_00.jpg` 至 `frame_11.jpg`|保留原索引；仅定性比较，不作精确色度测量|
|C 上板反馈|[板测记录](BOARD_VALIDATION.md)：用户反馈 C 与 A 接近、可能略好；本轮用户接受现状|无独立加载 SHA、新 C 视频和持续时长记录；不补写通过|

## 已知限制与待办

20～30 分钟稳定性测试为 **not tested，待用户完成**。按 [板测记录](BOARD_VALIDATION.md)填写时长、异常和切换结果，空项不视为通过。

偏色仍存在，但已按用户决定接受为演示限制，不再将画质优化作为当前主线。当前未完成“安路”Logo、全模式实物验收、Flash 无 PC 冷启动。已建模时序 setup/hold WNS 为 +0.103/+0.020 ns、覆盖率 98.75%，不等于外部 I/O、PLL/PHY/DDR 或板级全覆盖。历史无间隙 SOF FIFO 丢字反例和异常帧恢复限制继续保留，详见 [QA 报告](QA_REPORT.md)。

下一项比赛功能为“安路”Logo OSD；扩展项另保留简单目标检测与结果叠加缺口，详见 [逐项完成表](CONTEST_CHECKLIST.md)。本轮不实施 RTL，不构建、不下载、不写 Flash。

## Git 与保留范围

既有整理提交 `b07f832`、文档提交 `14800f3` 及完整备份仍在。2026-10-17 远端 main 与本地更新前 HEAD 均为 `14800f3d162800df992de859b0f59cd54e48e28d`，因此跳过重复整理。已重新通过 `git bundle verify`；完整备份完成记录仍在 `qa/_local_backups/pre_cleanup_20261016/COMPLETE.json`。未重新计算整个 43 GB 快照，本轮不将其描述为重新逐文件验证。

原有 4 个历史仿真暂存文件保持原暂存状态，不混入本次阶段基线提交。旧候选、失败证据、未跟踪/忽略成果及备份保留；不强推、不清空 QA。恢复说明见 [CLEANUP_AND_RECOVERY.md](CLEANUP_AND_RECOVERY.md)。
