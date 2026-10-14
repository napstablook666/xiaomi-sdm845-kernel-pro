---
status: observed
scope: Xiaomi equuleus / Android 15 / KernelSU / SvcHub 1.3.5 / binary_services / OpenList
date: 2026-10-14
---
规则：在本次 Xiaomi `equuleus`、Android 15、SvcHub `1.3.5` 实测中，SvcHub 管理的 root binary service 将 ELF 和服务数据放在全局 `SERVER_DIR`（默认 `/data/media/0/Server`），通过 `savesettings`、`saveservices` 和 `start` 接入；不要把用户服务二进制放进 `/data/adb/modules/SvcHub`。共享存储是否可执行必须由目标设备上的实际 SvcHub runner 验证，本条不把结果推广到其他 Android 设备、系统版本或运行上下文。
适用 / 不适用：本条仅适用于上述设备和 SvcHub 版本下的 `binary_services` root 服务；不适用于 Termux 私有 `termux_services` 或普通应用直接执行。完成验收至少记录 runner 下的版本、SHA-256、进程路径/UID、监听端口和 HTTP 响应，并确认 SvcHub 配置中的服务状态。
证据：本次设备上的 `/data/media/0/Server/openlist/openlist` 运行 `v4.2.6`，SHA-256 为 `65f0368358394871a27f75505a4b6af724c33f294989647f20c5e40f80677d92`；重启手机后 SvcHub runner 自动重新拉起该进程，进程上下文为 `u:r:ksu:s0`、UID 0，`*:5244` 仍在监听，`http://127.0.0.1:5244/` 返回 `200 OK`；重启前的 SvcHub `1.3.5` `svcstatus` 已报告 `openlist` 为 `running`、`auto=start`，`server_dir` 为 `/data/media/0/Server`。
安全边界：OpenList 当前以 UID 0 绑定 `0.0.0.0:5244`；不要将此端口暴露到不可信网络。管理员口令不写入仓库或任务记忆；弱口令应尽快轮换为强口令。经授权修改后，须按该版本客户端实际 API 协议确认应用层认证成功；单凭设置命令成功、HTTP 200、进程存活或端口监听不足以证明登录可用。本条不保存初始密码或其他明文凭据。
候选归宿：attention
