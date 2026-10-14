---
status: observed
scope: Android / KernelSU / SvcHub / binary_services / OpenList / shared-storage execution
date: 2026-10-14
---
规则：SvcHub 管理的 root binary service 应把 ELF 和服务数据放在全局 `SERVER_DIR`（默认 `/data/media/0/Server`），通过 `savesettings`、`saveservices` 和 `start` 接入；不要把用户服务二进制放进 `/data/adb/modules/SvcHub`。共享存储是否可执行要以实际 SvcHub runner 的结果为准，不能只凭普通 Termux 或应用上下文推断。
适用 / 不适用：适用于 SvcHub `binary_services` 的 root 服务；不适用于 Termux 私有 `termux_services` 或普通应用直接执行。完成验收至少记录 runner 下的版本、SHA-256、进程路径/UID、监听端口和 HTTP 响应，并确认 SvcHub 配置中的服务状态。
证据：设备 `/data/media/0/Server/openlist/openlist` 运行 `v4.2.6`，SHA-256 为 `65f0368358394871a27f75505a4b6af724c33f294989647f20c5e40f80677d92`；进程上下文为 `u:r:ksu:s0`、UID 0，`http://127.0.0.1:5244/` 返回 `200 OK`；SvcHub `1.3.5` 的 `svcstatus` 已报告 `openlist` 为 `running`，`server_dir` 为 `/data/media/0/Server`。
候选归宿：attention
