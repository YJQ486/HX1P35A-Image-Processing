# custom_sobel_4px ERAM 优化与独立综合报告

## 1. 结论与范围

本轮在独立 QA 工程中完成了 ERAM 模板实验、行缓存小范围改造、Icarus 功能自检和 Tang Dynasty `opt_gate`。最终结果满足本阶段完成标准：功能自检 `errors=0`，`ERAM20K=3`，`DRAM LUT=0`，数据与 `tvalid/tuser/tlast` 按两拍固定延迟对齐，未出现 black box、latch、隐式 wire、位宽截断或未连接端口警告。

结论是：**已具备进入 lab_ex1 集成准备阶段的条件，但本报告不等同于已完成集成或实现时序闭合。** 本轮没有修改或运行 `project/`、`vendor/`、官方 IP、ADC/SDC，也没有执行 place、route、bitgen、Download 或上板。

最终证据：

- 功能仿真：`sim/custom/sobel_iverilog_evidence.txt`
- TD 日志：`qa/custom_sobel_synth_check/td_20260922_135205.log`
- 资源：`qa/custom_sobel_synth_check/custom_sobel_synth_check_gate.area`
- 综合级时序：`qa/custom_sobel_synth_check/custom_sobel_synth_check_gate.timing`
- 流程状态：`qa/custom_sobel_synth_check/flow.status`

## 2. 工具、器件和源文件

- Tang Dynasty：`V6.2.168116`，可执行文件 `D:/TD/bin/td_commands_prompt.exe`；器件 `PH1P35MDG324`，Speed `-3`（`qa/custom_sobel_synth_check/td_20260922_135205.log:1-10`，`qa/custom_sobel_synth_check/settings.cfg`）。
- Icarus Verilog：`12.0 (devel)`，语言开关 `-g2005`（`sim/custom/sobel_iverilog_evidence.txt`）。
- 目标时钟：16.668 ns / 59.995 MHz。该值来自当前 lab_ex1 clean build 的 `MIPI_RX_BYTE_CLK`，不是历史 112.511 MHz 报告（`project/lab_ex1_mipi_hdmi_SC500_720P/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display_Runs/phy_1/final_timing.rpt:37,54`；QA 约束见 `qa/custom_sobel_synth_check/custom_sobel_synth_check.sdc`）。

独立综合源文件：

1. `rtl/custom/custom_rgb_to_gray.v`
2. `rtl/custom/custom_sobel_4px.v`
3. `qa/custom_sobel_synth_check/custom_sobel_synth_top.v`

`custom_sobel_synth_top.v` 只是综合可观察性 harness，把原生 200 个顶层 I/O 压缩到器件可映射的 156 个 I/O；testbench 不参与综合（`qa/custom_sobel_synth_check/custom_sobel_synth_top.v:1-36`）。

最终源码 SHA-256：

- `rtl/custom/custom_sobel_4px.v`：`24CF8E6578199C81E04A85C2158CD3EBF444F869398E836706BD83E3B460D7D8`
- `sim/custom/tb_custom_sobel_4px.v`：`AA5FB781CEC8F4367565CDA7FD37BEA80D300BB9CF4C8C6505B8D80D801E4516`
- `sim/custom/sobel_iverilog_evidence.txt`：`EA640A73AEBE9BD63C71FFE0C3022F1CDF3ED6D9155F9149854EAFED133D48FF`

## 3. 最小 ERAM 模板实验

### 3.1 官方模板依据

TD 的 HDL 编码指南给出的单口 RAM 模板是在同一个时钟过程内先执行同步读 `dout <= mem[addr]`，再条件写 `mem[addr] <= din`；同地址语义为 read-before-write。ERAM 推断要求同步读或寄存读地址，且单写端口深度至少 64（`D:/TD/doc/SWUG/SWUG106_HDL_Coding_Synthesis_User_Guide.pdf` PDF 第 90、92、95-96 页，印刷页 83、85、88-89）。本轮没有使用任何 Xilinx/Intel 属性，也没有使用 `ram_style` 强制属性。

### 3.2 单口同步读、同地址读写

工程：`qa/ram_template_check/`；模板：`ram_sync_read_first_320x32.v`。

- Icarus：`PASS: RAM template checks=5 errors=0 mode=READ_FIRST`，编译和运行退出状态均为 0（`qa/ram_template_check/ram_template_evidence.txt`）。
- opt_gate：LUT 0、REG 0、SLICE 0、DRAM LUT 0、ERAM20K **2**（`qa/ram_template_check/ram_template_check_gate.area`）。
- 门级网表把 320×32 拆成 20 位和 12 位两个 `PH1P_PHY_ERAM_V2`；每块工作几何为 1024×20，`WRITEMODE_A="READBEFOREWRITE"`（`qa/ram_template_check/ram_template_check_gate_netlist.v:1260-1368,1378-1486`）。
- 因而本实验对 PH1P35 实证确认：320×32 单口同步读可映射 ERAM，同地址写周期输出旧数据。

### 3.3 同步读、独立写地址

工程：`qa/ram_template_check/sdp/`；模板：`ram_sync_sdp_320x32.v`。

- Icarus：`PASS: SDP RAM template checks=6 errors=0 behavioral_collision=READ_FIRST`，编译和运行退出状态均为 0（`qa/ram_template_check/sdp/ram_sdp_evidence.txt`）。
- opt_gate：LUT 0、REG 0、SLICE 0、DRAM LUT 0、ERAM20K **1**（`qa/ram_template_check/sdp/ram_sdp_check_gate.area`）。
- 门级网表为一个 512×40 工作几何的 `PH1P_PHY_ERAM_V2`，端口模式均为 `NORMAL`（`qa/ram_template_check/sdp/ram_sdp_check_gate_netlist.v:134-243`）。
- 因硬件网表没有把双口碰撞标成 `READBEFOREWRITE`，改造后的 Sobel **不依赖该模板的同地址碰撞值**。合法连续流中 line2 在本拍读 group N、写上一流水拍的 group N-1；无效 AWB 行尾拍只完成上一拍写入而不发起读。

这里只确认了实际测试的 320×32 几何及上述物理拆分；没有足够资料宣称 PH1P 支持更广泛的任意宽度/深度组合。

## 4. Sobel 行缓存改造

原结构的八个 `320×8` 异步读数组已替换为两条 `320×32` 宽字缓存（`rtl/custom/custom_sobel_4px.v:28-34`）。四个 lane 按 `{gray0,gray1,gray2,gray3}` 打包，解包顺序保持 lane0 在最高字节（`rtl/custom/custom_sobel_4px.v:88-102`）。

- `line1_word`：同地址同步读/写，read-before-write；旧数据成为中间行，当前灰度写入该地址（`rtl/custom/custom_sobel_4px.v:164-170`）。
- `line2_word`：同步读当前输入地址，下一流水拍把 `line1_q` 写入上一拍地址（`rtl/custom/custom_sobel_4px.v:170-173`）。连续流的两个地址不同，因此不依赖双口同地址碰撞语义。
- TD elaboration 实际识别 2 个 RAM；最终门级映射为 3 个 ERAM20K：line1 的 20+12 位两个 1024×20 `READBEFOREWRITE` 块，以及 line2 的一个 512×40 双口块（`qa/custom_sobel_synth_check/td_20260922_135205.log:69-74`；`qa/custom_sobel_synth_check/custom_sobel_synth_check_gate_netlist.v:12293-12638`）。
- 灰度公式和 12 个乘法保持不变；TD 仍报告 `All the used dsp number is 12`（`qa/custom_sobel_synth_check/td_20260922_135205.log:296`）。

同步读增加了一个流水级。输入到输出的真实固定延迟由自检确定为 **2 拍**；`o_tdata/o_tvalid/o_tuser/o_tlast` 同时取自同一 `stage1`（`rtl/custom/custom_sobel_4px.v:186-212`）。原有一行/一像素空间偏移和边界清零条件保持不变（`rtl/custom/custom_sobel_4px.v:132-158`）。`tvalid=0,tlast=1` 仍通过 `stage1_last` 延迟两拍传播，同时不会发起 RAM 读写或更新有效数据历史（`rtl/custom/custom_sobel_4px.v:166-173,197-230`）。

## 5. 功能验证

重复运行命令：

```powershell
& .\sim\custom\run_sobel_iverilog.ps1
```

脚本保存完整版本、编译命令、运行输出和退出状态，并删除 `.tmp_sobel_iverilog`。最终结果：

```text
Default 1280x720 RTL compile exit status: 0
Compile exit status: 0
Run exit status: 0
PASS: sobel checks valid=173 marker=216 reset=4 hardcoded=7 errors=0
PASS: True
```

覆盖内容及依据：

- 全黑、全白、水平边缘、垂直边缘（`sim/custom/tb_custom_sobel_4px.v:7-10,53-66,268-273`）。
- 跨 4 像素组边界的单点脉冲 `x=8,y=3`（`:11,62,256-259,272`）。
- 非对称二维图案 `x+2y+xy`，硬编码检查点 `96'h606060686868707070787878`，用于同时检查 lane 顺序、行地址和跨拍窗口（`:12,63-64,260-262,273`）。
- 连续帧、每行连续有效拍、AWB `tvalid=0,tlast=1` 行尾、帧中异步复位及复位后恢复（`:168-183,268-296`）。
- 两级独立期望队列检查精确两拍延迟；每拍比较全部标记，有效拍比较数据，无效拍显式要求 `o_tdata=0`（`:148-164,198-220`）。

## 6. opt_gate 前后对比

执行命令：

```powershell
& .\qa\custom_sobel_synth_check\run_td_synthesis.ps1
```

流程为 `read_design -> opt_rtl -> opt_gate`，退出状态 0，`.opt_gate.end.f` 存在。优化前报告已保存到 `qa/custom_sobel_synth_check/baseline_before_eram/`。下表的资源统一采用 **`gate.area`** 口径：

| 项目 | 优化前 | 优化后 | 变化 |
|---|---:|---:|---:|
| LUT | 1,678 | 1,039 | -639 |
| REG | 102 | 155 | +53（新增同步读和标记流水线） |
| SLICE | 1,611 | 976 | -635 |
| DRAM LUT | 512 | **0** | -512 |
| ERAM20K | 0 | **3** | +3 |
| DSP | 12 | 12 | 0 |
| 最差数据路径 | 11.878 ns | 9.781 ns | -2.097 ns |
| SWNS | +4.726 ns | +6.823 ns | +2.097 ns |
| HWNS | +1.119 ns | +0.415 ns | -0.704 ns，仍为正 |
| 功能测试 | PASS，errors=0 | PASS，errors=0 | 新增非对称图案和无效拍数据检查 |
| 输入到输出延迟 | 1 拍 | **2 拍** | +1 拍 |

优化后最差 setup 路径为 `u_dut/ramread1_syn_11.clkb -> u_dut/o_tdata_reg[24].d`：ERAM clk-to-Q 后经过 Sobel 加法、绝对值/饱和相关组合逻辑，数据延迟 9.781 ns、10 个逻辑级（`qa/custom_sobel_synth_check/custom_sobel_synth_check_gate.timing:54-96`）。约束 16.668 ns 时综合级估算 SWNS +6.823 ns、HWNS +0.415 ns，Fmax 101.574 MHz；但 STA coverage 仅 63.09%，且没有执行 place/route，所以不得称为实现时序闭合（同文件 `:1-54`）。

`gate.qor` 的 LUT 数是另一统计口径：优化前 682，优化后 683；`gate.area` 的优化前 1,678 和优化后 1,039 是本报告固定使用的完整映射资源口径。**不得把 `gate.qor` 的 682/683 与 `gate.area` 的 1,678/1,039 直接比较。**（`qa/custom_sobel_synth_check/baseline_before_eram/gate.qor`；`qa/custom_sobel_synth_check/gate.qor`；两版 `custom_sobel_synth_check_gate.area`。）

## 7. 警告与完整性检查

- `SYN-5025 WARNING: Using 0 for all undriven pins and nets` 仍存在，工具日志不报告具体对象（`qa/custom_sobel_synth_check/td_20260922_135205.log:144`）。导出的 elaborated/RTL/gate 网表没有给出可唯一归因的未驱动对象。曾试验删除未使用的 Sobel 中心像素函数形参，警告仍存在，随后已撤回该试验。因此当前结论仍是：**SYN-5025 仍未定位，未 waiver**。
- `SYN-6021 CRITICAL-WARNING` 是 QA harness 的 156 个顶层端口没有 ADC；这会阻止该独立 QA 工程 bitgen，但本阶段有意只运行 opt_gate，不影响 RAM/资源对比（同日志 `:267`）。该工程不得用于下载。
- RTL area 为 `#LATCH 0`；最终日志没有 black box、RAM 无法推断、异步读 RAM、隐式 wire、位宽截断或未连接端口警告（`qa/custom_sobel_synth_check/custom_sobel_synth_check_rtl.area`；`td_20260922_135205.log`）。
- 当前目录不存在残留 `.vvp`、`work/`、`tmp/`、`VSOUT` 或 ModelSim 数据库；生成的 TD `.db`、网表、area/timing 和日志属于 QA 证据，不当作源文件。

最终证据 SHA-256：

- `td_20260922_135205.log`：`A2CF1A6A33F67354D6FA858F907601D99795F71A3CF78973DAD74DB36FC780C5`
- `custom_sobel_synth_check_gate.area`：`B8AD5EEB990BF4892FD2F09D87F8A98D77F3384137C6DD1F845238EFDF51E4A1`
- `custom_sobel_synth_check_gate.timing`：`E359EC5C71A9BE3DDC432F6E7877AC36B834255E299035A87AE27E3563D96549`

## 8. 集成准备判断

**可以进入 lab_ex1 集成准备阶段。** 依据是功能自检无错误、ERAM 推断已由真实 PH1P opt_gate 与门级原语参数双重确认、DRAM LUT 已归零、固定两拍延迟和全部标记对齐已验证。

进入实际集成前仍需完成但不属于本轮的工作：把两拍接口契约写入插点适配、在 lab_ex1 工作副本中做最小源文件接入、重新执行完整综合/place/route/最终时序，并继续定位 SYN-5025。只有完整工程结果才能判断系统资源余量和实现时序；本轮没有实际集成、下载或上板。
