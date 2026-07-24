# LetMeBlock — 本地 macOS 编译说明（RootHide / roothide）

本文记录 **RootHide 版 LetMeBlock** 在本地 macOS 上的完整编译与装机流程。  
本次移植实际使用的 Theos 路径为：

```text
/Users/danbo/theos-roothide
```

对应环境变量：

```bash
export THEOS=~/theos-roothide
# 等价于
export THEOS=/Users/danbo/theos-roothide
```

> 不要用普通 rootless 版 Theos（例如 `~/theos`）编 roothide 包，路径前缀与 `jbroot` 链接方式会不对。

---

## 0. 产物是什么

| 项 | 值 |
|----|-----|
| 包名 | `com.ps.letmeblock` |
| 版本 | `1.3.0`（见 `Makefile` 的 `PACKAGE_VERSION`） |
| 架构 | `iphoneos-arm64e`（含 arm64 + arm64e 切片） |
| 方案 | `THEOS_PACKAGE_SCHEME=roothide`（Makefile 默认） |
| 输出 deb | `./packages/com.ps.letmeblock_1.3.0_iphoneos-arm64e.deb` |
| 设备路径 | `/usr/lib/TweakInject/LetMeBlock.dylib` |
| 注入目标 | `mDNSResponder`、`mDNSResponderHelper` |
| 依赖 | `ellekit`（或 mobilesubstrate）、`com.opa334.libsandy` |

插件作用：让 mDNSResponder 读取越狱环境下的 hosts（优先 `/var/jb/etc/hosts`），从而自定义域名解析。

---

## 1. 环境依赖

### 1.1 必需

| 组件 | 说明 | 本机参考路径 |
|------|------|----------------|
| **theos-roothide** | RootHide 分支 Theos | `/Users/danbo/theos-roothide` |
| **iOS SDK（Theos 侧）** | 已放在 Theos 的 `sdks/` 下即可 | `~/theos-roothide/sdks/iPhoneOS16.5.sdk` |
| **clang / 工具链** | Xcode 或 Command Line Tools | 见下节 |
| **ldid** | 签名 dylib | `/usr/local/bin/ldid` |
| **dm.pl** | Theos 自带，打 deb | Theos 内置 |

### 1.2 Xcode vs Command Line Tools

两种情况都能编，注意 `DEVELOPER_DIR`：

**A. 已装完整 Xcode**

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
# 或临时：
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

**B. 仅 Command Line Tools（本次成功编译时的情况）**

本机若没有 `/Applications/Xcode.app`，而只有：

```text
/Library/Developer/CommandLineTools
```

则必须：

```bash
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
```

否则 `xcrun` / `git` 可能报：

```text
xcrun: error: missing DEVELOPER_DIR path: /Applications/Xcode.app/Contents/Developer
```

建议把下面几行放进 `~/.zshrc`（按你机器改路径）：

```bash
export THEOS=~/theos-roothide
export PATH=/usr/local/bin:$PATH   # ldid
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
# 若使用完整 Xcode，改成：
# export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

### 1.3 设备侧依赖（装 deb 之前）

手机上需已安装：

- RootHide 越狱环境 + **ElleKit**
- **libSandy**（`com.opa334.libsandy`，含 `sandyd` / `libsandy.dylib`）

Sileo 里搜 `libSandy` 安装即可。本机编译不需要手机在线，但**安装运行**需要 libSandy。

---

## 2. 仓库与 vendor 目录

源码目录示例：

```text
/Users/danbo/Data/jailbreak/tweak/LetMeBlock
```

RootHide 移植后，仓库内已带 **vendor**，离线也能编：

```text
vendor/
├── include/
│   ├── PSHeader/          # Misc.h, PAC.h（符号查找辅助）
│   ├── libSandy.h
│   ├── launch.h
│   └── xpc/               # xpc.h 等（iPhone SDK 常缺，从 Mac SDK 拷入）
└── lib/
    └── libsandy.dylib     # 链接用（可从手机 /usr/lib/libsandy.dylib 再拷）
```

Makefile 中已指定：

```make
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Ivendor/include
$(TWEAK_NAME)_LDFLAGS = -Lvendor/lib
$(TWEAK_NAME)_LIBRARIES = sandy
```

### 2.1 若缺少 xpc 头文件（未使用 vendor 时）

上游 README 的做法（有完整 Xcode 时）：

```bash
sudo ln -s "$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/xpc" \
  "$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include/xpc"
sudo ln -s "$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/launch.h" \
  "$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include/launch.h"
```

本仓库已 vendored `vendor/include/xpc`，**一般不需要**再 symlink。

### 2.2 若需更新 libsandy.dylib

从已装 libSandy 的手机拷贝：

```bash
scp -P 2234 root@iphone:/usr/lib/libsandy.dylib \
  /Users/danbo/Data/jailbreak/tweak/LetMeBlock/vendor/lib/libsandy.dylib
```

（端口、主机名按你的 SSH 配置改。）

---

## 3. 一键编译命令

在仓库根目录执行：

```bash
cd /Users/danbo/Data/jailbreak/tweak/LetMeBlock

export THEOS=~/theos-roothide
export PATH=/usr/local/bin:$PATH
export DEVELOPER_DIR=/Library/Developer/CommandLineTools   # 或 Xcode 路径

# 可选：干净重建
make clean
rm -rf .theos/obj packages

# 打 roothide 包（Makefile 默认已是 roothide，可显式写出）
make package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1
```

成功时末尾类似：

```text
dm.pl: building package `com.ps.letmeblock:iphoneos-arm64e' in `./packages/com.ps.letmeblock_1.3.0_iphoneos-arm64e.deb'
```

检查：

```bash
ls -la packages/
file packages/com.ps.letmeblock_*.deb
```

### 3.1 编译过程中可能看到的警告（可忽略）

1. **rootless-compat 提示**  
   `You're building roothide package with leagy rootless.h...`  
   因为源码仍 `#import <rootless.h>`，在 roothide scheme 下会走兼容层。功能可用；若以后全面改 `roothide.h` / `jbroot()` 可消掉。

2. **libsandy 部署版本**  
   `dylib was built for newer iOS version (15.0) than being linked (14.0)`  
   仅链接警告；目标机 iOS 16 无影响。

### 3.2 常见失败

| 现象 | 处理 |
|------|------|
| `THEOS` 未设置 / 找不到 makefiles | `export THEOS=~/theos-roothide` |
| `ldid: command not found` | 安装 ldid 并保证 `/usr/local/bin` 在 `PATH` |
| `missing DEVELOPER_DIR ... Xcode.app` | 设置正确的 `DEVELOPER_DIR` |
| `xpc.h file not found` | 确认 `vendor/include` 在；或按 §2.1 链 xpc |
| `library not found for -lsandy` | 确认 `vendor/lib/libsandy.dylib` 存在 |
| 编出 `iphoneos-arm` 而非 arm64e | 确认 `THEOS_PACKAGE_SCHEME=roothide` 且用的是 theos-roothide |

---

## 4. 安装到手机

假设 SSH：`root@iphone`，端口 `2234`（按你的实际修改）。

```bash
DEB=packages/com.ps.letmeblock_1.3.0_iphoneos-arm64e.deb

scp -P 2234 "$DEB" root@iphone:/tmp/
ssh -p 2234 root@iphone 'dpkg -i /tmp/com.ps.letmeblock_1.3.0_iphoneos-arm64e.deb'

# 重载 mDNS（改 hosts / 装插件后必须）
ssh -p 2234 root@iphone '
  killall -9 mDNSResponder 2>/dev/null || true
  killall -9 mDNSResponderHelper 2>/dev/null || true
  sleep 1
  launchctl kickstart -k user/501/com.apple.mDNSResponder.reloaded 2>/dev/null || true
'
```

确认文件：

```bash
ssh -p 2234 root@iphone '
  dpkg -l com.ps.letmeblock
  ls -la /usr/lib/TweakInject/LetMeBlock*
  ls -la /Library/libSandy/LetMeBlock.plist
'
```

### 4.1 hosts 文件

把自定义解析写在（RootHide 常见路径）：

```text
/var/jb/etc/hosts
```

示例：

```text
199.180.112.180	search5-noneu.truecaller.com
```

改完后务必再 kill / kickstart mDNS（见上）。

---

## 5. 可选：Theos 远程 install

若已配置 `THEOS_DEVICE_IP` / `THEOS_DEVICE_PORT`：

```bash
export THEOS_DEVICE_IP=iphone   # 或 IP
export THEOS_DEVICE_PORT=2234
export THEOS_DEVICE_USER=root

make package install THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1
```

`after-install` 会尝试 kill mDNSResponder。

---

## 6. 自测清单

### 6.1 是否注入 mDNSResponder（Frida）

```bash
# 查 pid
ssh -p 2234 root@iphone \
  'launchctl print user/501/com.apple.mDNSResponder.reloaded 2>&1 | grep "pid ="'

# 假设 pid=2101
frida -U -p 2101 -q -e '
var m = Process.findModuleByName("LetMeBlock.dylib");
console.log(m ? ("OK " + m.path) : "LetMeBlock NOT loaded");
console.log(Process.findModuleByName("libsandy.dylib") ? "libsandy OK" : "libsandy missing");
'
```

期望：打印 `LetMeBlock.dylib` 的 jbroot 下路径，且 `libsandy` 已加载。

### 6.2 hosts 是否生效

不要用「本来就等于公网 A 记录」的 IP 做唯一判断。可临时写入文档用假 IP 再查：

```bash
# 手机上
echo "203.0.113.77 search5-noneu.truecaller.com" >> /var/jb/etc/hosts
killall -9 mDNSResponder
# 再 kickstart 后：
getent hosts search5-noneu.truecaller.com
# 若出现 203.0.113.77，说明 hosts + LetMeBlock 生效
```

测完恢复你的正式 hosts 条目。

---

## 7. 目录与 Makefile 要点（便于改）

```make
THEOS_PACKAGE_SCHEME ?= roothide   # 默认 roothide
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
FINALPACKAGE = 1

# 编 rootless 包时（一般不用于本机 RootHide 真机）：
# make package THEOS_PACKAGE_SCHEME=rootless
```

逻辑 hosts 查找顺序（`Tweak.xm`）：

1. `/var/jb/etc/hosts`
2. `ROOT_PATH("/etc/hosts")` → roothide 下为 `jbroot("/etc/hosts")`
3. `ROOT_PATH("/etc/hosts.lmb")`

---

## 8. 完整「从克隆到 deb」最小脚本

可保存为 `build.sh` 后执行 `bash build.sh`：

```bash
#!/bin/bash
set -euo pipefail

export THEOS="${THEOS:-$HOME/theos-roothide}"
export PATH="/usr/local/bin:$PATH"
# 按本机修改：
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"

cd "$(dirname "$0")"

test -d "$THEOS/makefiles" || { echo "THEOS invalid: $THEOS"; exit 1; }
test -x /usr/local/bin/ldid || { echo "ldid missing"; exit 1; }
test -f vendor/lib/libsandy.dylib || { echo "vendor/lib/libsandy.dylib missing"; exit 1; }

make clean || true
rm -rf .theos/obj packages
make package THEOS_PACKAGE_SCHEME=roothide FINALPACKAGE=1

echo "OK: $(ls -1 packages/*.deb)"
```

---

## 9. 与本次移植相关的环境事实（备忘）

| 项 | 值 |
|----|-----|
| Theos | `/Users/danbo/theos-roothide` |
| 使用的 SDK | `~/theos-roothide/sdks/iPhoneOS16.5.sdk` |
| 签名 | `ldid` @ `/usr/local/bin/ldid` |
| 成功 deb | `packages/com.ps.letmeblock_1.3.0_iphoneos-arm64e.deb` |
| 测试机 | iPhone，SSH `root@iphone:2234`，RootHide |
| 真机验证 | Frida 确认注入 mDNSResponder；假 IP hosts 解析成功 |

---

## 10. 参考

- 上游：https://github.com/PoomSmart/LetMeBlock  
- libSandy：https://github.com/opa334/libSandy  
- RootHide 开发说明：https://github.com/roothide/Developer  
- 本仓库 git 移植提交示例：`fb56b00`（*Port LetMeBlock to RootHide*）

---

*文档对应仓库路径：`LetMeBlock/BUILD-macos-roothide.md`*
