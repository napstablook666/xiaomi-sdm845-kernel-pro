---
status: active
created: 2026-10-13
work: ../work/epic-equuleus-resukisu-build.md
---
# 小米 8 UD ReSukiSU UAPI 5 自编译与设备验收

## 起点与目标
用户计划在新会话继续自编译。目标是在确认的 GitHub fork 上构建 ReSukiSU UAPI 5 内核，为 Xiaomi Mi 8 UD（`equuleus`、Android 15 / LineageOS 22.2、Linux 4.9.337）准备可审计的安装包并逐步验收。Hook 模式已按 owner 委托选择 Manual Hook；该选择意味着此构建不提供 SUSFS Inline Hook。

## 范围
- 修正并验证 `.github/workflows/build-resukisu-equuleus.yml` 的 Kconfig、固定源码、工具链、镜像检查和元数据。
- 在用户确认的 fork/分支运行 Actions，离线核对日志、最终配置、内核镜像及 AnyKernel3 ZIP，并记录来源和 SHA-256。
- 构建产物通过审核、安装路径明确且用户另行批准后，才进行临时启动或刷写和设备兼容性验收。

## 非目标与边界
- 本 Epic 不安装 Zygisk Next、LSPosed 或其他模块，不发布 GitHub Release。
- 构建成功不等于允许刷机。刷写前必须核实当前系统、boot 分区布局、备份匹配性、安装路径和恢复步骤，并由用户明确通过刷写 checkpoint。
- 不暂存或提交此目录中现有 ROM、boot 镜像、工具、ZIP、APK 等未跟踪材料；本地初始里程碑提交为 `3e59465`，远端初始发布提交为 `1b2782e902184639b2aade66a8433b4b806fea8a`，其后 adapter 修复提交为 `e684bca9f8e954aa61f2f845fb67ba558110565a`、artifact 修复提交为 `cd5b314c1b601d7f142569edd21ea433dbc92cdb`，成功构建所用 head 为 `cd5b314c1b601d7f142569edd21ea433dbc92cdb`，当前目标分支 head 为 `c82b21d0e7e03ca31a78f92925f4bc84348187b3`；后续只允许精确暂存相关路径。

## 已核实事实
- 设备上次识别为序列号 `c967753e`、产品 `equuleus`；新会话须重新检查设备、LineageOS 构建、bootloader 解锁状态和当前内核/Manager 状态。
- 固定内核基线为 `b6ac784a9c3ec331c0cc2de9c5b5e99a9c4c7ddb`；AnyKernel3 为 `9eed8aea17dd92b97cf71368b74ac1174129e733`。
- 计划评估的 ReSukiSU 源码提交为 `8770c7e324a22895703c4916b8a16520e0b81c79`，其 `uapi/supercall.h` 声明 `KERNEL_SU_UAPI_VERSION = 5`。基线 gitlink 原先指向 `54e7551e01bb131403aa8e600147fee40b2ee000`（UAPI 2）。`build_for_equuleus.sh` 不会再次运行 `git submodule update`；workflow 必须显式 fetch/checkout 并校验固定提交。
- 历史问题已解决：ReSukiSU `kernel/Kconfig` 将 `KSU_MANUAL_HOOK` 与 `KSU_SUSFS` 放在同一个互斥 `choice` 中，旧 workflow 曾同时断言二者为 `y`。ITEM-1 已按 Linux 4.9 评估改为选择 `KSU_MANUAL_HOOK=y`、不启用 `KSU_SUSFS`；固定 ReSukiSU Kconfig 中所有 `CONFIG_KSU_SUSFS*` 子项均依赖该顶层选择，adapter/workflow 拒绝最终 `.config` 中任一 family 符号为 `y`。
- 历史问题已解决：基线 `arch/arm64/Makefile` 把 `Image.gz` 与 DTB 拼成 `Image.gz-dtb`，旧 workflow 对该文件执行 `gunzip` 会因尾随 DTB 在 `pipefail` 下返回状态码 2。ITEM-1 已改为检查未压缩的 `out/arch/arm64/boot/Image`，并验证 `Image.gz-dtb` 与 ZIP 内镜像一致。
- 工具链锁定方案为 Ubuntu 24.04 官方 APT Snapshot `20261013T000000Z`，并对显式安装包固定完整版本：`clang-18=1:18.1.3-1ubuntu1`、`llvm-18=1:18.1.3-1ubuntu1`、`lld-18=1:18.1.3-1ubuntu1`、`gcc-aarch64-linux-gnu=4:13.2.0-7ubuntu1`、`binutils-aarch64-linux-gnu=2.42-4ubuntu2.10`、`gcc-arm-linux-gnueabihf=4:13.2.0-7ubuntu1`、`binutils-arm-linux-gnueabihf=2.42-4ubuntu2.10`、`binutils=2.42-4ubuntu2.10`、`bc=1.07.1-3ubuntu4`、`bison=2:3.8.2+dfsg-1ubuntu0.24.04.1`、`ccache=4.9.1-1`、`flex=2.6.4-8.2build1`、`libelf-dev=0.190-1.1ubuntu0.1`、`libssl-dev=3.0.13-0ubuntu3.16`、`make=4.3-4.1build2`、`patch=2.7.6-7build3`、`unzip=6.0-28ubuntu4.1`、`zip=3.0-13ubuntu0.2`；metadata 仍记录编译器、链接器和实际包版本。
- Snapshot 源范围已按候选 workflow 约束为 `https://snapshot.ubuntu.com/ubuntu/20261013T000000Z/` 的 `noble`、`noble-updates`、`noble-security` 三个 suite，且仅使用 `main`、`universe` 两个 component 的 `binary-amd64/Packages.xz`；不配置 `noble-backports`，也不把 `restricted`/`multiverse` 纳入解析范围。
- 固定根包来源校验结果：`clang-18`、`llvm-18`、`lld-18` 来自 `noble-updates/universe`；`gcc-aarch64-linux-gnu`、`gcc-arm-linux-gnueabihf`、`bc`、`flex`、`make`、`patch` 来自 `noble/main`；`binutils-aarch64-linux-gnu`、`binutils-arm-linux-gnueabihf`、`binutils`、`zip` 来自 `noble-updates/main`；`ccache` 来自 `noble/universe`；`bison`、`libelf-dev`、`libssl-dev`、`unzip` 的固定版本在 `noble-security/main` 与 `noble-updates/main` 均存在。
- 对 `clang-18`、`llvm-18`、`lld-18` 的来源冲突已直接复核原始 `Packages.xz`：三者的精确版本 `1:18.1.3-1ubuntu1` 均只命中 `noble-updates/universe`，对应文件名分别为 `clang-18_18.1.3-1ubuntu1_amd64.deb`、`llvm-18_18.1.3-1ubuntu1_amd64.deb`、`lld-18_18.1.3-1ubuntu1_amd64.deb`；`noble/universe` 未命中这些精确版本。
- Snapshot 索引级依赖闭包校验已通过：固定根包及其 `Pre-Depends`、`Depends`、`Recommends` 共 `248` 个包、`755` 条依赖边，无未解析项；来源计数为 `noble/main=73`、`noble-updates/main=52`、`noble-security/main=106`、`noble/universe=5`、`noble-updates/universe=10`、`noble-security/universe=2`，未使用其他 suite/component。该结果验证索引候选与版本约束，不替代获批后 ITEM-1 中的实际 `apt-get` 安装验证。
- workflow 的发布目标已确定为 `https://github.com/napstablook666/xiaomi-sdm845-kernel-pro` 的 `codestable/equuleus-resukisu-build` 分支；`https://github.com/GuLingguang/xiaomi-sdm845-kernel-pro` 的 `lineage-22.2` 仅作只读参考基线。owner 已授权自动 push 和运行 Actions；ITEM-2 已由 run `38404743286` 在远端提交 `cd5b314c1b601d7f142569edd21ea433dbc92cdb` 上完成并记录于 work 游标。
- 回滚镜像 `D:\AI\小米8ud\boot-stock-lineage-20261006.img` 的已知 SHA-256 为 `08CE8935501BBDD5468BD40EDF4367C8F2A5BAD10BCF9229C74069638AABA4CF`。这只确认文件身份，尚未证明它匹配刷写时设备运行的系统构建、boot 分区或 slot，不得据此宣称回滚路径已验证。
- 设备上次使用 Lineage Recovery 22.2；当前未验证它能安装 `ak3-equuleus.zip`。不得假设 Recovery 接受或正确执行 AnyKernel3 包。
- 当前 ReSukiSU Manager 兼容 UAPI 5 的具体版本/官方产物尚未选定。新会话须固定官方来源、构建/版本和 SHA-256，并验证它能正常读取驱动状态及执行 Root 操作；已安装的其他 Manager 不能自动视为通过。

## 关键决策
- **DEC-1 · KSU Hook 模式（已批准）**：owner 已批准依据 Linux 4.9 评估选择 `KSU_MANUAL_HOOK=y`；`KSU_SUSFS` 不启用，因此该构建不提供 SUSFS Inline Hook。最终 `.config` 必须满足 `KSU_MANUAL_HOOK=y` 且任何 `CONFIG_KSU_SUSFS*` family 符号都不能为 `y`。
- **DEC-2 · GitHub 目标（已确定）**：`https://github.com/GuLingguang/xiaomi-sdm845-kernel-pro` 的 `lineage-22.2` 继续作为只读参考基线；发布目标为 `https://github.com/napstablook666/xiaomi-sdm845-kernel-pro` 的 `codestable/equuleus-resukisu-build` 分支。owner 已确认自动 push 和运行 Actions，不得把只读参考基线当作发布目标。
- **DEC-3 · 安装与恢复路径（待验证）**：先验证 Lineage Recovery 对 AnyKernel3 的支持，以及包的设备判断/写入目标。若不支持，使用与当前系统完全匹配的 LineageOS 原始 boot ramdisk 和 Actions 内核镜像重打包；核对 boot image 格式后，优先使用设备支持的 `fastboot boot` 临时验证，再讨论永久刷写。
- **DEC-4 · 刷写 checkpoint**：CI 与离线产物审查不触发刷写。永久写入前需用户另行明确批准，并核对当前系统构建、bootloader 解锁状态、实际分区/slot、回滚镜像匹配性与 SHA-256、可执行恢复命令和 Fastboot 可用性；任何一项不明即停止。

## 子项契约
- **ITEM-1 · 修正构建流程**（cs-issue）：按已记录的 DEC-1 设置 Kconfig，不能同时断言互斥选项；显式 checkout ReSukiSU UAPI 5；修正 `Image.gz-dtb` 检查；使用已冻结的 Ubuntu 24.04 APT Snapshot 和完整包版本固定工具链并记录版本；保留基线、AnyKernel3 提交及来源校验。用 YAML/actionlint 与 shell 静态检查验证。
- **ITEM-2 · 运行可复现 CI**（cs-feat）：在用户确认的 fork/分支运行 Actions；记录 canonical URL、全部源码提交、UAPI、用户确认的 hook 配置、OS/工具链版本、内核版本、产物路径及 SHA-256。定义为固定输入/工具链可重跑；若未验证 bit-for-bit，不作该声明。失败或元数据不符时不得进入设备验证。
- **ITEM-3 · 安装路径审查与设备验收**（cs-epic）：先检查 ZIP 中设备识别、写入目标及实际内核镜像一致性，并验证 Lineage Recovery 是否支持该 AK3 包。若不支持，用匹配当前 LineageOS 的原始 boot ramdisk 与 Actions 内核重打包，核对 header/分区后优先临时启动；不支持临时启动时，在另行评估风险并获用户批准前不永久刷写。永久刷写前逐项通过 DEC-4。使用来源和版本已固定、SHA-256 已记录的 UAPI 5 兼容 ReSukiSU Manager；再验证 Root、Manager/驱动交互、模块状态及 Wi-Fi、移动数据、蓝牙、GPS、摄像头、指纹、充电和重启。

## 整体验收
- Actions 成功，来源提交和 UAPI 5 正确，工具链版本可复核，最终 `.config` 与用户确认的唯一 hook 模式一致；镜像和 ZIP 内容、来源及 SHA-256 均经核对。
- 已证明一种可执行的安装路径：Lineage Recovery 正确处理并安装 AK3，或匹配 ramdisk 的重打包镜像通过临时启动验证。不能仅凭 ZIP 非空或哈希存在认定可安装。
- 若进行永久刷写，DEC-4 所列设备状态、分区和回滚前置条件全部有证据且用户已批准；否则只报告离线结果，不刷写。
- 设备验收只有在匹配的官方 Manager 能使用 UAPI 5 驱动、Root 正常且基础硬件功能通过后才算完成。Actions 构建已通过；未刷机时，不得宣称设备验收通过。

## 遗留风险
- UAPI 5 ReSukiSU 提交已在固定 Linux 4.9 kernel source tree 上完成交叉编译；目标设备上的实机启动、Root 和硬件适配尚未验证。
- Manual Hook 已获 owner 批准；workflow 已修正互斥断言、`Image.gz-dtb` 尾随 DTB 检查和构建日志路径，首轮 Actions 编译因 adapter 兼容补丁失败，已在修复提交后由 run `38404743286` 完成编译与产物验收；ITEM-2 已通过。
- Recovery 对 AK3 的支持、匹配当前系统的 boot ramdisk、临时启动能力和官方 UAPI 5 Manager 仍待新会话核实。
- Snapshot 索引级依赖闭包已验证；首轮 workflow 已完成 APT 安装、固定 baseline/UAPI 5 checkout 和配置步骤，但 run `38393628663` 在编译阶段因 `fs/namei.c:3801:26: error: use of undeclared identifier 'tmp'` 失败。修复提交 `e684bca9f8e954aa61f2f845fb67ba558110565a` 及其 artifact 隐藏文件修复提交 `cd5b314c1b601d7f142569edd21ea433dbc92cdb` 后，run `38404743286` 完成构建和产物验收；ITEM-2 已通过，本地回滚镜像仍未证明与未来刷写时系统匹配。
