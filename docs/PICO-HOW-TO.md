# Raspberry Pi Pico (RP2040/RP2350) 开发环境 (Guix Channel)

用 Guix 打包的树莓派 Pico 开发环境。pico-sdk 源码、交叉工具链、构建工具全部在
Guix store 中，`PICO_SDK_PATH` 进入 shell 后自动设置，`pioasm`/`picotool` 由
CMake 自动找到，无需任何手工配置。

- 工具链：源码构建的 GCC **16.1.0** + newlib **4.6.0**（`arm-none-eabi`，
  `rmprofile` multilib，覆盖 Cortex-M0+/M3/M4/M7/M23/M33/M55 及 Cortex-R）
- SDK：pico-sdk **2.2.0**（含 pin 住的 TinyUSB）
- 工具：pioasm 2.2.0、picotool 2.2.0（带 libusb）、树莓派 fork 的
  OpenOCD（命令名 `openocd-rpi`）、probe-rs 0.32.0

## 1. 添加 Channel

在 `~/.config/guix/channels.scm` 中添加：

```scheme
(cons* (channel
        (name 'ebreak)
        (url "https://github.com/ebreak/guix-channel"))
       %default-channels)
```

```bash
guix pull
```

开发中也可以不添加 channel，直接用 `-L` 指向本地 checkout：

```bash
guix shell -L /path/to/guix-channel pico-sdk arm-none-eabi-toolchain ...
```

## 2. 进入开发环境

```bash
guix shell pico-sdk pioasm picotool arm-none-eabi-toolchain cmake ninja python
```

首次使用需要源码编译交叉工具链，可能需要 **数小时**；之后全部走 Guix store
缓存，秒级进入。

进入后检查：

```bash
echo $PICO_SDK_PATH          # 应指向 store 里的 pico-sdk 2.2.0
arm-none-eabi-gcc --version  # 16.1.0
```

## 3. 编译固件

以最小 blinky 为例。`CMakeLists.txt`：

```cmake
cmake_minimum_required(VERSION 3.13)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(blinky C CXX ASM)
pico_sdk_init()

add_executable(blink blink.c)
target_link_libraries(blink pico_stdlib)
pico_add_extra_outputs(blink)   # 生成 .uf2/.hex/.bin 等
```

`blink.c`：

```c
#include "pico/stdlib.h"
int main() {
    const uint led = PICO_DEFAULT_LED_PIN;
    gpio_init(led);
    gpio_set_dir(led, GPIO_OUT);
    while (true) {
        gpio_put(led, 1); sleep_ms(250);
        gpio_put(led, 0); sleep_ms(250);
    }
}
```

构建（已实测通过）：

```bash
cmake -B build -GNinja              # 默认 PICO_BOARD=pico (RP2040)
ninja -C build
# 产物：build/blink.{elf,uf2,hex,bin,...}
```

换板只需一个参数：

```bash
cmake -B build-pico2 -GNinja -DPICO_BOARD=pico2   # RP2350 (Cortex-M33)
ninja -C build-pico2
```

`pioasm`（PIO 汇编器）和 `picotool`（UF2 转换）会被 pico-sdk 的
`find_package` 通过 `CMAKE_PREFIX_PATH` 自动找到，不会触发网络下载。

> 注意：`pico_add_extra_outputs()` 的 UF2 转换依赖 picotool，所以环境里要
> 带上 `picotool`；用到 PIO 的工程（`pico_generate_pio_header`）需要
> `pioasm`；boot_stage2 需要 `python`。上面的 shell 命令已全部包含。

## 4. 刷写固件

### UF2 启动盘（最简单）

按住 BOOTSEL 接入 USB，出现 U 盘后复制：

```bash
cp build/blink.uf2 /media/$USER/RPI-RP2/
```

### picotool（同样在 BOOTSEL 模式）

```bash
picotool load build/blink.uf2
picotool reboot
picotool info -a        # 查看设备信息
```

### Debug Probe / Picoprobe（SWD）

环境里的 `openocd-rpi` 是树莓派官方 fork，自带 `rp2040.cfg`、
`rp2350.cfg` 等目标配置；与上游 `openocd` 包可共存（命令、脚本、文档均带
`-rpi` 后缀）：

```bash
openocd-rpi -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "program build/blink.elf verify reset exit"
```

也可以用 probe-rs：

```bash
probe-rs download build/blink.elf --chip RP2040
probe-rs run      build/blink.elf --chip RP2040
```

## 5. Debug Probe 固件本身

`debugprobe-firmware` 包在构建阶段用上述工具链 + pico-sdk 交叉编译了三个
目标的 Debug Probe 固件（兼作整套环境的端到端验证）：

```bash
guix build debugprobe-firmware
# 输出路径/share/debugprobe-firmware/：
#   debugprobe/debugprobe.uf2          — Debug Probe 配件本体
#   pico/debugprobe_on_pico.uf2        — 跑在 Pico 上
#   pico2/debugprobe_on_pico2.uf2      — 跑在 Pico 2 上
```

把对应的 `.uf2` 按 BOOTSEL 方式复制进 U 盘即完成烧录。

## 6. 包结构

| 包 | 说明 |
|----|------|
| `arm-none-eabi-toolchain` | 源码构建的 GCC 16.1.0 + newlib 4.6.0 + libstdc++（rmprofile multilib） |
| `pico-sdk` | pico-sdk 2.2.0 源码树（含 TinyUSB），导出 `PICO_SDK_PATH` |
| `pioasm` | PIO 汇编器（宿主工具，带 CMake package config） |
| `picotool` | RP2040/RP2350 二进制工具（UF2 转换、BOOTSEL 烧录，带 libusb） |
| `openocd-rpi` | 树莓派 fork 的 OpenOCD（sdk-2.0.0 分支），命令名 `openocd-rpi` |
| `probe-rs` | probe-rs 0.32.0（含 `cargo-flash`、`cargo-embed`） |
| `debugprobe-firmware` | 预编译 Debug Probe 固件（三目标，端到端验证） |

### 环境变量

| 变量 | 何时设置 | 说明 |
|------|---------|------|
| `PICO_SDK_PATH` | 自动 | pico-sdk 的 native-search-path，进 shell 即生效 |
| `CMAKE_PREFIX_PATH` | 自动 | 环境含 `cmake` 时自动包含 pioasm/picotool 的 cmake 配置目录 |

不需要手工设置任何变量；交叉编译器通过 `arm-none-eabi-` 前缀在 `PATH`
中被 pico-sdk 的 toolchain 文件自动使用。

## 7. 故障排除

### 换了 `PICO_BOARD` 后配置混乱

CMake 缓存会记住旧板子，换板请换构建目录或 `rm -rf build` 后重新
configure。

### 提示找不到 pioasm / picotool

确认 shell 里同时带了 `cmake` 与 `pioasm`/`picotool`（`CMAKE_PREFIX_PATH`
由 cmake 的 search-path 生成）。也可以显式指定：

```bash
cmake -B build -Dpioasm_DIR=$(dirname $(dirname $(command -v pioasm)))/lib/cmake/pioasm ...
```

### 构建卡在拉取源码

大陆网络下 GitHub 偶发断连会让 git-fetch 回退到 Software Heritage 镜像，
导致 hash 不匹配报错；重试 `guix build` 即可（成功路径的 hash 与本仓库
pin 的一致）。

### 链接报 `cannot find -lc` / `crt0.o`

说明用的不是本 channel 的工具链（例如系统里另有 arm-none-eabi-gcc 抢先于
`PATH`）。用 `--pure` 进 shell 排除干扰：

```bash
guix shell --pure pico-sdk pioasm picotool arm-none-eabi-toolchain cmake ninja python
```
