# 当前候选 QA（2026-10-16）

范围为 `release/current.json` 指定的完整帧 AWB 集成候选。本轮只整理、检查路径/哈希、公开文件验证和必要自检；没有修改任何正式/候选 RTL、厂商 IP、ADC、SDC 或 .al，没有重跑 TD 综合/布局布线，没有操作下载器或 Flash。

|项目|状态|证据与边界|
|---|---|---|
|仓库身份/默认分支|pass|origin为YJQ486/HX1P35A-Image-Processing；默认main；整理前HEAD f4b0fbfb7e668ac975dd944ae9be4a7282fef80e；fetch后无分叉|
|活动工程/依赖|pass|70条.al记录含6排除；全部路径存在；394项源/IP/脚本/证据哈希匹配；56个显式活动Verilog模块无重名|
|旧仿真与当前源绑定|pass|原verify_test_source_bindings.py：8组105项；CSA穷举证书与当前灰度字节一致；freeze_diag_sources.py匹配syn_6输入|
|本轮当前源回归|pass|7组；小帧AWB7987、完整720行AWB8755237、按键18、状态CDC206、AE控制418、AE统计9项检查均errors=0；四模式1280宽6行19201有效拍、19262标记检查errors=0|
|公开独立导出|pass|无vendor/project/旧QA的目录中，公开19项源哈希及6组基础回归通过；--local按预期报375项未包含依赖，不冒充完整工程|
|综合/布局布线/bit|pass（历史工具范围）|syn_6 → run_route_11_gray_csa → final精确查询 → checked bitgen；本轮输入SHA与原生清单一致，bit来源/大小/SHA复核；本轮未重建|
|时序/CDC已建模路径|pass（限定）|SWNS +0.103 / HWNS +0.020 ns，STNS/HTNS0，覆盖98.75%；gray36条7.2ns Active最小+6.097ns；AE176位8ns+7.112ns；面板177位12ns+11.127ns|
|完整物理/外部时序签核|not tested|4类dummy、36输入无delay、64输出无delay、1部分输入；PLL lock/hardPHY/DDR/MTBF/外部电气边界未完成|
|C实物对照|pass（用户观察）|C已上板，与A接近可能略好；加载SHA未独立核验，见BOARD_VALIDATION|
|偏色修复|fail|用户明确仍未解决|
|全部模式/OSD/反复切换板测|not tested（完整验收）|本轮无逐项实物证明|
|长期稳定/Flash冷启动/最终签核|not tested|不计算竞赛已通过条目数；本轮不进行硬件操作|

综合资源为syn_6 gate.area口径：LUT18946、REG17569、SLICE15365、DRAM LUT296、ERAM20K42、DSP16；这是综合估算，不与route资源混为一谈。告警保留SYN-5013×789、SYN-5025×3、加密MC latch HDL-5369×1、SYN-5065×1及PHY局部时钟/路由相关告警；新模块名过滤告警0不能抹掉全工程告警。精简原始审计摘录和哈希见 `release/historical_audit_excerpt.txt`；完整日志/失败TimingHigh访问冲突及未过时序试验留在本地QA。

历史测试清单见 `release/historical_test_summary.csv`（19组，包含独立负例）。完整原厂divider门级仅短帧，720行原AWB使用经门级比较的非恒定算术模型；新完整帧AWB除法是实际RTL。接线层测试中部分AWB/PLL被注入，不能称整个加密ISP完整门级720行证明。no-gap FIFO历史反例与异常帧不保证无损恢复的边界继续保留，未由本轮目录整理宣称消除。

本轮仿真最初在沙盒内compiler退出3221225477，失败证据保留；获准本机执行后7组通过。公开 `release/validation.json` 记录本轮通过结果、源哈希、历史绑定复核和独立导出结论；本地完整原始输出在 `build/current_tests/20261016_233744/` 和 `exports/public_current_20261016/build/current_tests/20261016_234152/`。本轮测试绑定当前候选qa/rtl，未误用根目录旧rtl。

恢复位置、待保留4个暂存文件与移除清单见 CLEANUP_AND_RECOVERY。任何新构建必须重新运行与新网表相匹配的证明，不能把本次源绑定检查当作未来任意构建签核。
