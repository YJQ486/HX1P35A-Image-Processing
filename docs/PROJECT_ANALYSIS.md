# 当前集成候选与接口

本轮从已有报告、实际 .al、syn_6 原生 source_manifest 和冻结输入选定 `qa/sc520cs_frame_awb_trial_20261016`，理由是它在同一工程中保留室内 AE、四模式和 AWB A/B/C，且具有当前源绑定的完整构建证据；不是按目录时间推定稳定。活动入口、设备和 bit 以 `../release/current.json` 为准。

下表的文件位置均相对于候选根目录。源码在本地，公开仓库提供路径/哈希而不分发厂商或改编厂商源：

|源 → 目的/接口|时钟、格式及语义|证据|
|---|---|---|
|MIPI DPHY → CSI/RAW10 → uial2axis → isp_top|2 lane RAW10；ISP `I_tdata[39:0]`、valid/user/last；CSI byte 时钟|`lab_ex1_mipi_hdmi/user_source/hdl_source/design_top_wrapper.v:649,680,695,717,769`；`isp/isp_top.v:1-21`|
|demosaic → data128_96 → AE 旁路统计/AWB|`m_aixs_tdata_96[95:0]`，四个 RGB888；空间首像素[95:72]，每像素 R[23:16]/G[15:8]/B[7:0]；AE 先于 AWB|`isp/isp_top.v:102-139`；`rtl/custom/custom_ae_frame_stats.v`|
|共享 delay RAM → 原 AWB/单位增益/完整帧 AWB → 四模式|CSI 域；A/B/C 输出同沿；提前 SOF 经 aligner；模式两拍统一标记延迟；每行320有效拍|`lab_ex1_mipi_hdmi/user_source/hdl_source/awb.v`；`isp/isp_top.v:132-187`；`rtl/custom/custom_frame_awb.v`|
|四模式 → data_96bit_to_128bit → video_in/FIFO/DDR|96→128 重打包，每720行320→240字；无任意 backpressure 承诺；CSI→DDR 用户域|`isp/isp_top.v:171-200`；`design_top_wrapper.v:792-828`|
|DDR/video_out → 面板/HDMI|DDR用户域→HDMI；面板RGB/DE/HS/VS等延迟已分层检查；并非全部图文OSD实物验收|`design_top_wrapper.v:829` 起；`rtl/custom/custom_ae_overlay.v`|
|按键 → 请求 → 帧首提交|低有效；CAM 23.809524 MHz 消抖/长短互斥，事件握手到CSI；不是多位裸同步；短按四模式、长按A/B/C|`design_top_wrapper.v:762-785`；`rtl/custom/custom_key_mode_request.v`|
|AE/AWB 状态 CSI → CAM → HDMI|相干 mailbox；CSI→CAM 226位，低160位室内AE；CAM→HDMI 使用既有468位包；中间状态可合并|`isp/isp_top.v:59-63`；`design_top_wrapper.v:575` 及相应 snapshot 实例|

本地 `isp_top.v` 的完整路径是 `lab_ex1_mipi_hdmi/user_source/hdl_source/isp/isp_top.v`。原厂旧嵌套同名 AWB 不是活动 AWB；不得以全目录扫描同名文件代替真实编译清单。

时钟报告为 CSI 103.520 MHz / 9.660 ns、DDR用户133.333 MHz / 7.5 ns、CAM23.809524 MHz / 42 ns、HDMI75.002 MHz / 13.333 ns；原始sys 50 MHz。`constraints/base_clocks.sdc` 和 `constraints/ddr_clock_relations_audit.sdc`、`i2c_clock.sdc`、`top_clock_relations_ae.sdc`、FIFO生成Tcl及查询期 `diag_entries.sdc` 构成实际链。引脚依赖 .al 中的 `user_source/constraints_source/pin.adc`，均保留哈希而不修改。复位、锁定和DDR-ready链继承候选；本次没有新例外、周期放宽或硬件测量。

源清单：70条含6条AutoExcluded；脚本检查全部路径与394项输入/依赖哈希，显式活动 .v 解析到56个模块名、无重复定义。加密/生成IP的展开依赖仍以TD历史elaboration及原生清单为准，此静态扫描不声称穷尽全部IP模块。原8组仿真105项源绑定及CSA全RGB证书字节匹配复核通过。

原 lab_ex_1/2/3 与 SC500CS 基线保留在本地 vendor/project，用于追溯，不能作为当前 SC520CS 工程入口。板手册的FPC描述、DDR极性/JTAG表项疑点仍以官方原理图、真实约束与实物解决。缺失项按优先级：偏色定量对照和实际加载SHA；全模式/OSD逐项板测；持续运行与反复切换；外部时序/PLL/硬PHY边界；厂商分发授权；独立授权后的Flash冷启动。不得用当前文件存在或正slack代替这些结论。
