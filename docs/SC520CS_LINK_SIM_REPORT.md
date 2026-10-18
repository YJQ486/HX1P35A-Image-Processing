# 早期链路仿真：打包正确，帧首标记曾经错位

这是一份 **2026-09-23 的历史缺陷报告**，检查当时处理模块接入官方例程前的数据接口。它不是最新 `stable` 的整体状态报告，也没有执行实物测试。

## 当时查到了什么

|问题|通俗解释|历史结论|
|---|---|---|
|96→128 位打包|把每组 12 字节重新拼成每组 16 字节|在所测输入中顺序和数量正确|
|帧首标记提前|“新画面开始”的通知到了，首批有效像素还没到|处理模块错过模式切换，负例明确失败|
|转换器复位|接口声明了复位，但实际寄存器没有使用它|不能假定拉低复位就立即清空所有旧状态|

```mermaid
flowchart LR
    A[帧首通知先到] --> B[此时数据无效]
    B --> C[首批像素随后到达]
    C --> D[通知与像素未同时有效]
    D --> E[模式请求没有被正确采样]
```

当时建议把早到的通知保存下来，在首批有效像素到达时再交给处理模块。后续 AWB 基线已包含专用帧首对齐逻辑，见[系统设计](PROJECT_ANALYSIS.md)；这不意味着历史无间隙帧首下的 FIFO 丢数据问题也一起解决。

本报告的正常自检退出码为 0，故意重现提前帧首问题的用例退出码为 1；脚本整体失败是为了保留缺陷门槛，不能把所有退出码 1 都当作工具故障。逐拍时序、文件指纹和限制在下方保留。旧文引用但未公开的其他报告属于本地历史材料。


<details>
<summary>2026-09-23 独立仿真的逐拍证据（点击展开）</summary>

日期：2026-09-23。范围仅为文件复制、独立 Icarus 仿真及文档；未修改任一官方 RTL、寄存器、PLL/DDR/IP/ADC/SDC，未改工作副本 `isp_top.v`，未综合、place/route、bitgen、Download 或上板。`project/` 与 `vendor/` 均被 `.gitignore` 排除；**本报告不批准 bitstream 下载**。

## 1. 新工作副本及溯源

| 项目 | 路径 / 结果 |
|---|---|
| 官方只读原件 | `vendor/official_sc520/SC520CS摄像头资料/lab_ex1_mipi_hdmi_SC520 (2)/lab_ex1_mipi_hdmi_SC520/lab_ex1_mipi_hdmi/` |
| 新工作副本 | `project/lab_ex1_mipi_hdmi_SC520CS_official_workcopy/lab_ex1_mipi_hdmi/` |
| 原 SC500 工作工程 | `project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/`，保留未动 |

复制了 `user_source/` 中非历史日志的源码/生成 IP 配置、`td_project/al_ip/`、`td_project/chip_debugger/` 以及 `.al`、`.sdc`，没有复制 `_Runs`、历史日志、布局布线报告、bitstream。新副本 216 个文件、4,841,810 字节；逐文件与官方同相对路径文件计算 SHA-256，**216/216 相同、0 不匹配**。`.al` 的 57 个文件引用（含自动排除项）在副本中全部存在；原件 468 个文件包含历史产物，本次没有把它们当作新构建证据。`.al:2` 仍保留官方旧电脑绝对 `Project Path`，本轮未改，后续打开 TD 前须受控处理。未运行 TD。

| 文件（在两工程根目录下的相对路径） | 原件 = 副本 SHA-256 |
|---|---|
| `td_project/camera_to_dsi_display.al` | `0f52f5de0f0fc4b98a73b0c82579444fe142b5ba0b601078bda1341f8e6c2940` |
| `td_project/camera_to_dsi_display.sdc` | `54eb1455e1c938b2cca47641c789ae0f475e43bc318421c165ddc4d6f280d6d4` |
| `user_source/constraints_source/pin.adc` | `99c31a6c3d949e35848184c7cef3c11487e98fa5e803123e84541fbe96d98dbe` |
| `user_source/hdl_source/design_top_wrapper.v` | `ae7c4782b5fc7817923dbae2c0688617fd55c71cae8305421f91289cbc060ebc` |
| `user_source/hdl_source/isp/isp_top.v` | `c65dc71dcbe05ffdb0ffd2cfe161ee1d96dc14c35b62cb8aafb71861173dba36` |
| `user_source/hdl_source/isp/data96_128/data96_128.v`（**本次实际编译文件**） | `c79a102378c70ce5faacbc46a62b5ae6eaac151b93891379eda2880a7d68fe30` |
| `user_source/hdl_source/uics520_cfg/uics520reg_720p60.v` | `8c871586e9d2bf46f245f161f925ab1d811ae647d3089c1eaf8fa9ce5c8f48c7` |

## 2. 实际连接与独立参考模型

`td_project/camera_to_dsi_display.al:54,158` 列入的**活动** AWB 和转换器分别是 `user_source/hdl_source/awb.v`、`user_source/hdl_source/isp/data96_128/data96_128.v`。同目录中另有 `isp/awb/awb.v` 和顶层 `data_96bit_to_128bit.v`，但二者**未列入活动 `.al`**，本次没有以它们代替真实转换器。`isp/isp_top.v:77–105` 将活动 AWB 的 96-bit data、valid、frame_start 直接接到转换器；AWB 的 `tlast` 不进入转换器，`isp_top.v:38` 原样旁路到外部。

仿真将 `custom_processing_top` 接在相同 96-bit 插点和**真实活动**转换器之前；另将相同原始 96-bit 输入直接接第二个转换器作为基线，不修改转换器。自检用独立 byte FIFO 参考模型：每个有效 96-bit 拍按高字节到低字节压入 12 字节，每凑成 16 字节比较一个 128-bit 输出；并对四模式另算灰度/阈值结果，Sobel 用均匀黑场。参考模型没有复制转换器的 `case(S_cnt)` 拼接式。源文件与自检见 `sim/custom/tb_sc520cs_processing_link.v:1–342`，复现脚本和全量文本证据见 `sim/custom/run_sc520cs_link_iverilog.ps1`、`sim/custom/sc520cs_link_iverilog_evidence.txt`。

| 接口事实 | 实际源码 | 仿真所检契约 |
|---|---|---|
| 四模式处理 | `rtl/custom/custom_processing_top.v:31–110` | 96-bit 四 RGB888、帧首仅 `valid&&user` 锁存模式和阈值；所有路径两级寄存，输入于边沿 N、处理输出于 N+1；无效 data=0；无效 `tlast` 仍透传。 |
| 96→128 | 副本 `user_source/hdl_source/isp/data96_128/data96_128.v:3–75` | 320 个连续有效输入拍 = 3840 字节 = 240 个有效 128-bit 输出字；四拍 96-bit 对应三拍 128-bit，顺序不反转。输出 `valid` 只在输入有效且计数为 1、2、3 的边沿置位。 |
| frame_start | 同一转换器 `:16,28–31` | `O_128b_frame_start` 只对 `I_96b_frame_start` 寄存一拍，不等待首个 128-bit 有效字；相对于输出 valid 提前，第一拍输出 SOF 时 data/valid 仍无效。这是源码/仿真行为，不应称为“对齐的 128-bit SOF”。 |
| 新增延迟 | `custom_processing_top.v:75–110`；转换器 `:28–65` | 直通基线的每个 converter 事件与经处理器直通模式的同一事件相差 **2 个采样边沿**；各自 96→128 打包规则相同。若原始首个 96-bit 拍在 N，基线首个 128-bit 有效字在 N+1，经处理器后在 N+3。 |
| reset | 转换器 `:5,22–65` | `I_rst_n` 声明但不被任何时序块使用；中途异步拉低不会立即清其输出寄存器。处理器有异步低有效复位；测试观察到直接转换器上一次 `valid=1` 在复位拉低后、下个时钟前仍为 1。恢复时必须保证足够无效拍使转换器内部计数回 0，不能假定其复位输入会清状态。 |

## 3. 实测仿真结果与失败用例

执行 `& .\sim\custom\run_sc520cs_link_iverilog.ps1`；Icarus Verilog **12.0 (devel)**。脚本完整记录版本、所有绝对源文件、`iverilog -g2005 -Wall -s tb_sc520cs_processing_link` 编译命令和 `vvp` 两次运行命令。实际编译退出码 **0**；编译提示只有若干原有模块缺少 `timescale`。测试平台有 timeout、逐拍比较、错误计数及 `$fatal(1)` 失败退出。

| 项目 | 实测 / 判定 |
|---|---|
| 连续 320 有效拍、128-bit 字节顺序/拍数 | **PASS**；首行直接转换得到 240 字。独立字节 FIFO 共比较 23,040 个输出字节；首个 128-bit 字另用硬编码 `{96'h000000ffffff_ff0000_00ff00,32'h7f7f7f80}` 检查。 |
| 旁路相对直接基线的新增延迟 | **PASS**；逐拍比较 direct 输出的两边沿历史与 linked 输出。 |
| 四模式、帧中请求变化及阈值变化 | **PASS（有效 SOF 输入前提下）**；旁路/灰度/二值化使用独立像素公式；Sobel 使用均匀黑场。帧内第 160 拍更改 mode 和 threshold，当前帧保持锁存值。此链路测试不替代 `docs/CUSTOM_PROCESSING_TOP_REPORT.md` 中 Sobel 多图案自检。 |
| 相邻行、无效行尾、连续帧 | **PASS（有效 SOF 输入前提下）**；6 行，每行 320 拍，相邻行只隔一个 `valid=0,last=1`；帧间无额外空闲拍。处理输出的 invalid EOL 共检查 6 次；转换器本身没有 `tlast` 端口。 |
| 启动及流中复位 | **部分 PASS / 缺陷已确认**；处理器输出在复位后清空，两个转换器经过无效拍重新同步；直接转换器 `valid` 在异步拉低后的下个边沿之前仍保持旧值，`reset_stale=1`。此处不把恢复情形泛化为“任意复位时刻均安全”。 |
| 正常自检汇总 | `vvp` 退出码 **0**，`cycles=1941 frames=6 lines=6 direct_words=1441 linked_words=1440 marker_checks=3882 invalid_last=6 hardcoded=1 errors=0`。1441 中多出的直接输出字来自故意打断的复位前两拍测试，不是某行 320 拍的计数。 |
| 活动 AWB 提前 SOF | **FAIL，最小用例已保存**：另以 `+AWB_EARLY` 运行，给一个 `valid=0,user=1` 帧首、一个无效拍、然后首个有效红像素且 `user=0`。处理顶层因只在 `valid&&user` 采样，仍按复位默认旁路输出 `ff0000`，而请求的灰度为 `4d4d4d`。该次 `vvp` **退出码 1**，明确 `$fatal`；脚本最终退出码 **1** 表示集成就绪性 FAIL。这里的两拍间隔是可复现的**最小抽象反例**，不是声称量得实际 AWB 的精确延迟。 |

活动 AWB 错位另有直接源码证据：上游 `user_source/hdl_source/isp/uial2axis.v:61–65` 仅在第一个有效像素拍产生 `axis_tuser`；`isp/isp_top.v:80–101` 将其送活动根 AWB；活动根 `user_source/hdl_source/awb.v:230–237,357–376` 将 `O_tuser=I_tuser` 直接透传，而 `O_tvalid=valid_d2` 是从 `valid_d0→valid_d1→valid_d2` 延迟所得。`isp/awb/awb.v:475` 的 `O_tuser=I_tuser_r2` **不是当前活动版本**，不能拿它解释当前工程。精确的帧首提前周期数还需完整 AWB 及其 IP 模型仿真或波形测量；目前已足以证明不能把原 AWB `O_tuser` 当作与首个 AWB 输出有效像素同拍的标记。

## 4. 结论和建议修复位置

**暂不具备直接进入 ISP 最小集成的条件。** 数据打包、字节顺序、四模式的对齐输入场景和新增两边沿延迟已独立通过，但活动 AWB 的提前帧首会使 `custom_processing_top` 在真实插点漏采模式/阈值；真实转换器还没有复位实现，输出 frame_start 领先首个 128-bit 有效字。不能为了让仿真变绿而改期望值或静默改官方转换器。

建议在后续**获准的独立工作副本集成阶段**，于 AWB→处理器的接口边界设计专用 SOF 重对齐（将早到帧事件保存到首个有效 AWB 输出拍），同时保留原有供 `video_in` 提前复位所需的事件语义；再单独验证 `tlast` 两拍延迟与 128-bit 输出时序、启动/流中复位、连续完整帧。不要直接修改官方转换器或本轮原件。修复前保留本报告的正/负两组 Icarus 用例作为回归门槛。MCLK 的 27/24/23.809524MHz 冲突、FPC 插向、全链路 lane 与 1.8/3.3V 电平仍按 `docs/SC520CS_MIGRATION_ASSESSMENT.md` 标为**待确认**，本轮没有新增板级证明。

</details>
