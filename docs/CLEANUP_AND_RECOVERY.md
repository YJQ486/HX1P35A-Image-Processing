# 归档与恢复说明

## 整理记录

2026-10-16，仓库完成当前成果整理，首次整理提交为 `b07f8327bce3a52cbe2ed9b3ba0eff6be9c60a65`。仓库为 [YJQ486/HX1P35A-Image-Processing](https://github.com/YJQ486/HX1P35A-Image-Processing)，默认分支 `main`。

整理前主分支 HEAD 为 `f4b0fbfb7e668ac975dd944ae9be4a7282fef80e`。整理采用普通提交和推送，保留原 Git 历史；备份分支与标签仅保存在本地。

## 完整文件备份

备份位于仓库根目录下的：

```text
qa/_local_backups/pre_cleanup_20261016/
```

共 46,979 个文件、43,189,259,587 字节，包含未跟踪及被忽略文件、厂商原件、QA 数据库、失败证据和整理前 `.git` 快照。

|文件 / 目录|用途|
|---|---|
|`snapshot/`|整理前完整文件树|
|`backup_manifest.jsonl`|逐文件大小与 SHA256；源文件和备份已分别计算并比对|
|`COMPLETE.json`|备份完成记录|
|`repository.bundle`|独立 Git 历史备份，已通过 bundle verify|
|`index.before`、`staged.patch`、`staged.entries.txt`、`staged_worktree/`|原暂存区及对应工作区文件|

备份启动后新增的公开文档、导出与回归结果保存在现工作区，未计入整理前快照。

## Git 快照与暂存区

本地分支 `codex/backup-pre-cleanup-20261016` 和标签 `backup-pre-cleanup-20261016` 均指向：

```text
9cf21e4c70f165492f0b120f835348c979ce1f2a
```

该快照通过 `git stash create` 保存已跟踪文件及原暂存区，创建过程未清空工作区。未跟踪和忽略文件由完整文件备份保存。

整理前已有的以下 4 个暂存文件未纳入整理提交：

- `docs/SC520CS_LINK_SIM_REPORT.md`
- `sim/custom/run_sc520cs_link_iverilog.ps1`
- `sim/custom/sc520cs_link_iverilog_evidence.txt`
- `sim/custom/tb_sc520cs_processing_link.v`

整理提交使用独立 Git 索引。提交后，上述文件按原 blob、mode 和 stage 恢复到新 HEAD 之上的暂存区，工作区内容也已核对。因此，整理完成后的状态仍显示这 4 项新增。

## 本地归档

旧报告和根目录 TD 日志移至 `qa/_local_archive/pre_cleanup_20261016/`，被替换的 README、忽略规则、工程分析和 QA 文档保存在其中的 `replaced/`。

旧候选、完整日志、失败运行、历史 bit 和视频，以及旧 `rtl/`、`sim/` 依赖保留原本地路径，以维持既有工程引用。从当前公开版本移除的 26 个历史路径记录在 [retired_paths.csv](../release/retired_paths.csv)，每项包含原 SHA 和本地保留位置，已与 Git 路径移除清单核对。

## 恢复方法

建议先在新目录检查恢复结果。可直接从 `snapshot/` 恢复整理前文件树；也可从 bundle 克隆仓库，在整理前 HEAD 的干净工作区执行：

```powershell
git stash apply --index backup-pre-cleanup-20261016
```

该命令恢复已跟踪文件及暂存状态，未跟踪或忽略内容仍需从文件快照补回。恢复时应保留现有工作区，避免直接覆盖当前 `.git`。

部分历史脚本使用原工作机工具路径；迁移到其他位置后，仍需按[依赖说明](DEPENDENCIES.md)核对路径和哈希。完整备份包含机内路径、配置及受限厂商材料，仅作为本地恢复资料保存。
