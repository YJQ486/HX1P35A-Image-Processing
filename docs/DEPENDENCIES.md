# 依赖、许可与公开范围

`.gitattributes` 保留文件原始字节，避免 Git 自动换行转换使冻结源/测试哈希失效；发布前逐个比较 Git blob 与清单 SHA。

本轮检查了 vendor 下的许可/README 文件名及当前自研源头部。仅找到工具生成的 IP README，未找到明确授予厂商例程、生成 IP、加密 RTL、手册或衍生 bit 公开分发权的许可。这是“未找到许可”，不是法律上断言禁止一切使用；因此这些内容默认仅留本地，不另加开源许可证代替权利人授权。

公开内容限本项目自研模块、必要自检、项目自己编写的文档和不含源码的依赖清单。已有被跟踪的旧文件也纳入审查：当前版本移除过期报告、旧模块副本和历史日志；历史提交不改写。未发布厂商文件或复制其源码的补丁。公共仓库不是可独立构建完整镜像的厂商工程包。

`../release/dependencies.csv` 每行记录仓库相对路径、字节数、SHA256、公开/本地状态；`../release/active_sources.csv` 保留 .al 的全部 70 条记录、AutoExcluded 和编译顺序属性，不能把 70 条全称作活动 HDL。`../release/current.json` 指定唯一候选、入口与 bit。IP 的精确版本以 XML/IPC 哈希为准，不从目录名猜测版本。

获取方式：从安路比赛/开发板官方支持渠道取得 SC520CS Lab1、对应 PH1P35 IP 及手册；从芯片供应方取得 SC520CS-03 数据手册 V1.6 和应用指南 V1.4；从安路取得 Tang Dynasty 6.2.168116。不得以旧 SC500CS 工程替代。当前集成副本还含本地修订的顶层、ISP、AWB、复位/CDC 和相机控制接线，原始官方下载包不自动等于这些精确哈希。恢复完整本地工程须使用整理前快照或经授权取得精确集成文件，再运行 `python scripts/verify_current.py --local`；单靠下载原例程不能声称已复现当前 bit。

无工具安装包、许可证、密钥、缓存、Runs/DB、个人目录、原始翻拍视频或历史 bit 上传。选定 bit 只有 1,789,539 字节，尺寸不是阻碍；因包含厂商 IP 且授权不明，本次不放仓库或 Release。演示视频目前也无发布必要，只保留实物观察文字和来源记录。将来取得授权后可单独发布所需资产，不发布全部历史产物。

GitHub 当前规则：超过 50 MiB 警告，超过 100 MiB 拒绝普通 Git 文件。本次对最终上传清单逐文件检查，未靠 .gitignore 掩盖已跟踪文件。依据：[GitHub 大文件说明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。
