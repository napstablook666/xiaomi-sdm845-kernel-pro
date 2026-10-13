---
epic: ../epics/equuleus-resukisu-build.md
phase: executing
approved_revision: 9F09236E15F8F5847104E486CCC53F0DF2B62092B31610F269175BEDD2330390
current_item: ITEM-3
next_action: DEC-4 明确批准后将已验收镜像写入 `/boot`，重启复验 Manager Root 与回滚路径；Recovery 安装仍未验证，第三方 App 首次 `su` 授权仍需在 Manager 内确认。
blocked_by: recovery_install_unverified; third_party_root_client_unverified; hardware_interactive_unverified; fingerprint_service_baseline_failure; permanent_flash_dec4
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
- ITEM-3 设备验证：ADB 识别 `c967753e`，product/device 均为 `equuleus`；bootloader `unlocked: yes`、A-only、boot 分区 64 MiB，`ro.boot.verifiedbootstate=orange`。从实机只读备份原 `/dev/block/by-name/boot` 为 `boot-equuleus-device-preflash.img`，SHA-256 `ff25fb79e3021113d734892ed69073a391b94a28af29e23aca044cbf5bcc2184`。按原 Android boot header v1、原 ramdisk/DTB 重组 CI `Image.gz-dtb` 的临时镜像 `equuleus-boot-temporary.img`（SHA-256 `e8fcdc2776c557ca3474b14026fc59cf2b8e9bd0e8b2bc52ddf49c76e6f5c765`），`fastboot boot` 返回 `OKAY`；运行时 `uname` 为 `4.9.337-perf-equuleus-gb6ac784a9c3e-dirty`，配置确认 `CONFIG_KSU_MANUAL_HOOK=y` 且所有 `CONFIG_KSU_SUSFS*` 未启用。设备随后重启回原 `/boot`，boot SHA-256 仍为上述备份值，未执行 `flash`。
- ITEM-3 UAPI/Manager：临时启动期间 `ksud 4.2.0-rc3-55-gf6cb7e70 (uapi: 5)`，`ksud boot-info` 返回 A-only、默认分区 `boot`；已安装本地 `com.resukisu.resukisu` BakaSU `v4.2.0-rc3` (versionCode `35226`) arm64 APK，但设备处于锁屏，未完成 Manager UI 交互。普通 shell 执行 `su -c id` 返回 `/system/bin/sh: su: inaccessible or not found`，Root 授权仍未验收。
- ITEM-3 硬件基线：Wi-Fi 已启用、Bluetooth 为 ON、相机服务枚举前后摄、传感器服务可列出传感器；fingerprint HAL 在目标临时 kernel 和随后原 `/boot` 重启后的基线都持续 SIGSEGV，因此记录为现有用户态/硬件验收阻塞，未归因于本次 kernel。
- ITEM-3 第二次临时启动：解锁后打开 BakaSU Manager，目标页未显示原系统的“需要更新内核”，读取到内核驱动 `v4.1.0-8770c7e3@ReSukiSU (30701/5)`、kernel `4.9.337-perf-equuleus-gb6ac784a9c3e-dirty`、Android `15` 和设备 `Xiaomi MI 8 Pro`；页面显示 `0 个超级用户、0 个模块`，说明 UAPI/驱动已被 Manager 读到，但没有可验收的 Root 客户端请求。`su -c id` 仍返回 `/system/bin/sh: su: inaccessible or not found`。
- ITEM-3 目标 kernel 服务检查：Wi-Fi `enabled=true` 且状态 `connected`，Bluetooth `enabled: true` / `state: ON`，相机服务枚举 `6` 个设备，sensorservice 报告 `42` 个硬件传感器；fingerprint HAL 仍 SIGSEGV，与原 `/boot` 基线一致。检查完成后已 `adb reboot` 回到原 `/boot`，当前 `uname` 为 `4.9.337-perf-equuleus-gb6ac784a9c3`，`fastboot devices` 为空，未执行永久刷写。
- ITEM-3 Root 通道验证：目标临时 kernel 下 `ksud debug info` 返回 version `30701`、full version `v4.1.0-8770c7e3@ReSukiSU`、UAPI `5`、built-in runtime；`ksud feature get/check su_compat` 返回值 `1`、`enabled`、`supported`。重启 BakaSU Manager 后其内置 `libksud.so debug su` root service 多次成功，kernel log 记录 `allow root for: 10206`、`ksu fd installed`，Manager 可完成 root service 初始化。普通 ADB shell UID `2000` 未在 allowlist，因此直接 `adb shell su -c id` 返回 `su: inaccessible or not found`；这不等于 Manager/被授权 App 的 Root 失败。
