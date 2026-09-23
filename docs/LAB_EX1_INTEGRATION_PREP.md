# lab_ex1 自研图像处理集成准备

## 0. 范围、结论与证据口径

本文只定义后续集成方案并复核现有基线，不修改 `project/`、`vendor/`、RTL、厂商 IP、相机寄存器、ADC、SDC 或工程配置，也没有执行综合、place、route、bitgen、Download 或上板。

当前结论如下：

1. **已经具备编写并独立验证 `custom_processing_top` 的接口条件。** AWB 后的真实数据平面、四像素打包顺序、时钟、低有效复位、帧首和行尾语义均可由源码确认；Sobel 已有真实 PH1P `opt_gate` 与 Icarus 证据。
2. **还不具备把集成结果视为可安全下载 bitstream 的条件。** DDR 参考时钟配置错误、DDR PLL0 VCO 越界、FIFO CDC 约束被覆盖、未约束对象和相机 24 MHz 关键路由告警仍未关闭。
3. `data_96bit_to_128bit` **没有 line-end 输入**，而且其 `I_rst_n` 当前未参与内部时序过程。未来集成不能假定 `custom_processing_top.o_tlast` 会被位宽转换器自动对齐，必须在包含真实位宽转换器的集成仿真中单独解决并验证。

以下使用这些路径简称：

- `P`：`project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi`
- `V1`：`vendor/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi`
- `V2`：`vendor/lab_ex2_edge_SC500_720P/lab_ex2_edge`
- `SYN`：`P/td_project/camera_to_dsi_display_Runs/syn_1`
- `PHY`：`P/td_project/camera_to_dsi_display_Runs/phy_1`

历史 bitstream 和一次完成的 bitgen 只证明工具流程曾完成，不作为安全上板证据。基线构建边界见 `docs/BASELINE_BUILD_REPORT.md:153-167` 和 `docs/BASELINE_BOARD_READINESS.md:150-160`。

## 1. 最终数据通路与插入位置

### 1.1 推荐路径

后续唯一推荐的处理插点是：

```text
MIPI RX -> RAW10 unpack -> demosaic -> 128-to-96 -> AWB
    -> custom_processing_top
    -> data_96bit_to_128bit -> video_in async FIFO -> DDR
    -> video_out async FIFO -> HDMI
```

实例应放在 `isp_top` 内部的 AWB 与 `data_96bit_to_128bit` 之间，而不是放在 `design_top_wrapper` 的 128-bit ISP 输出之后。依据：

- lab_ex1 的 AWB 输出为 `awb_O_tdata/tvalid/tuser/tlast`：`P/user_source/hdl_source/isp/isp_top.v:26-34,77-93`。
- lab_ex1 当前把 AWB 的 data/valid/frame_start 直接接入位宽转换器：同文件 `:95-106`。
- lab_ex2 在完全相同位置插入 `edge_detect_96`：`V2/user_source/hdl_source/isp/isp_top.v:84-132`。
- `isp_top` 的时钟由顶层 `S_csi_rx_clk` 驱动，复位为 `S_rst_n`：`P/user_source/hdl_source/design_top_wrapper.v:654-668`。
- `S_csi_rx_clk` 来自 MIPI D-PHY 的 `O_hs_rx_clk`：同文件 `:531-550`；SDC 将该硬核派生时钟命名为 `MIPI_RX_BYTE_CLK`：`P/td_project/camera_to_dsi_display.sdc:4-11`。

### 1.2 真实时钟、复位、吞吐和分辨率

| 项目 | 已确认内容 | 依据 |
|---|---|---|
| 时钟域 | `S_csi_rx_clk` / `MIPI_RX_BYTE_CLK` | `P/user_source/hdl_source/design_top_wrapper.v:549,654-668`；`P/td_project/camera_to_dsi_display.sdc:11` |
| 本次基线约束频率 | 59.995 MHz，周期约 16.668 ns | `PHY/final_timing.rpt:35-38,53-55` |
| 复位 | `i_rst_n=S_rst_n`，低有效；当前 `S_rst_n=S_pll_lock` | `P/user_source/hdl_source/design_top_wrapper.v:217-218,654-668` |
| 分辨率 | 1280×720 | `P/user_source/hdl_source/isp/isp_top.v:49-53,77-80` |
| 每有效拍像素数 | 4 个 RGB888 像素，共 96 bit | `P/user_source/hdl_source/isp/awb/awb.v:28-37` |
| 每行有效拍数 | 320 拍，即 1280/4 | 由上述两个已确认参数直接计算；Sobel 同样定义 `GROUPS_PER_LINE=IMG_WIDTH/4`，见 `rtl/custom/custom_sobel_4px.v:8-22` |
| backpressure | 自研插点不提供 `ready`；必须接受连续逐拍 valid 流，不能停顿、插拍或重排 | lab_ex2 的边缘模块虽带 ready 名称，但只做组合透传，见 `V2/user_source/hdl_source/isp/edge_detect_96.v:6-20`；现有 custom Sobel 无 ready，见 `rtl/custom/custom_sobel_4px.v:7-21` |

59.995 MHz 是当前实现报告对该时钟的约束/传播结果，不等于重新集成后已经时序闭合。完整工程改动后仍须重新 place/route。

## 2. 96-bit 像素顺序和标记语义

### 2.1 四像素与 RGB 通道顺序

按现有工程和 lab_ex2 的处理顺序定义：

| 逻辑像素序号 | 96-bit lane | 24-bit 格式 |
|---|---|---|
| pixel 0 | `tdata[95:72]` | `{R[7:0], G[7:0], B[7:0]}` |
| pixel 1 | `tdata[71:48]` | `{R[7:0], G[7:0], B[7:0]}` |
| pixel 2 | `tdata[47:24]` | `{R[7:0], G[7:0], B[7:0]}` |
| pixel 3 | `tdata[23:0]` | `{R[7:0], G[7:0], B[7:0]}` |

证据链：

- `data128_96` 依次把四个 24-bit RGB 数据放入 `[95:72]`、`[71:48]`、`[47:24]`、`[23:0]`：`P/user_source/hdl_source/isp/data128_96/data128_96.v:10-17`。
- AWB 从低到高拆出四个 `{R,G,B}` lane：`P/user_source/hdl_source/isp/awb/awb.v:99-118`，并按 `x4,x3,x2,x1` 从高位到低位重新拼回：同文件 `:425-455,478-482`。
- lab_ex2 明确把 `[95:72]` 命名为 `pix0`，随后依次到 `[23:0]` 的 `pix3`：`V2/user_source/hdl_source/isp/edge_detect_96.v:22-32`。
- 当前 custom Sobel 使用相同 lane 顺序：`rtl/custom/custom_sobel_4px.v:82-90`。

这里确认的是**总线 lane/处理顺序**。现有这些文件没有单独声明画面坐标的左右方向，本文不进一步推断 sensor 输出的物理左右方向。

### 2.2 `tvalid`、`tuser`、`tlast`

| 信号 | 真实含义 | 有效条件和注意事项 | 依据 |
|---|---|---|---|
| `tvalid` | 当前 96-bit 拍含 4 个有效像素 | 高电平时才允许更新像素计数和 Sobel 行缓存 | `awb.v:474-476`；`custom_sobel_4px.v:166-173,205-212` |
| `tuser` | frame_start | 只在 `tvalid && tuser` 时采样新模式和阈值；无效拍上的 tuser 不得触发切换 | `P/user_source/hdl_source/isp/isp_top.v:59-69` 的注释；现有 adapter `rtl/custom/custom_axis96_mode_adapter.v:54-78` |
| `tlast` | line_end | AWB 以 `valid_d1==0 && valid_d2==1` 产生，所以真实流允许 `tvalid=0,tlast=1` | `P/user_source/hdl_source/isp/awb/awb.v:461-476` |

没有可用于此插点的 `de`、`hsync`、`vsync`。没有可让模块停止上游的 `ready`。这些信号不得加入视频数据平面接口。

## 3. `custom_processing_top` 规划

### 3.1 端口契约

视频数据平面只能有以下端口：

| 端口 | 位宽 | 方向 | 说明 |
|---|---:|---|---|
| `i_clk` | 1 | input | 接 `S_csi_rx_clk` |
| `i_rst_n` | 1 | input | 低有效，接 ISP 的 `I_rst_n` |
| `i_tdata` | 96 | input | 四个 RGB888 像素 |
| `i_tvalid` | 1 | input | 像素拍有效 |
| `i_tuser` | 1 | input | frame_start |
| `i_tlast` | 1 | input | line_end，允许在 invalid 拍单独出现 |
| `o_tdata` | 96 | output | 四个 RGB888/灰度复制/二值复制/Sobel 灰度复制像素 |
| `o_tvalid` | 1 | output | 固定延迟 2 拍 |
| `o_tuser` | 1 | output | 固定延迟 2 拍 |
| `o_tlast` | 1 | output | 固定延迟 2 拍，包括 invalid line_end |

为满足模式控制要求，另设控制平面输入 `i_mode_req[1:0]` 和 `i_threshold[7:0]`。它们不是 AXI-stream/视频握手信号；顶层只在有效帧首采样。第一版不连接实体按键，独立测试平台直接驱动这两个端口。

### 3.2 模式和统一两拍延迟

| `mode` | 输出 | 算法来源 | 输入到输出延迟 | 空间关系 |
|---|---|---|---:|---|
| `2'b00` | RGB 旁路 | `custom_rgb_passthrough` | 2 拍 | 原像素位置 |
| `2'b01` | 灰度 RGB | `Y=(77R+150G+29B+128)>>8`，三个通道复制 Y | 2 拍 | 原像素位置 |
| `2'b10` | 二值 RGB | `gray >= threshold` 输出白，否则黑 | 2 拍 | 原像素位置 |
| `2'b11` | Sobel 边缘 RGB | signed Gx/Gy，`abs(Gx)+abs(Gy)` 饱和到 8 bit，三个通道复制 | 2 拍 | 保留当前一行/一像素因果空间偏移和边界清零 |

算法依据：`rtl/custom/custom_rgb_passthrough.v:1-7`、`custom_rgb_to_gray.v:1-12`、`custom_gray_threshold.v:1-8`、`custom_sobel_4px.v:104-158`。Sobel 的固定两拍输出及 marker 同步寄存见 `custom_sobel_4px.v:176-212`；独立 Icarus 结果为 `valid=173 marker=216 reset=4 hardcoded=7 errors=0`，见 `sim/custom/sobel_iverilog_evidence.txt:77-93`。真实 PH1P `opt_gate` 资源为 LUT 1039、REG 155、SLICE 976、ERAM20K 3、DRAM LUT 0、DSP 12，见 `docs/CUSTOM_SOBEL_SYNTH_REPORT.md:109-126`。

### 3.3 内部结构

```text
                           +--> two-cycle bypass delay --------+
i_tdata --> lane unpack ---+--> gray + two-cycle delay --------+--> mode_d2 mux --> o_tdata
             |             +--> gray/threshold + delay --------+
             +----------------> custom_sobel_4px (always on) ---+

i_tvalid/i_tuser/i_tlast ------> unconditional two-stage marker pipe ------> outputs
mode_for_beat ------------------> two-stage mode pipe ----------------------> mux select
```

实现时必须遵守：

1. `custom_sobel_4px` 始终接收完整的 `i_tdata/i_tvalid/i_tuser/i_tlast`，无论当前选择哪种显示模式都持续更新两条行缓存；不能用 mode 对 Sobel 时钟、valid 或 RAM 写入作门控。
2. 旁路、灰度和二值路径补成与 Sobel 相同的两拍。最终 mux 放在四条已对齐路径之后，不再增加第三拍。
3. marker 流水线必须**每个时钟都移位**，不能只在 valid 时使能；这样 `tvalid=0,tlast=1` 才能在两拍后变成 `o_tvalid=0,o_tlast=1`。
4. `o_tvalid=0` 时强制 `o_tdata=96'd0`，但 `o_tuser/o_tlast` 仍按两拍传播。
5. 不增加、删除、停顿或重排任何有效数据拍；没有 ready/backpressure。
6. 当前 Sobel 已通过 320 拍连续行、跨 4-pixel group 窗口、连续帧、invalid line-end 和中途复位测试；窗口跨拍桥接位于 `custom_sobel_4px.v:132-146`，ERAM 读写与历史更新位于 `:160-174,214-248`。

资源注意：当前 Sobel 内部已实例化四个 `custom_rgb_to_gray`（`custom_sobel_4px.v:82-85`）。若统一顶层再为灰度/二值路径另实例化四个乘法灰度单元，按两个独立综合结果作**规划估算**会使 custom 部分达到约 24 个 DSP；这不是完整工程报告。第一版应优先保持已验证 Sobel 不变，集成综合后读取真实资源；若 DSP 余量不足，再把共享灰度作为单独、可回归验证的优化，不在首次集成同时重构 Sobel。

### 3.4 帧首模式与阈值采样

必须同时维护：

- `active_mode[1:0]`、`active_threshold[7:0]`：当前帧状态；复位后 mode=`2'b00`，threshold 置确定值（建议 0，仅在二值模式下有意义）。
- `mode_for_beat`、`threshold_for_beat`：本输入拍实际使用的值。
- 与数据同长的 `mode_d1/mode_d2`，用于两拍后选择对应输出路径。

有效帧首组合选择规则：

```text
sof_accept = i_tvalid && i_tuser
mode_for_beat      = sof_accept ? i_mode_req  : active_mode
threshold_for_beat = sof_accept ? i_threshold : active_threshold
```

在同一个上升沿把新请求写入 `active_*`，并把 `mode_for_beat` 送入 mode 两拍流水线。因此：

- 帧首数据本身立即使用新 mode/threshold；
- 两拍后的第一个输出数据使用该帧新 mode，而不是上一帧 mode；
- 帧中改变请求只改变尚未提交的控制值，不影响当前帧；
- 两帧可以无额外空闲拍衔接。

现有一拍 adapter 已验证过“帧首拍使用新值”的选择方式，可作为控制逻辑参考：`rtl/custom/custom_axis96_mode_adapter.v:52-83`；但它只有三种模式且总延迟一拍，不能直接作为最终顶层并联使用。

## 4. 精确连接表

### 4.1 AWB -> `custom_processing_top`

| AWB 信号 | custom 输入 | 位宽 | 时钟域 | 有效/语义 | custom 固定延迟 |
|---|---|---:|---|---|---:|
| `awb_O_tdata` | `i_tdata` | 96 | `S_csi_rx_clk` | `awb_O_tvalid=1` 时为 4×RGB888 | 2 拍 |
| `awb_O_tvalid` | `i_tvalid` | 1 | 同上 | 像素拍有效 | 2 拍 |
| `awb_O_tuser` | `i_tuser` | 1 | 同上 | frame_start；采样条件为 valid && user | 2 拍 |
| `awb_O_tlast` | `i_tlast` | 1 | 同上 | line_end；允许 valid=0 | 2 拍 |
| `axi4s_video_aclk` | `i_clk` | 1 | 即 `S_csi_rx_clk` | 上升沿 | — |
| `I_rst_n` | `i_rst_n` | 1 | 低有效异步复位；释放需按视频域时序实现 | 低有效 | — |

AWB 端口和当前网名依据：`P/user_source/hdl_source/isp/isp_top.v:26-34,77-93`；AWB 自身端口依据：`P/user_source/hdl_source/isp/awb/awb.v:20-38`。

### 4.2 `custom_processing_top` -> `data_96bit_to_128bit`

| custom 输出 | 下游连接 | 位宽 | 当前可确认结论 |
|---|---|---:|---|
| `o_tdata` | `I_96b_data` | 96 | 精确连接 |
| `o_tvalid` | `I_96b_valid` | 1 | 精确连接 |
| `o_tuser` | `I_96b_frame_start` | 1 | 精确连接 |
| `o_tlast` | **转换器无对应端口** | 1 | 不能虚构连接；候选是替代 `isp_top.O_tlast` 的来源，但必须结合 96→128 输出节拍验证 |

转换器真实端口仅为 clock/reset、frame_start、valid、96-bit data 及对应 128-bit 输出：`P/user_source/hdl_source/isp/data96_128/data96_128.v:3-14`。它在 `:23-28` 独立延迟 frame_start，在 `:31-75` 按连续 valid 计数重组 96→128；`I_rst_n` 没有被这些时序过程使用。lab_ex1 当前 `O_tlast=awb_O_tlast`：`P/user_source/hdl_source/isp/isp_top.v:36-40`。lab_ex2 虽将 edge 的 data/valid/user 接入转换器，却仍把 ISP 的 `O_tlast` 接 AWB 的 `tlast`：`V2/user_source/hdl_source/isp/isp_top.v:42-47,102-132`。

顶层 `video_in` 实际只消费 ISP 的 frame_start、valid 和 128-bit data，并不连接 ISP `tlast`：`P/user_source/hdl_source/design_top_wrapper.v:672-690`。因此，当前主链路不消费 line_end 不能替代接口正确性验证；未来 testbench 必须明确检查转换前后的 frame_start/valid/data 节拍，并对 `O_tlast` 的设计去向作出有证据的决定。

### 4.3 ready 旁路

自研模块没有 ready。AWB 仍可保留现有 `awb_O_tready=O_tready` 的控制旁路，但这不是 custom 的流控端口。AWB 内部只是 `assign I_tready=O_tready`：`P/user_source/hdl_source/isp/awb/awb.v:484-485`；lab_ex1 的连接见 `P/user_source/hdl_source/isp/isp_top.v:36,87,92`。必须用连续 valid 测试证明 custom 从不依赖 ready。

## 5. 按键控制与 CDC 方案（只规划，不实现）

### 5.1 引脚和命名

- 板级原理图将 KEY0～KEY3 对应为 D5/A9/B9/C7：`docs/OFFICIAL_DOC_INDEX.md:55,207`。
- 官方 `8_key_sw` 例程也把 `key[0:3]` 约束到 D5/A9/B9/C7，且为 LVCMOS33、PULLUP：`vendor/official_docs/2_Example/8_key_sw/key_sw.adc:2-5`。
- 如果 UI 文档称 KEY1～KEY4，应理解为同四个物理键的人类编号偏移，映射关系在新增 ADC 前仍要按实际板卡丝印复核；见 `docs/PROJECT_ANALYSIS.md:119`。
- 当前 lab_ex1 的 `I_button[1:0]` 是 N2/J14，并用于 AE 控制，不是上述四键：`P/user_source/constraints_source/pin.adc:10-11`、`P/user_source/hdl_source/design_top_wrapper.v:506-515`。不能复用其名称或假设物理来源相同。

因此，D5/A9/B9/C7 有官方资料依据，但**尚未加入当前工程**；本阶段不修改 ADC，也不把按键接到 `custom_processing_top`。

### 5.2 按键时钟域、消抖和单次触发

物理按键相对 FPGA 时钟是异步输入。未来建议：

1. 以现有、稳定且已约束的板级 `I_sys_clk` 50 MHz 域作为按键控制域；其管脚 C4 和 20 ns 约束分别见 `P/user_source/constraints_source/pin.adc:2`、`P/td_project/camera_to_dsi_display.sdc:1`。
2. 每个低有效按键先做两级同步，再做计数式消抖；仅在稳定按下边沿产生一个单周期 pulse，释放也必须消抖，避免一次按键多次触发。
3. KEY 到模式的具体人机映射在 UI 需求确认后再定；不要在 CDC 模块里硬编码板级管脚。

### 5.3 50 MHz -> `S_csi_rx_clk` CDC

多位 `{mode_req[1:0],threshold[7:0]}` 不得逐位双触发器同步。推荐 bundled-data req/ack toggle 握手：

1. 50 MHz 源域把完整 payload 写入保持寄存器，然后翻转 `req_toggle`；payload 在收到 ack 前保持不变。
2. `req_toggle` 经两级触发器同步到 `S_csi_rx_clk` 域；目标域检测 toggle 改变后一次性捕获稳定 payload 到 `pending_mode/pending_threshold`。
3. 目标域只在下一次 `i_tvalid && i_tuser` 时把 pending 值提交给视频帧状态，并在提交后翻转 `ack_toggle`。
4. ack 经两级触发器返回 50 MHz 域；源域在 ack 前不发布下一组 payload。

这种方案使多位数据在跨域采样期间保持稳定，并把最终生效点严格限制在视频帧首。如果长时间没有视频帧，ack 会等待，这是预期行为；UI 可以显示 pending 状态，不能绕过帧首直接改 active mode。

## 6. 自研源文件、工程改动和编译顺序

### 6.1 首次最小集成需要的自研 RTL

推荐 TD 编译/依赖顺序：

1. `rtl/custom/custom_rgb_passthrough.v`
2. `rtl/custom/custom_rgb_to_gray.v`
3. `rtl/custom/custom_gray_threshold.v`
4. `rtl/custom/custom_sobel_4px.v`
5. `rtl/custom/custom_processing_top.v`（后续新建，本阶段未编写）

TD 通常会解析 Verilog 依赖，但仍按“叶子模块先、顶层后”加入，便于审查。首次集成不加入按键/CDC RTL；它们应在图像处理顶层独立仿真和完整工程资源检查之后作为第二个可回退变更集加入。

### 6.2 仅用于独立验证、不能与最终顶层同时实例化的旧模块

| 文件 | 原因 |
|---|---|
| `rtl/custom/custom_axis96_mode_adapter.v` | 仅三模式、固定一拍，并已包含 mode/threshold 锁存和灰度/二值 datapath；若与新顶层串联会多一拍并重复处理，若并联会重复资源。依据：`:1-22,40-86`。 |
| `rtl/custom/custom_video_mode_select.v` | 使用当前插点不存在的 de/hsync/vsync，且只有三模式、一拍；只能保留作早期通用接口 testbench 参考。依据：`:1-26,70-95`。 |

`sim/custom/tb_custom_axis96_mode_adapter.v` 和 `tb_custom_video_mode_select.v` 仍是回归参考，不加入 TD 综合源。`tb_custom_sobel_4px.v` 继续作为 Sobel 单元回归，也不加入 TD 工程。

### 6.3 未来最小文件改动

在解除本阶段禁令后，首次集成预计只需：

- 新增 `rtl/custom/custom_processing_top.v`；
- 新增 `sim/custom/tb_custom_processing_top.v` 及可重复运行脚本/证据；
- 修改 `P/user_source/hdl_source/isp/isp_top.v`，在 AWB 后实例化统一顶层并替换转换器的 data/valid/frame_start 来源；
- 通过 TD GUI 把上述 5 个自研 RTL 加入 `P/td_project/camera_to_dsi_display.al` 的 source set。

首次集成不修改 `design_top_wrapper.v`、按键 ADC、原 SDC、DDR/MIPI/HDMI/FIFO IP 或相机寄存器。按键与 CDC、基线 DDR/约束修复应分别作为后续独立变更集，避免把图像功能回归与板级时钟修复混在一起。

## 7. 基线阻塞项复核

表中“否（阻止签核）”表示工具可以机械执行该阶段，但结果不能作为通过证据。

| 优先级 | 项目与当前状态 | 证据 | 阻止写 custom RTL | 阻止集成综合 | 阻止 place/route | 阻止安全 bitstream/Download | 推荐处置 |
|---|---|---|---|---|---|---|---|
| P0 | **DDR ref 配置错误仍存在**：IP 声明 100 MHz，实际接 50 MHz | `P/user_source/hdl_source/ph1p35_ddr/ddr2/Design.xml:13-15,83-89`；`P/user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v:79`；`P/user_source/hdl_source/design_top_wrapper.v:757-762`；`P/td_project/camera_to_dsi_display.sdc:1` | 否 | 否，可综合 | 否（阻止签核） | **是** | 先由官方支持流程形成 reference/速度档/PLL/SDC 一致方案，重新生成 IP；禁止只手改生成 RTL |
| P0 | **DDR PLL0 VCO 越界仍存在**：当前 50 MHz 与 DIV=3、FBK=32 对应约 533.3 MHz，低于 800 MHz | `docs/BASELINE_BOARD_READINESS.md:23-47`；PH1P 数据手册 PDF 第 77 页（印刷页 71） | 否 | 否 | 否（阻止签核） | **是** | 与上一项一起修复并重新 clean build；观察 lock、`ddrphy_rdy`、训练和读写 |
| P0 | **两个异步 FIFO 的 36 条 gray-pointer `set_max_delay` 全被忽略** | `PHY/camera_to_dsi_display_exception.timing:24-31,44-59`；`docs/BASELINE_BOARD_READINESS.md:84` | 否 | 否 | 否（阻止签核） | **是** | 修复 `set_clock_groups` 与 IP 例外优先级，route 后确认 Ignored=0 |
| P1 | **STA coverage 95.64%，109 个 timing-unconstrained PI/PO 未枚举** | `PHY/final_timing.rpt:8`；`SYN/run.log:1196`；`docs/BASELINE_BOARD_READINESS.md:72-90` | 否 | 否 | 否（阻止签核） | **是** | 导出 `report_unconstrained_paths`/GUI 等效明细，逐项分类为需约束、专用 IP 覆盖或合法 false path |
| P1 | **fabric `scl_clk` 未被 SDC/Clock Summary 覆盖**，且直接作多个 posedge/negedge 时钟 | `P/user_source/hdl_source/uics500_cfg/uii2c.v:81,109-188`；`P/user_source/hdl_source/design_top_wrapper.v:517-525`；`PHY/run.log:139` | 否 | 否 | 否（阻止签核） | **是** | 用工具支持的 generated clock 约束，或经单独 RTL 评审改成 clock-enable；重新检查 unconstrained 对象 |
| P1 | **相机 24 MHz 网络告警仍存在**：`O_cam_24m_syn_3` mixed fanout，`pll_clk_24m` local routing | `PHY/run.log:138,1585-1586`；`docs/BASELINE_BOARD_READINESS.md:94-100` | 否 | 否 | 否（阻止签核） | **是，除非安路给出可接受性结论** | 消除 mixed clock/data 用法或取得厂商签核；重新跑 clock detail 和 route |
| P1 | **`dhi_clk` 仍是隐式 wire**；它确为 DDR 用户时钟且导出为 `O_ddr_clk` | `SYN/run.log:230`；`P/user_source/hdl_source/ph1p35_ddr/ph1p35_324_ddr_wrapper.v:60-83`；`docs/BASELINE_BOARD_READINESS.md:49-70` | 否 | 否 | 否 | 是，作为 DDR 连接质量门槛 | 显式声明并启用隐式 net 检查；它不是 ref 频率错误根因 |
| P1 | **96→128 line_end/复位契约不完整**：转换器无 tlast 端口，`I_rst_n` 未在过程内使用 | `P/user_source/hdl_source/isp/data96_128/data96_128.v:3-14,23-75`；lab1 `P/user_source/hdl_source/isp/isp_top.v:36-40,95-106`；lab2 `V2/user_source/hdl_source/isp/isp_top.v:42-47,121-132` | 否 | 否 | 否 | 是，作为功能正确性门槛 | 先做包含真实转换器和 `video_in` 接口的仿真，确认 frame_start/valid/line-end 策略后再决定最小修改 |
| P1 | **复位释放/DDR ready 仍需确认**：`S_rst_n=S_pll_lock` 直接用于多个异步复位域；`S_init_calib_complete` 主要用于 debug 观察，未用于全局释放 video/MC reset | `P/user_source/hdl_source/design_top_wrapper.v:217-218,220-304,377-402,672-762` | 否 | 否 | 否（阻止最终签核） | 是，除非通过设计审查和板测 | 复核每域同步释放；在 DDR 配置修正后确认 app ready/校准前不会发出有害事务 |
| P2 | **PHY-5016 四条网络仍未唯一定位** | `PHY/run.log:198-211`；`docs/BASELINE_BOARD_READINESS.md:98,145` | 否 | 否 | 否 | 条件性：定位后决定 | 用 `analyze_clock -detail`/等效报告导出 net，不能直接 waiver |
| P2 | **HDMI 74.25/75.0 配置表现不一致**；本次实现为 75.002 MHz | `docs/VIDEO_PIPELINE_INTERFACE.md:34`；`PHY/final_timing.rpt:39,56` | 否 | 否 | 否 | 阻止 HDMI 功能签核，不单独构成电气安全结论 | 对齐 PLL XML、生成 RTL和目标视频时序；重新验证显示器兼容性 |
| P2 | **MIPI/RAW 宽度和未驱动告警尚未逐项 waiver**，包括 `I_lane_invert` 4→2、RAW 未驱动记录 | `docs/BASELINE_BUILD_REPORT.md:132-151` | 否 | 否 | 否 | 阻止正式发布签核 | 结合 LANE_NUM=2 活动分支逐项证明未用；不得仅因 bitgen 成功而忽略 |

现有 route 的 setup `+1.408 ns`、hold `+0.020 ns` 只覆盖当前网表及已覆盖路径：`PHY/final_timing.rpt:25-29`。加入 custom RTL 后该结果全部失效；尤其 hold 余量很小，必须重新实现，不能外推。

## 8. 后续验证与实施顺序

### 8.1 `custom_processing_top` 独立功能仿真

新 testbench 至少应覆盖：

1. 四模式逐一验证，固定硬编码黑、白、红、绿、蓝和阈值边界；
2. 每行连续 320 个 valid 拍，不插空；跨 4-pixel group 的 Sobel 检查继续使用独立参考模型；
3. `tvalid/tuser/tlast/tdata` 精确两拍队列对比；invalid 输出 data 必须为 0；
4. `tvalid=0,tlast=1` 两拍后完整传播且不增加有效数据计数；
5. 两帧无额外 idle 拍衔接；帧中改 mode/threshold，仅下一有效 SOF 生效；
6. 特别硬编码检查新帧首第一个输出拍使用新 mode，而非上一帧 mode；
7. Sobel 未选中期间仍与参考模型同步更新，下一帧切回 Sobel 时不得出现行缓存冷启动或旧帧污染；
8. 复位前后、帧首、行首/行尾、最后一行、超时和可靠非零失败退出状态。

### 8.2 插点集成仿真

独立顶层通过后，再搭建小型链路：AWB 接口行为模型 -> `custom_processing_top` -> **真实** `data_96bit_to_128bit`。重点验证：

- 320 个 96-bit valid 拍如何变为 240 个 128-bit valid 拍；
- frame_start 相对第一个 128-bit valid/data 的真实位置；
- invalid line-end 在转换器无 tlast 输入时的去向；
- back-to-back 行/帧和复位后的计数器状态；
- 旁路模式除固定两拍外不改变像素序列。

在这一步完成前，不修改 `isp_top` 的 `O_tlast` 来源。

### 8.3 完整工程顺序

1. 完成并通过 `custom_processing_top` 独立 Icarus 回归。
2. 完成真实 96→128 小链路仿真并关闭 tlast/reset 契约问题。
3. 在 project 工作副本做最小 ISP 插入和 TD source-list 修改；保留 vendor 只读。
4. 先执行独立/全工程 synthesis，检查 black box、latch、implicit wire、width truncation、DSP/ERAM 推断与资源余量。
5. 与图像 RTL 开发并行、但在最终 bitstream 前关闭第 7 节 P0/P1 板级时钟与约束问题。
6. 对修正后的完整工程执行 clean synthesis -> place -> route -> final timing；要求 100% 可解释的时序覆盖、FIFO max-delay 生效、无未处理 critical warning，并重新检查 setup/hold。
7. 通过 bitgen 只说明生成成功；在下载前再次核对 bitstream 路径、时间、大小、SHA-256 与对应源码/约束版本。
8. 首次上板按最小风险顺序观察 PLL lock、DDR `ddrphy_rdy`/读写、MIPI activity、旁路画面，再逐帧切换灰度、二值、Sobel；最后才做长时间稳定性和 QSPI 冷启动。

## 9. 回退方案

1. 把首次集成限制为 `isp_top.v` 的一个实例和 TD source-list 的五个自研文件；不同时加入按键、CDC 或基线时钟修复。
2. 如果 custom 顶层仿真失败，回退到已通过的 `custom_axis96_mode_adapter`/Sobel 单元测试，不改 lab_ex1。
3. 如果集成 synthesis 资源或时序恶化，先固定 mode 为旁路并保留两拍接口检查，再分别启用灰度/二值/Sobel定位；不能用关闭 Sobel 行缓存更新的方式节省资源。
4. 如果完整工程出现问题，删除 `custom_processing_top` 实例并恢复 AWB 直接连接转换器，同时从 project source set 移除新增自研源；vendor 原件始终保持不动，可用其哈希作基线比对。
5. DDR/SDC/时钟修复必须独立提交、独立 clean build。若结果不如基线，回退该变更集，而不是用历史 bitstream 掩盖失败。

## 10. 三项最终判断

1. **是否具备编写 `custom_processing_top` 的条件：是。** 真实插点、lane 顺序、59.995 MHz `S_csi_rx_clk` 域、低有效复位、valid/SOF/invalid-EOL 语义及 Sobel 两拍契约均已有源码和报告证据。编写时仍须把 mode 选择一起延迟两拍，保证新帧首拍使用新 mode/threshold。
2. **可与 RTL 开发并行处理的问题：** 按键 UI 映射和 req/ack CDC 细化、DDR 官方一致配置方案、FIFO 约束优先级、unconstrained 对象导出、`scl_clk` 时序方案、相机 24 MHz clock detail、PHY-5016 定位及 HDMI 74.25/75 MHz 核对。这些不妨碍独立编写/仿真 custom 顶层，但不得拖到下载之后。
3. **生成或下载 bitstream 前必须解决的问题：** DDR 100/50 MHz 配置与 PLL0 VCO、36 条被忽略的 FIFO CDC max-delay、未约束对象/`scl_clk`、相机 24 MHz critical warning、`dhi_clk` 显式声明和复核、复位/DDR calibration 启动策略，以及 96→128 位宽转换后的 frame_start/tlast/reset 契约。随后必须对完整集成网表重新 clean synthesis、place/route、final timing 和 bitgen；当前历史 bitstream 不批准下载。
