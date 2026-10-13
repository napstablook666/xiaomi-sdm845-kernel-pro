---
epic: ../epics/equuleus-resukisu-build.md
phase: executing
approved_revision: 9F09236E15F8F5847104E486CCC53F0DF2B62092B31610F269175BEDD2330390
current_item: ITEM-3
next_action: 设备连接后按 DEC-3 复核当前 product/slot/bootloader，实测 Lineage Recovery 安装或匹配 boot ramdisk 的 `fastboot boot` 临时启动，再验收 UAPI 5 Manager、Root 与硬件；永久刷写前仍需 DEC-4。
blocked_by: device_not_connected; recovery_install_unverified; temporary_boot_unverified; manager_root_hardware_unverified
item_progression: automatic
milestone_commit: authorized
remote_publish: each-milestone
---
## 子项进度
- [x] ITEM-1
- [x] ITEM-2
- [ ] ITEM-3

## 临时决策与证据
- Hook 决策：owner 已批准本次修订采用 `KSU_MANUAL_HOOK=y`，不启用互斥顶层 `KSU_SUSFS`，因此不提供 SUSFS Inline Hook；固定 ReSukiSU `kernel/Kconfig` 的 SUSFS 菜单及其子项依赖该顶层选项，adapter/workflow 拒绝最终 `.config` 中任一 `CONFIG_KSU_SUSFS*` family 符号为 `y`；批准的 Epic SHA-256 为 `9F09236E15F8F5847104E486CCC53F0DF2B62092B31610F269175BEDD2330390`。
- GitHub 目标：`https://github.com/GuLingguang/xiaomi-sdm845-kernel-pro` 的 `lineage-22.2` 仅是只读参考基线（非发布目标）；发布目标为 `https://github.com/napstablook666/xiaomi-sdm845-kernel-pro` 的 `codestable/equuleus-resukisu-build`，owner 已授权自动 push 和运行 Actions。
- 执行策略已按 owner 最新授权记录为 `item_progression: automatic`、`milestone_commit: authorized`（本地里程碑自动 commit）、`remote_publish: each-milestone`（自动 push 并运行 Actions）；ITEM-1 完成后自动连续推进 ITEM-2/ITEM-3，永久刷写仍需 DEC-4 单独批准。
- ITEM-1 已完成：workflow 只负责依赖、固定 baseline/source checkout、参数和验收；版本化 `ci/build-equuleus-resukisu.sh` 负责 KSU fragment 合并、兼容补丁、固定并行度下的配置/编译和 `zip -FS` 打包。workflow 另行校验 Kconfig 互斥选择、未压缩 `Image`、`Image.gz-dtb` 及 metadata，并用 `exec > >(tee build.log) 2>&1` 产出构建日志。
- 最终静态验证（未压缩 `Image` 验收修正及来源 metadata/仓库区分校验修改后）通过：`actionlint v1.7.7`、Prettier、抽取全部 workflow `run` 块后的 `bash -n`；静态验证当时尚未运行 Actions。
- 永久 Epic 已按 owner 确认同步为 `status: active`、DEC-1 已批准、DEC-2 远端目标已确定；新的已批准 SHA-256 为 `9F09236E15F8F5847104E486CCC53F0DF2B62092B31610F269175BEDD2330390`。
- 工具链候选输入：`clang-18=1:18.1.3-1ubuntu1`、`llvm-18=1:18.1.3-1ubuntu1`、`lld-18=1:18.1.3-1ubuntu1`、`gcc-aarch64-linux-gnu=4:13.2.0-7ubuntu1`、`binutils-aarch64-linux-gnu=2.42-4ubuntu2.10`、`gcc-arm-linux-gnueabihf=4:13.2.0-7ubuntu1`、`binutils-arm-linux-gnueabihf=2.42-4ubuntu2.10`、`patch=2.7.6-7build3`，以及显式构建工具包的完整版本；Snapshot ID 为 `20261013T000000Z`。
- 来源冲突复核：对同一 Snapshot 的原始 `Packages.xz` 重新查验，`clang-18`、`llvm-18`、`lld-18` 的 `1:18.1.3-1ubuntu1` 仅存在于 `noble-updates/universe`，`noble/universe` 没有这些精确版本；三者的 `Filename` 均为对应 `llvm-toolchain-18` amd64 包。main/universe 限定闭包为 `248` 个包、`755` 条依赖边，无未解析项，来源计数为 `noble/main=73`、`noble-updates/main=52`、`noble-security/main=106`、`noble/universe=5`、`noble-updates/universe=10`、`noble-security/universe=2`。
- 本地工作树没有 `build_for_equuleus.sh`；该脚本已确认存在于固定 baseline commit，ITEM-1 必须以 checkout 后的内核仓库工作目录为执行上下文。
- Lineage Recovery 22.2 对 AnyKernel3 的支持未确认；若不支持，计划要求使用匹配 LineageOS boot ramdisk 重打包并优先临时启动。
- stock boot 哈希 `08CE8935501BBDD5468BD40EDF4367C8F2A5BAD10BCF9229C74069638AABA4CF` 仅标识当前本地文件，未证明与后续刷写系统及分区匹配。
- Manager 的 UAPI 5 兼容版本/官方产物待核实；不以其他 Manager 的安装状态替代验收。
- 原设计复核目标 SHA-256 `D0247D0AF42116173A2C1B61FB19F4FA5E7B4D4951B59AC9C46C3C2EBC2849E6`；当前已批准修订 SHA-256 为 `9F09236E15F8F5847104E486CCC53F0DF2B62092B31610F269175BEDD2330390`，`approved_revision` 已写入该精确值。
- ITEM-2 首轮 run `38393628663` 在 `Build kernel and package AnyKernel3` 因 `fs/namei.c:3801:26: error: use of undeclared identifier 'tmp'` 失败；修复提交已从远端 `1b2782e902184639b2aade66a8433b4b806fea8a` 为父移植为 `e684bca9f8e954aa61f2f845fb67ba558110565a`，随后以其为父加入 artifact 隐藏文件修复提交 `cd5b314c1b601d7f142569edd21ea433dbc92cdb`。
- ITEM-2 已通过：run `38404743286`（head `cd5b314c1b601d7f142569edd21ea433dbc92cdb`）成功完成固定 Snapshot APT、UAPI 5 checkout、编译和 artifact 验收；`.config` 存在且为 `CONFIG_KSU=y`、`CONFIG_KSU_MANUAL_HOOK=y`，无任何 `CONFIG_KSU_SUSFS*` 为 `y`；`Image.gz-dtb` 与 ZIP 内镜像一致。metadata 记录 adapter SHA-256 `4751014f1298490c6aa22be5c6710fb2a13d81b37eccf3f06a0fefbebc25d405`、baseline build script SHA-256 `bbf526b2cdd04d74c10699aefe4d9e6541749ee5df988ff7bd59c0b673c188a7`、`patch=2.7.6-7build3` 和 Snapshot `20261013T000000Z`；artifact `build-metadata.txt` 末尾的 `sha256sum` 摘要加路径两行与下载的 Image/ZIP 实际计算结果逐一相等：镜像 SHA-256 `07c1bc0e519f8a38cc7bd47c80f9db377a88e7bb85703751f00ddb719adfa3fc`，ZIP SHA-256 `17eed4af2c2d3326587ec7bf21d9620037637229babf13586123a7951124e1d4`。未刷写。
- ITEM-3 离线交付：run `38404743286` 的原始下载文件位于 `AnyKernel3/ak3-equuleus.zip`、`out/arch/arm64/boot/Image.gz-dtb` 和 `out/.config`；已复制到稳定目录 `D:/AI/小米8ud/equuleus-resukisu-run-38404743286/` 根部，并保留 `build-metadata.txt`、`build.log` 和 `artifact-manifest.sha256`。在该目录执行 `sha256sum -c artifact-manifest.sha256` 全部通过；GNU `sha256sum .config` 的标准记录为 `*` 二进制标记加文件名 `.config`（文本显示为 `*.config`），校验输出为 `.config: OK`；根部 ZIP SHA-256 为 `17eed4af2c2d3326587ec7bf21d9620037637229babf13586123a7951124e1d4`，未纳入普通代码提交。
- 记录发布历史：目标分支曾从 `c82b21d0e7e03ca31a78f92925f4bc84348187b3` 快进至 `ef7f4b655e57b845de34a9f8b30468de1b8cfd01`；已核对该提交的父提交、Epic blob `7cbf9a59a5cb182bd3836f5fa1e907acf6432a2d`、work blob `79257a39edc4bce498d73dae43b6a781d538f95f`、workflow blob `fd02b39fcba83a450bae23e261105a1355609603` 和 adapter blob `9029ea1b45c87996a96889353e82cba4c279719c`。
- ITEM-3 离线包审查：`anykernel.sh` 声明设备 `equuleus`、`do.devicecheck=1`、`is_slot_device=0` 并写入 `/boot`；`adb devices -l` 与 `fastboot devices` 当前均无设备，尚未证明 Lineage Recovery 可安装、`fastboot boot` 可临时启动、UAPI 5 Manager/Root 或硬件功能，未刷写。
