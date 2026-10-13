---
epic: ../epics/equuleus-resukisu-build.md
phase: executing
approved_revision: 73EE6779371B10E51EF1349BD6043C4B546B391F89000188BB2A0922C7526386
current_item: ITEM-2
next_action: 创建推荐 fork，建立 `codestable/equuleus-resukisu-build` 分支，自动 push workflow 并运行 ITEM-2 Actions；完成日志与产物验收后进入 ITEM-3。
blocked_by: none
item_progression: per-item
milestone_commit: authorized
remote_publish: each-milestone
---
## 子项进度
- [x] ITEM-1
- [ ] ITEM-2
- [ ] ITEM-3

## 临时决策与证据
- Hook 决策：owner 已批准本次修订采用 `KSU_MANUAL_HOOK=y`，不启用 `KSU_SUSFS`，因此不提供 SUSFS Inline Hook；批准的 Epic SHA-256 为 `73EE6779371B10E51EF1349BD6043C4B546B391F89000188BB2A0922C7526386`。
- GitHub 目标：`https://github.com/GuLingguang/xiaomi-sdm845-kernel-pro` 的 `lineage-22.2` 仅是只读参考基线（非发布目标）；发布目标为 `https://github.com/napstablook666/xiaomi-sdm845-kernel-pro` 的 `codestable/equuleus-resukisu-build`，owner 已授权自动 push 和运行 Actions。
- 执行策略已按 owner 最新授权记录为 `item_progression: per-item`、`milestone_commit: authorized`（本地里程碑自动 commit）、`remote_publish: each-milestone`（自动 push 并运行 Actions）；永久刷写仍需 DEC-4 单独批准。
- ITEM-1 已完成：workflow 保持固定 baseline checkout 只读，在自身编排中合并 Manual Hook Kconfig fragment、编译并打包；已修正 Kconfig 互斥断言、未压缩 `Image` 验证和 `Image.gz-dtb` 产物校验，并用 `exec > >(tee build.log) 2>&1` 产出构建日志。
- 最终静态验证（未压缩 `Image` 验收修正及来源 metadata/仓库区分校验修改后）通过：`actionlint v1.7.7`、Prettier、抽取全部 workflow `run` 块后的 `bash -n`；未运行 Actions。
- 永久 Epic 已按 owner 确认同步为 `status: active`、DEC-1 已批准、DEC-2 远端目标已确定；新的已批准 SHA-256 为 `73EE6779371B10E51EF1349BD6043C4B546B391F89000188BB2A0922C7526386`。
- 工具链候选输入：`clang-18=1:18.1.3-1ubuntu1`、`llvm-18=1:18.1.3-1ubuntu1`、`lld-18=1:18.1.3-1ubuntu1`、`gcc-aarch64-linux-gnu=4:13.2.0-7ubuntu1`、`binutils-aarch64-linux-gnu=2.42-4ubuntu2.10`、`gcc-arm-linux-gnueabihf=4:13.2.0-7ubuntu1`、`binutils-arm-linux-gnueabihf=2.42-4ubuntu2.10`，以及显式构建工具包的完整版本；Snapshot ID 为 `20261013T000000Z`。
- 来源冲突复核：对同一 Snapshot 的原始 `Packages.xz` 重新查验，`clang-18`、`llvm-18`、`lld-18` 的 `1:18.1.3-1ubuntu1` 仅存在于 `noble-updates/universe`，`noble/universe` 没有这些精确版本；三者的 `Filename` 均为对应 `llvm-toolchain-18` amd64 包。main/universe 限定闭包为 `247` 个包、`754` 条依赖边，无未解析项，来源计数为 `noble/main=72`、`noble-updates/main=52`、`noble-security/main=106`、`noble/universe=5`、`noble-updates/universe=10`、`noble-security/universe=2`。
- 本地工作树没有 `build_for_equuleus.sh`；该脚本已确认存在于固定 baseline commit，ITEM-1 必须以 checkout 后的内核仓库工作目录为执行上下文。
- Lineage Recovery 22.2 对 AnyKernel3 的支持未确认；若不支持，计划要求使用匹配 LineageOS boot ramdisk 重打包并优先临时启动。
- stock boot 哈希 `08CE8935501BBDD5468BD40EDF4367C8F2A5BAD10BCF9229C74069638AABA4CF` 仅标识当前本地文件，未证明与后续刷写系统及分区匹配。
- Manager 的 UAPI 5 兼容版本/官方产物待核实；不以其他 Manager 的安装状态替代验收。
- 原设计复核目标 SHA-256 `D0247D0AF42116173A2C1B61FB19F4FA5E7B4D4951B59AC9C46C3C2EBC2849E6`；当前已批准修订 SHA-256 为 `73EE6779371B10E51EF1349BD6043C4B546B391F89000188BB2A0922C7526386`，`approved_revision` 已写入该精确值。
- Epic: `../epics/equuleus-resukisu-build.md`。本地目录无 commit/remote；未运行 Actions、未推送、未刷写。
