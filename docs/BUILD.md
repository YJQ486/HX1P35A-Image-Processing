# 构建说明

仓库中的自研 RTL 和测试平台可以单独仿真。完整 bitstream 还需要厂商例程、IP 和修改过的顶层文件，这些材料未公开，只能在具备相同材料的环境中复现。

## 仿真

需要 Icarus Verilog 12 和 Python 3：

```bash
python scripts/run_tests.py
```

脚本用 `iverilog -g2005` 把 `tb/` 下每个测试平台与 `hdl/*.v` 一起编译运行，输出和中间文件放在 `build/sim/`。必须使用 Verilog-2005 模式：`custom_ae_frame_stats.v` 用 `sequence` 作信号名，而它在 SystemVerilog 中是关键字。只运行名称包含某段文字的测试：

```bash
python scripts/run_tests.py processing
```

各测试的内容和结果见 [验证报告](VERIFICATION.md#模块仿真)。

## 完整工程的依赖

|材料|来源|说明|
|---|---|---|
|Tang Dynasty 6.2.168116|安路官方|其他版本可能得到不同的布局布线结果|
|SC520CS Lab1 例程（`lab_ex1_mipi_hdmi`）|安路比赛资料|MIPI D-PHY、CSI 解包、去马赛克、DDR2 控制器、HDMI 发送器、PLL、FIFO 等|
|lab_ex3 OSD 例程中的 `anlogic_logo_rom.v`|安路比赛资料|生成 Logo ROM 数据|
|修改过的厂商派生文件|本地|见 [系统设计](ARCHITECTURE.md#厂商派生文件中的修改)|

仅有官方原始例程不足以复现最终 bitstream。[release/final.json](../release/final.json) 列出构建时全部 77 个输入文件的路径和 SHA-256，可以逐个核对恢复后的文件。

## 恢复工程

1. 以 SC520CS Lab1 例程为基础，换入本地修改过的厂商派生文件，并核对 SHA-256。
2. 把 `hdl/*.v` 复制到工程的 `rtl/custom/` 并加入工程，文件清单与 `release/final.json` 一致。
3. 生成 Logo ROM 数据，并放到 `custom_logo_overlay.v` 所在目录：

   ```bash
   python scripts/make_logo_rom.py <lab_ex3_osd 路径>/user_source/hdl_source/anlogic_logo_rom.v
   ```

   脚本输出 `hdl/custom_logo_rom.hex`，并检查其 SHA-256 是否与最终构建所用文件相同（`FCD45773…`）。`custom_logo_rom` 通过 `$readmemh("custom_logo_rom.hex")` 读取该文件，TD 按源文件所在目录解析这个相对路径。

4. 器件选 PH1P35MDG324、Speed -3，顶层为 `design_top_wrapper`，约束文件为 `camera_to_dsi_display.sdc` 和 `pin.adc`。

## 构建流程

最终版本使用命令行流程，综合、布局、布线各运行一次，不重复尝试种子或策略：

1. **综合。** 检查 `custom_logo_rom` 的日志：应出现 `extracting RAM for identifier 'S_mem'` 和 `readmemh: reading from file 'custom_logo_rom.hex'`，资源报告中 Logo 模块应约占 19 块 ERAM。如果 Logo 仍占约 1800 个 LUT，说明 hex 文件没有找到，或者 ROM 没有推断为 ERAM。
2. **布局、布线。** Slice 占用约 87%，正常情况下 route 在 4～6 分钟内完成。Slice 超过 95% 时，route 可能长时间不收敛，见 [开发记录](HISTORY.md#资源与布线)。
3. **时序。** setup 和 hold 的 WNS 都应不小于 0，TNS 为 0；36 条格雷码跨时钟路径的最大延迟预算为 7.2 ns。
4. **生成 bit。** 下载到 SRAM 测试；确认无误后，再手动写入 Flash，并断电测试冷启动。

各次构建还运行了本地审计脚本，检查 CDC 映射、复位、I²C 时钟和装箱 LUT 的真值表。这些脚本解析含厂商代码的网表，未公开，结果见 [验证报告](VERIFICATION.md#构建与时序)。
