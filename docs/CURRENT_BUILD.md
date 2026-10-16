# 当前工程的检查、构建和手动板测

唯一集成工程为 `qa/sc520cs_frame_awb_trial_20261016/lab_ex1_mipi_hdmi/td_project/camera_to_dsi_display.al`，top `design_top_wrapper`，PH1P35MDG324、Speed -3、TD 6.2.168116。`project/` 是旧 SC500CS 基线；其他 qa 候选是前驱或试验，均不是当前入口。原相对路径保持不变。

先在仓库根目录执行（Python 3.11+）：

```powershell
python scripts/verify_current.py
python scripts/verify_current.py --local
python scripts/test_current.py --iverilog-bin D:/iverilog/bin --full
```

第一项只检查公开源；第二项要求本地完整依赖和 bit，克隆公开仓库后缺少受限依赖应明确失败；第三项跑当前候选自研源的小帧/完整帧 AWB、按键、状态 CDC、室内 AE 和四模式自检。工具路径可用 IVERILOG_BIN/PATH 或命令行指定。输出放 `build/current_tests/时间戳/`，不覆盖旧证据；本轮还在不含旧工程的导出目录运行公开检查，结果见 QA 报告。

当前 bit 的已完成历史链是 syn_6 → run_route_11_gray_csa → final 精确查询 → run_bitgen_frame_awb_checked。原始命令、脚本和日志全部留在本地候选目录，其哈希在依赖清单。以下是重建步骤，**本轮仅整理和检查，没有再执行 TD 构建**。先恢复受限依赖；每次使用未存在的 syn_N/route/查询前缀/bitgen 名称，不覆盖原结果：

```powershell
$q='qa/sc520cs_frame_awb_trial_20261016'
& "$q/run_opt_gate.ps1" -RunName syn_20
& "$q/run_implement.ps1" -RunName run_route_rebuild_20 -SynRun syn_20
& "$q/run_current_audit.ps1" -Route run_route_rebuild_20 -Prefix rebuild_20
```

综合脚本还依赖保留在 qa 前驱目录中的 `sc520cs_ddr_100mhz_diff_trial/run_internal_pll_opt_gate.ps1`。物理脚本显式 clear/read QA 时钟、DDR、I2C、AE、FIFO SDC；不能只在 GUI 打开 .al 后点击默认 Build 当作原链复现。pin.adc 及默认工程 SDC 和 IP 配置在源清单，精确查询脚本追踪当前 packed 名称。新网表可能改变名称；保护断言失败必须重新证明，不能改字符串绕过或把旧例外套入新网表。

重建 bit 前还要重新冻结综合清单、测试源绑定、STA/CDC 证据和发布输入清单。历史 `freeze_diag_sources.py` 固定 syn_6；`run_closed_ae_bitgen.ps1` 同时校验冻结输入、旧候选和原四个暂存路径，其默认参数指向历史前驱，**不能无参数调用，也不能直接作为新网表自动发布器**。它们的历史命令为：

```powershell
& "$q/run_closed_ae_bitgen.ps1" -RouteName run_route_11_gray_csa -AuditPrefix final -BitgenRun run_bitgen_frame_awb_checked
```

上述历史输出已存在，脚本应拒绝覆盖。若需要完整再构建，应在独立 QA 发布副本中更新证明绑定并验证；本轮没有建立或声称验证这样的新构建入口。`release/current.json` 和 `scripts/verify_current.py --local` 是本轮可执行的当前状态检查入口，不替代 TD 构建。

手动上板仅供后续获准操作：核对板型/相机/线序、bit 大小和 SHA，再按官方流程受控加载 SRAM。短按依次彩色/灰度/二值/Sobel；约 1 秒长按依次 A 原 AWB / B 单位增益 / C 完整帧 AWB，释放不附带短按。固定室内照明拍摄 A/B/C/A、灰卡及彩色物体，等待至少 20 帧后比较；记录曝光、实际分支、增益、异常/丢帧和重启条件。已有用户 C 观察见 BOARD_VALIDATION；本轮未操作下载器或 Flash。Flash 断电启动和长期稳定性均待单独测试。
