# 整理与本地恢复

整理前主分支 HEAD：`f4b0fbfb7e668ac975dd944ae9be4a7282fef80e`。远端身份为 `https://github.com/YJQ486/HX1P35A-Image-Processing.git`，默认分支 main。只提交并推送 main，不推本地备份分支/标签，不强推或改写历史，不新建仓库。

完整备份相对仓库根目录在 `qa/_local_backups/pre_cleanup_20261016/`，含未跟踪/被忽略文件、厂商原件、QA数据库、失败证据、原始 `.git` 快照；`backup_manifest.jsonl` 对源与目标分别计算 SHA256 比较，`COMPLETE.json` 是完成标记。`repository.bundle` 另保留 Git 完整历史并已通过 bundle verify。本轮生成的公开文档、导出和新仿真结果是备份启动后的新增产物，保存在当前工作区，不属于整理前快照。

Git 备份分支 `codex/backup-pre-cleanup-20261016` 和标签 `backup-pre-cleanup-20261016` 均指向 `9cf21e4c70f165492f0b120f835348c979ce1f2a`。该快照通过 stash create 建立，包含已跟踪工作区和原index快照，没有stash/reset工作区；未跟踪文件由独立文件备份保证。备份仅本地保留，未上传潜在受限材料。

原4个暂存文件：

- `docs/SC520CS_LINK_SIM_REPORT.md`
- `sim/custom/run_sc520cs_link_iverilog.ps1`
- `sim/custom/sc520cs_link_iverilog_evidence.txt`
- `sim/custom/tb_sc520cs_processing_link.v`

它们由 `index.before`、`staged.patch`、`staged.entries.txt`、`staged_worktree/` 和Git快照独立保留。本次提交使用单独index，只包含公开清单，以上4项不会混入。提交后将其原blob、mode和stage恢复到新HEAD之上的待暂存状态；因此最终 `git status` 显示这4项新增是有意保留，不能据此断言整理提交不完整。

过时根目录 TD 日志、旧报告移至 `qa/_local_archive/pre_cleanup_20261016/`；替换前的README、ignore、分析和QA文档另存 replaced/。旧候选、完整日志、失败运行、原bit/视频以及root旧rtl/sim依赖均留原本地路径，避免破坏旧工程引用。当前公开树退出的历史跟踪文件逐项列在 `release/retired_paths.csv`，每项有原SHA和本地保留位置；这份清单与Git删除清单交叉核对。未删除独一成果或本地QA证据。

恢复应先在新目录审阅：从 `snapshot/` 恢复完整整理前文件树；或从 bundle 克隆 Git，再在原HEAD干净工作区执行 `git stash apply --index backup-pre-cleanup-20261016` 恢复已跟踪和暂存状态，并从文件快照补回未跟踪/忽略内容。不要在当前成果上直接覆盖 `.git` 或反向应用patch。工程部分工具脚本硬编码原工作机工具路径，迁移到新目录仍需按依赖说明核对路径，不能宣称任意目录即开即建。

许可、尺寸和敏感内容检查覆盖最终完整公开文件清单及原已跟踪文件。仓库保留历史提交，因此历史报告仍可从旧commit找到；本轮只清理当前版本，不改写过去。完整本地备份含原路径/可能的机内配置，应作为本机恢复材料保管，不能整包上传。
