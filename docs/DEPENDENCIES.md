# 依赖与公开范围

## 仓库内容

公开仓库包含自研 RTL、必要测试平台、检查脚本、项目文档及依赖清单。完整集成工程还使用厂商例程、生成 IP、加密 RTL 和本地修订的厂商文件，这些内容目前仅保留在本地。

对本地厂商材料的许可文件、README 及相关源文件头部检查后，尚未找到明确覆盖上述文件、手册或衍生 bit 的公开分发授权。因此，仓库暂不提供这些材料、包含厂商源码的补丁或完整编程镜像。该处理依据是当前掌握的许可资料，后续取得授权后可调整发布范围。

工具安装包、许可证、密钥、缓存、Runs 数据库和个人目录配置不属于仓库发布内容。旧候选、原始视频、完整日志及历史 bit 保留在本地归档中。

## 依赖清单

|文件|用途|
|---|---|
|[current.json](../release/current.json)|当前候选、工程入口、构建来源和 bit 信息|
|[active_sources.csv](../release/active_sources.csv)|工程全部 70 条记录，含 AutoExcluded 和编译顺序属性|
|[dependencies.csv](../release/dependencies.csv)|仓库相对路径、文件大小、SHA256 及公开状态|

70 条工程记录中包含 6 条自动排除项，并非全部参与 HDL 编译。IP 的精确配置由 XML/IPC 文件哈希标识。

公开文件通过 `.gitattributes` 保留原始字节，避免自动换行转换影响源文件哈希。发布检查已逐项比较 Git blob 与工作区文件。

## 获取与恢复

从安路比赛或开发板官方支持渠道获取 SC520CS Lab1、PH1P35 配套 IP、板级资料及 Tang Dynasty 6.2.168116；摄像头资料包括 SC520CS-03 数据手册 V1.6 和应用指南 V1.4，可向供应方获取。

当前集成版本包含本地修订的顶层、ISP、AWB、复位与 CDC 逻辑及相机控制接线。官方原始例程与当前集成文件的哈希并不必然一致，旧 SC500CS 工程也不能替代该版本。恢复现有成果时，应使用整理前快照，或经授权取得清单对应的精确文件，然后执行：

```powershell
python scripts/verify_current.py --local
```

仅取得官方原始例程不足以复现当前 bit。完整构建的依赖和脚本限制见[构建说明](CURRENT_BUILD.md)。

## 二进制与视频

当前选定 bit 为 1,789,539 字节。由于厂商 IP 的分发授权尚未明确，该文件未放入仓库或 Release，仓库仅保留来源、大小及 SHA。演示视频目前保留本地原件及观察记录。

2026-10-16 发布检查覆盖了最终文件清单和原有已跟踪文件，未包含超限文件。GitHub 对超过 50 MiB 的普通 Git 文件发出警告，超过 100 MiB 则拒绝接收，参见 [GitHub 大文件说明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。
