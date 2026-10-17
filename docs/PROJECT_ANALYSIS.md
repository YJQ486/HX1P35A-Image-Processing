# 工程结构与接口

## 版本依据

当前集成候选为 `qa/sc520cs_frame_awb_trial_20261016`，包含室内 AE、四种显示模式和 AWB A/B/C。版本选择依据为实际工程清单、`syn_6` 原生源清单及对应构建记录。该候选具备完整的构建证据，但尚未完成色度与长期稳定性验证。

工程入口、器件及 bit 信息见 [current.json](../release/current.json)；全部工程条目见 [active_sources.csv](../release/active_sources.csv)。

## 视频通路

```text
MIPI D-PHY → CSI / RAW10 解包 → uial2axis
    → demosaic → data128_96 → AWB A/B/C → 四模式处理
    → data_96bit_to_128bit → video_in → FIFO / DDR
    → video_out → 状态叠加 → HDMI
```

AE 从 `data128_96` 输出、AWB 之前旁路采样。以下路径均相对于候选根目录；为便于阅读，`hdl/` 表示 `lab_ex1_mipi_hdmi/user_source/hdl_source/`。

|环节|接口与时序|源码位置|
|---|---|---|
|摄像头至 ISP|2 lane RAW10；ISP 输入 `I_tdata[39:0]` 及 valid、user、last 标记，工作于 CSI 域|`hdl/design_top_wrapper.v:649–769`；`hdl/isp/isp_top.v:1–21`|
|去马赛克与 AE 测光|96 bit RGB 流，每拍 4 个 RGB888 像素；首像素为 `[95:72]`，单像素 R/G/B 对应 `[23:16]`、`[15:8]`、`[7:0]`|`hdl/isp/isp_top.v:102–139`；`rtl/custom/custom_ae_frame_stats.v`|
|白平衡与模式处理|三个 AWB 分支同沿输出；提前 SOF 经对齐处理。四模式统一采用两拍标记延迟，每行 320 个有效输入拍|`hdl/awb.v`；`hdl/isp/isp_top.v:132–187`；`rtl/custom/custom_frame_awb.v`|
|重打包与帧缓存|96 bit 转为 128 bit，每行 320 拍转换为 240 字，共 720 行；经 FIFO 从 CSI 域进入 DDR 用户域|`hdl/isp/isp_top.v:171–200`；`hdl/design_top_wrapper.v:792–828`|
|视频读出与显示|DDR 用户域至 HDMI 域；状态面板的 RGB、DE、HS、VS 延迟已有分层检查|`hdl/design_top_wrapper.v:829` 起；`rtl/custom/custom_ae_overlay.v`|

该链路未提供任意反压条件下的无损保证。历史无间隙 SOF 反例及异常帧恢复限制见 [QA 报告](QA_REPORT.md)。活动 AWB 为 `hdl/awb.v`，实际编译关系以工程清单为准。

## 控制与跨时钟域通信

按键为低有效输入，在 CAM 域完成消抖和长短按识别，通过事件握手传至 CSI 域；短按切换四模式，长按切换 A/B/C。处理器在有效帧首应用模式请求。相关接线见 `hdl/design_top_wrapper.v:762–785` 和 `rtl/custom/custom_key_mode_request.v`。

AE/AWB 状态通过相干 mailbox 传递：CSI → CAM 数据包为 226 bit，其中低 160 bit 保留室内 AE 数据；CAM → HDMI 使用既有 468 bit 数据包。快照可能合并中间状态，面板读数不等同于逐帧遥测。相关逻辑见 `hdl/isp/isp_top.v:59–63`、顶层 snapshot 接线及 `custom_diag_snapshot_cdc.v`。

## 时钟与约束

|时钟域|频率|周期|
|---|---:|---:|
|系统输入|50 MHz|20 ns|
|CSI|103.520 MHz|9.660 ns|
|DDR 用户时钟|133.333 MHz|7.5 ns|
|CAM|23.809524 MHz|42 ns|
|HDMI 像素时钟|75.002 MHz|13.333 ns|

实际构建加载 `constraints/base_clocks.sdc`、`constraints/ddr_clock_relations_audit.sdc`、`i2c_clock.sdc`、`top_clock_relations_ae.sdc` 及 FIFO 生成 Tcl；查询阶段另加载 `diag_entries.sdc`。引脚文件为工程清单中的 `user_source/constraints_source/pin.adc`。

复位、PLL 锁定和 DDR-ready 链沿用当前候选。2026-10-16 的整理未修改时钟周期、时序例外、引脚或复位逻辑。

## 清单核验与待完成工作

工程包含 70 条文件记录，其中 6 条标记为 `AutoExcluded`。核验结果为：全部路径存在，394 项输入及依赖哈希匹配；显式活动 Verilog 文件解析得到 56 个模块名，未发现重复定义。加密及生成 IP 的展开关系仍以 TD 原生清单和既有 elaboration 记录为依据。

原 8 组回归的 105 项编译源绑定通过复核，当前灰度模块与全 RGB 穷举证书所对应的源文件一致。

2026-10-17 用户接受室内亮度与轻微偏色，暂停 AE/AWB 画质优化。后续重点是加载文件 SHA 确认、全模式板测、20～30 分钟持续运行与反复切换，以及外部时序和硬 PHY 验证。下一项比赛功能为“安路”Logo OSD，见[逐项完成表](CONTEST_CHECKLIST.md)。Flash 冷启动需另行安排。旧 SC500CS 基线和官方 lab_ex_1/2/3 保留在本地 `vendor/`、`project/`，用于历史追溯。
