# lab_ex1 未修改基线构建与上板检查清单

> 适用对象：vendor/lab_ex1_mipi_hdmi_SC500_720P  
> 状态：计划文档；2026-09-21 尚未执行 clean build、下载或上板  
> 原则：vendor 保持只读；任何清理和构建只在未来创建的工作副本中进行。

## 1. 证据边界

本清单把四类结论严格分开：

1. **文件存在**：只说明源文件、约束、IP 和工程描述可见。
2. **clean build 通过**：必须由本次从干净工作副本生成的日志、报告和 bitstream 证明。
3. **易失下载/上板通过**：必须有当前硬件观察记录；不能由历史 .bit 或历史日志替代。
4. **QSPI 冷启动通过**：必须完成 Flash 擦除、编程、校验，并在断开下载连接、完全掉电后启动成功。

官方流程依据：

- vendor/official_docs/安路软件使用完整流程.pdf：工程/器件选择第 3 页，语法/展开检查第 7 页，仿真第 8–16 页，IO 约束与编译第 17–19 页，Tools→Download 和 bit 下载第 20–22 页。
- vendor/official_docs/（必看）PH1P35烧写程序的使用方法.pdf：WinUSB/VID-PID 第 1 页，AL-LINK-FT/Local Host/5555 第 2 页，未识别或 OCCUPIED 处理第 3 页。

## 2. 构建前置条件

| 检查项 | 期望 | 证据/状态 |
|---|---|---|
| 工具版本 | Tang Dynasty v6.2.168116；若使用其他版本，必须记录并视为单独基线 | 工程历史日志和 .al 元数据；当前安装状态尚未确认 |
| FPGA 器件 | PH1P35MDG324 可选且器件库完整 | 三套工程 .al；开发板原理图 _1.pdf 第 1 页 |
| IP/许可证 | MIPI D-PHY、DDR3、HDMI、FIFO 生成核均可综合/实现 | 当前未验证 |
| 工程入口 | design_top_wrapper | lab_ex1 的 camera_to_dsi_display.al |
| 活动源清单 | .al 中 52 项可解析，不出现丢失文件或绝对路径错误 | 现有文件级分析；clean build 时重新检查 |
| 活动引脚约束 | 工程 .al 实际引用的 pin.adc | lab_ex1 工程文件 |
| 活动时序约束 | 工程目录 camera_to_dsi_display.sdc | lab_ex1 工程文件；user_source/constraints_source/timing.sdc 未被工程引用 |
| 构建目录 | 新的、可删除的工作副本；不得直接清理 vendor | 本清单要求 |
| 板卡/相机 | 不属于编译前提，但属于下载后上板前提 | 见第 6 节硬阻塞 |

## 3. 基线冻结

- [ ] 将 vendor/lab_ex1_mipi_hdmi_SC500_720P 标记为只读参考，不在其中运行 Clean、重新生成 IP 或编译。
- [ ] 在允许修改工程的后续阶段，从 vendor/lab_ex1_mipi_hdmi_SC500_720P 创建一个新的构建工作副本；本阶段不创建。
- [ ] 记录源基线：
  - 当前 vendor/lab_ex1 目录为 313 个文件、91,098,458 字节；
  - 当前目录树 SHA-256 为 d1f1462f855bfb96da2e96bd2295f1eb1fab29175e37cec0dd9cc29b8c6f8bb8；
  - 当前 project/lab_ex1_mipi_hdmi_SC500_720P 与 vendor/lab_ex1 逐文件 SHA-256 相同。
- [ ] 在复制后重新做逐文件哈希比较；只允许构建输出目录出现变化，源文件、.al、.adc、.sdc、IP 配置 XML 必须保持不变。
- [ ] 给本次运行分配唯一编号，记录日期、主机、TD 版本、许可证状态和工作副本绝对路径。

目录树哈希算法应与 docs/OFFICIAL_DOC_INDEX.md 相同：按相对路径排序，对每个文件计算 SHA-256，再串联“相对路径 + NUL + 文件 SHA-256 + LF”计算总摘要。

## 4. Clean build

官方“安路软件使用完整流程”没有给出可审计的命令行 clean 参数或明确的 Clean 菜单，因此推荐用**新工作副本**实现可复现的 clean 起点，而不是在 vendor 中删除历史目录。

### 4.1 打开和静态检查

- [ ] 启动 TD，记录完整版本号。
- [ ] 打开工作副本中的：
  - lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al
- [ ] 在 Project/Device 设置中确认：
  - Device：PH1P35MDG324；
  - Top：design_top_wrapper；
  - 不自动升级或重新生成任何厂商 IP；
  - 52 个活动源均存在。
- [ ] 确认活动约束文件是工程 .al 所列文件，而不是仅在目录中存在的同名/备用文件。
- [ ] 检查源/约束路径是否仍含旧机器的绝对路径；若存在，记录为 build blocker，不直接改工程。
- [ ] 按官方流程 PDF 第 7 页执行语法/层次展开检查，保存控制台输出。

### 4.2 清理历史结果

以下动作只允许在新工作副本中：

- [ ] 如果 TD 提供 Clean/Reset Runs，记录所用菜单和清理对象。
- [ ] 如果工具没有可确认的 clean 功能，关闭 TD 后只删除工作副本中的历史 Runs、best_result 和其他可再生输出；删除前列出精确路径并保留源树哈希。
- [ ] 重新打开工程，确认工具没有从 vendor 路径读取历史数据库。
- [ ] 不删除或重生成 ph1p35_ddr、pll、MIPI、HDMI、FIFO 等 IP 的源/配置文件。

### 4.3 完整实现流程

- [ ] 按官方流程 PDF 第 17–19 页确认 IO 约束加载后，运行完整 compile/implementation 流程，至少覆盖：
  1. elaboration/synthesis；
  2. placement；
  3. routing；
  4. timing analysis；
  5. bitstream generation。
- [ ] 保存未经截断的控制台和各阶段日志。
- [ ] 对所有 error 和 warning 分类；以下任一情况直接停止：
  - 缺失源文件、加密 IP 或许可证；
  - 顶层/器件与基线不一致；
  - 引脚冲突、未约束顶层端口或 IO 标准错误；
  - 时钟未创建、派生时钟缺失或约束解析失败；
  - MIPI/DDR/HDMI/FIFO IP 参数或 wrapper 端口不匹配；
  - setup/hold 不满足；
  - bitgen 未完成。

### 4.4 clean-build 交付物

- [ ] TD 完整版本、主机和许可证信息。
- [ ] 工作副本源树哈希以及与 vendor 基线的差异清单。
- [ ] 完整 synthesis/place/route/timing/bitgen 日志。
- [ ] 资源报告：LUT、FF、ERAM、DSP、PLL 和专用 MIPI/DDR 资源。
- [ ] 每个时钟域的 setup/hold 摘要，不能只抄 global slack。
- [ ] 所有 warning 清单及处置分类。
- [ ] 本次生成 bitstream 的绝对路径、大小、时间戳和 SHA-256。
- [ ] 明确写“未运行 RTL 仿真”或附上本次仿真证据；不能把编译通过写成仿真通过。

## 5. 构建通过判据

只有同时满足下列条件，才可写“未修改 lab_ex1 clean build 通过”：

- [ ] 源和配置与冻结基线无非构建性差异；
- [ ] 使用记录明确的 TD/器件库/IP/许可证；
- [ ] 完整流程零 error；
- [ ] 活动引脚及时序约束均成功读取；
- [ ] 所有要求时钟的 setup/hold 满足；
- [ ] bitstream 由本次 run 生成，且已记录 SHA-256；
- [ ] 关键 warning 已审阅，尤其是 DDR ref_clk、未约束端口、跨时钟、复位和 IP 黑盒。

即使满足以上条件，也只能宣布“build 通过”，不能宣布相机、DDR、HDMI 或板上启动通过。

## 6. 上板前硬阻塞

当前不应连接相机并下载测试，直到以下项目闭环：

1. **确认实物板版号**：PCB 丝印应与 HX1P35B_FT_40P / PH1P35_FT V1 原理图对应。依据：开发板原理图 _1.pdf 第 1 页。
2. **确认 FPC 插接方向**：官方图纸只确认板端 40 个电气触点+2 固定脚、相机端 24 个电气触点+2 固定脚，没有确认同面/异面和金手指朝向。不得靠试插判断。
3. **确认 DDR 参考时钟**：lab IP 配 100 MHz，但 wrapper 接 50 MHz；板上另有 K5/L5 100 MHz 差分。必须获得 PH1P DDR 专用文档、厂家答复或已知正确的同板工程，不能猜测改接。
4. **确认相机时钟/寄存器表**：23.809524 MHz 在 SC500CS 允许的 6–40 MHz 范围内，但表注释为 24M、模组图写主机 27M；需确认精确模式参数。
5. **确认上电/复位**：XSHUTDN/PWDNB 低有效；数据手册第 11、13 页的上电间隔需要由板级电源、配置期间 IO 状态和 RTL 共同满足。

## 7. 易失 bitstream 下载

在第 5 节 build 通过且第 6 节上板条件满足后：

- [ ] 完全断电后连接已确认方向的相机 FPC、HDMI 和下载器。
- [ ] 按 PH1P35 烧写说明第 1 页，用 UsbDriverTool 为 USB_A、VID/PID 0403:6042 安装 WinUSB；按文档要求放置对应工具文件。
- [ ] 按该说明第 2 页选择 AL-LINK-FT、Local Host、端口 5555，Refresh、Apply、Close。
- [ ] 若未发现目标，按第 3 页重新打开/Refresh；出现 OCCUPIED 时等待设备释放，不反复并发连接。
- [ ] 在 TD 中按软件流程第 20–22 页打开 Tools→Download，添加**本次 clean build** 的 bit 文件并运行。
- [ ] 只有下载界面到 100% 才记录“易失下载完成”；它仍不代表 QSPI 固化。

## 8. 最小上板 smoke test

每项都要记录测量方法、时间和结果：

- [ ] 板卡电源轨稳定，无异常发热或过流。
- [ ] C4 系统时钟实测约 50 MHz；若使用 DDR100，确认 K5/L5 差分时钟存在且极性正确。
- [ ] 相机 XCLK/MCLK 实测频率和占空比；预期工程值约 23.809524 MHz，必须落在数据手册 6–40 MHz、45–55% 范围。
- [ ] PWDNB/XSHUTDN 上电波形满足低有效复位和数据手册延时。
- [ ] I2C 有 ACK；读取/观察传感器 ID 0xEE27，7 位地址 0x36；不修改现有寄存器表。
- [ ] D-PHY clock lane 进入 HS，物理 data lane 为 D0/D1，P/N 未反相；记录错误状态。
- [ ] CSI/RAW10 每行 payload 和行/帧计数符合 1280×720 模式；不得仅凭 HDMI 有图认定 MIPI 正常。
- [ ] ddrphy_rdy/O_init_calib_complete 到达有效状态；在它未有效前不得把随机画面归因于 ISP。
- [ ] DDR 写入/读出和帧边界稳定，无持续 FIFO overflow/underflow。
- [ ] HDMI 输出为 RGB888、1280×720 时序；连续运行并记录显示器型号、锁定情况和稳定时长。

当前工程把 DDR 校准信号主要用于调试观察，没有明确作为整条视频通路的启动门控；这应记录为上板风险，而不是在基线测试前修改。

## 9. QSPI 固化与断电启动

当前资料只确认：

- PH1P 支持 MSPI x1/x2/x4 和 MultiBoot：DS1300 第 34、38 页；
- 板上模式电阻为 M[2:0]=001，存在配置 SPI Flash：开发板原理图 _3.pdf、_8.pdf 第 1 页；
- 现有下载说明覆盖驱动/AL-LINK-FT 和 bit 下载连接。

以下关键信息仍缺失，因此本步骤当前是 **blocked**：

- Flash 器件在下载工具中的准确选择；
- bit/bin/其他映像格式及起始地址；
- 擦除范围、Program、Verify 和保护位操作；
- 配置状态/失败诊断；
- 断开 USB/JTAG 后的冷启动验收流程。

拿到官方流程后，最少应执行：

- [ ] 读取并记录 Flash ID；
- [ ] 擦除目标区域；
- [ ] 编程本次 clean-build 映像；
- [ ] Verify 或回读哈希；
- [ ] 关闭下载工具并断开下载连接；
- [ ] 完全断电，等待电源放电，再上电；
- [ ] 验证相机→DDR→HDMI 独立启动，并记录证据。

在这组证据完成前，只能写“易失下载测试”，不能写“烧写成功”或“断电启动成功”。

## 10. 当前可执行性结论

- **可以准备 clean build**：源工程、顶层、器件、活动源/约束和对应官方软件流程均已定位，vendor 与 project 基线也已做过逐文件一致性核对。
- **尚不能确认可以实际完成 clean build**：本阶段没有验证 TD v6.2.168116、PH1P35 器件库、许可证和加密 IP 在当前主机可用，也没有运行工具。
- **暂不具备安全、可判定的上板条件**：DDR ref_clk 冲突、FPC 插入方向、实物板版本、SC500CS 时钟/上电时序仍未闭环。
- **不具备可复现的 QSPI 冷启动条件**：缺少官方 Flash 编程与校验步骤。

