# Nix devenv 简化 Linux 开发环境搭建

## devenv 介绍

devenv 是基于 Nix 的开发环境管理工具。它提供现成模块，用于配置语言工具链、开发依赖、环境变量和本地服务等。可以声明式启用，不用自己繁琐地组装依赖和环境变量。

- **Nix**：负责包、依赖、构建和环境复现的底层能力。
- **nixpkgs**：提供软件包，以及 Android SDK 等工具的封装。
- **`mkShell`**：由自己挑选软件包、设置变量，组装开发环境。
- **devenv**：在这些能力上提供更高层的模块和开关，减少重复配置。

### 官方主要支持范围

| 方向 | 代表支持 |
| --- | --- |
| 语言工具链 | Python、Rust、Go、Java、JavaScript/TypeScript、C/C++、PHP、Ruby 等 |
| 本地开发服务 | PostgreSQL、MySQL、Redis、MongoDB、Kafka、nginx 等 |
| 开发流程 | 启动进程、执行任务、测试、Git hooks、CI 环境复用 |
| 专项集成 | Android，以及建立在 Android 模块上的 Flutter 支持 |

上游维护模块，减少了项目自行维护的细节。

### 配置对比

```nix
pkgs.mkShell {
  packages = [
    pkgs.flutter
    # Android SDK、JDK 和其他依赖……
  ];

  # 自己配置 SDK、Java 等环境变量。
}
```

使用 devenv 时，可以调用现成模块。例如在 `devenv.nix` 中启用 Flutter 和 Android：

```nix
{ ... }: {
  android = {
    enable = true;
    flutter.enable = true;
  };
}
```

## 快速开始

### Install Nix

```sh
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### 安装 devenv

#### 开启 requires experimental flags

- `nix-command`：启用 `nix profile`、`nix run`、`nix develop` 等新版命令。
- `flakes`：支持 `nixpkgs#devenv` 这样的 Flake 引用和相关锁定机制。

创建配置目录：

```sh
mkdir -p ~/.config/nix
```

打开或创建 `~/.config/nix/nix.conf`，加入以下配置；若已有相关设置，合并即可，不要覆盖文件中的其他内容：

```conf
extra-experimental-features = nix-command flakes
```

#### 安装 devenv 到当前用户环境：
mkdir / cd
  ↓
devenv init       # 创建开发环境配置
  ↓
devenv shell      # 获得 Flutter 工具
  ↓
flutter create .  # 创建 Flutter 应用
```sh
nix profile install nixpkgs#devenv
```

安装后确认命令可用：

```sh
devenv --version
```

### Initial set up
mkdir / cd
  ↓
devenv init       # 创建开发环境配置
  ↓
devenv shell      # 获得 Flutter 工具
  ↓
flutter create .  # 创建 Flutter 应用
> `devenv` 命令可以直接调用，不需要先进入 `nix` 环境

初始化 devenv 项目

```sh
devenv init
```

## 集成

### Android

```nix
{ pkgs, ... }:

{
  android = {
    enable = true; # 安卓开发套件
  };
}
```

Since Android contains many unfree packages, you need to allow unfree packages in `devenv.yaml`:

```yaml
nixpkgs:
  allow_unfree: true
```

#### 模拟器

由于不可变的 Nix 存储路径与 Android Studio 要求的可变路径之间存在冲突，通过 Android Studio 图形用户界面 (GUI) 创建模拟器可能无法按预期工作。因此，建议通过命令行界面 (CLI) 创建模拟器：

```sh
avdmanager create avd --force --name my-android-emulator-name --package 'system-images;android-32;google_apis_playstore;x86_64'
```

#### Flutter

```nix
{ pkgs, ... }:

{
  android = {
    enable = true;
    flutter.enable = true;
  };
}
```

## 参考

具体细化配置可到以下详看

- [devenv 官网](https://devenv.sh/)
- [Android / Flutter 集成](https://devenv.sh/integrations/android/)
- [配置选项参考](https://devenv.sh/reference/options/)
- [Android SDK 许可证](https://developer.android.com/studio/terms)

---

## exp

```sh
mkdir / cd
  ↓
devenv init       # 创建开发环境配置
  ↓
devenv shell      # 获得 Flutter 工具
  ↓
flutter create .  # 创建 Flutter 应用
```

```sh
mkdir devenv_dmeo && cd devenv_dmeo
devenv init

# 改配置引入安卓flutter
...

devenv shell
flutter create --platforms=android .

avdmanager create avd --force --name my-android-emulator-name --package 'system-images;android-32;google_apis_playstore;x86_64'

flutter emulators # 查看已创建的模拟器
flutter emulators --launch my-android-emulator-name #启动名为 my-android-emulator-name 的模拟器

flutter run
```

## 已知问题

### 模拟器动态库冲突

[devenv #2782](https://github.com/cachix/devenv/issues/2782)：`LD_LIBRARY_PATH` 导致模拟器加载不兼容的 `libc++.so`，报 `undefined symbol`，Flutter 因而显示 `No emulators available`。截至 2026-10-19，issue 仍开放，未确认正式修复。

临时绕过：仅在查询、启动模拟器时移除该变量，不修改全局环境：

```sh
env -u LD_LIBRARY_PATH flutter emulators
env -u LD_LIBRARY_PATH flutter emulators --launch my-android-emulator-name
```

### Android Build Tools 版本不匹配

本次 Flutter 3.47.4 创建的项目使用 AGP 9.1.0，构建要求 Build Tools 36.0.0，但 devenv 默认 SDK 最高仅包含 35.0.0。Gradle 尝试自动安装缺失组件时，因 `/nix/store` 只读而失败。这是工具链默认版本未配套，与上述模拟器问题无关；`rolling` 也不保证各模块默认版本始终同步。

处理方式：在 `devenv.nix` 中显式声明所需版本，重新进入 `devenv shell` 后重试（尚未验证构建通过）：

```nix
android.buildTools.version = [ "36.0.0" "35.0.0" ];
```
