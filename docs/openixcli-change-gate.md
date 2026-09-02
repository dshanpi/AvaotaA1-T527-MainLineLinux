# OpenixCLI 变更门禁

OpenixCLI 是多个 Allwinner 芯片和产品共用的烧录工具。已通过真实烧录验证的
OpenixCLI 二进制及其行为默认冻结。

只有以下两种情况允许修改 OpenixCLI：

1. 明确新增 OpenixCLI 功能；
2. 有可复现证据证明问题属于 OpenixCLI 自身的业务逻辑 bug。

板卡固件、BootROM/FEL 状态、FES loader、目标 U-Boot/Linux 驱动、镜像打包、
线缆、权限、USB/VMware 重连或其他环境问题，不得通过修改 OpenixCLI 规避；
必须在对应组件内定位和修复。

获准修改时必须增加针对性回归测试、运行既有测试，并明确检查其他 SoC 与存储
后端没有行为变化。未经实机验证的临时 workaround 不得合入共用 OpenixCLI。

本仓库烧录门禁固定接受已验证二进制：

```text
SHA-256 c370b3b5079ff67672728d127df57e1cb234e18a10febd4ca3cda36a635662ae
```

只有通过上述门禁并完成多芯片回归后，才能评审更新该哈希。
