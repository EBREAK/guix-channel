# Zephyr RTOS 开发环境 (Guix Channel)

用 Guix 打包的 Zephyr RTOS 4.4.2 开发环境。所有源码、交叉工具链和构建工具都安装在
Guix store 中，不在 `$HOME` 下创建任何 workspace。**不使用 `west`**，直接用
`cmake` + `ninja` 编译。`ZEPHYR_BASE` 和 `Zephyr 模块列表`（`ZEPHYR_MODULES`）
进入 shell 后自动设置。

- 工具链：GCC **16.1.0** + newlib **4.6.0**（三套：`arm-zephyr-eabi`、
  `aarch64-zephyr-elf`、`riscv64-zephyr-elf`，后者支持 rv32/rv64 multilib）
- 构建工具：CMake 4.1.3、Ninja、DTC、gperf、OpenOCD、QEMU、Python 3.12 + 全部
  Zephyr 构建脚本依赖

## 支持的目标板

| 目标板 | BOARD 标识 | 架构 | 交叉编译前缀 |
|--------|-----------|------|-------------|
| Raspberry Pi Pico (RP2040) | `rpi_pico` | Cortex-M0+ | `arm-zephyr-eabi-` |
| Raspberry Pi Pico 2 (RP2350 ARM) | `rpi_pico2/rp2350a/m33` | Cortex-M33 | `arm-zephyr-eabi-` |
| Raspberry Pi Pico 2 (RP2350 RISC-V) | `rpi_pico2/rp2350a/hazard3` | Hazard3 | `riscv64-zephyr-elf-` |
| WCH CH32V307 | `ch32v307v_evt_r1` | QingKe V4F | `riscv64-zephyr-elf-` |
| Raspberry Pi 4B | `rpi_4b` | Cortex-A72 | `aarch64-zephyr-elf-` |
| 本机仿真 | `native_sim/native/64` | x86-64 (host) | 无（host 工具链） |

---

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
guix shell -L /path/to/guix-channel zephyr-development-environment
```

## 2. 进入开发环境

```bash
guix shell zephyr-development-environment
```

首次使用需要从源码编译三套交叉工具链，可能需要 **数小时**；之后全部走 Guix
store 缓存，秒级进入。

进入后检查环境变量（应已自动设置）：

```bash
echo $ZEPHYR_BASE
echo $ZEPHYR_MODULES | tr ';' '\n'   # 应列出 6 个模块
```

包含的 Zephyr 模块：`cmsis`（Cortex-A/R 头文件）、`cmsis_6`（Cortex-M 头文件，
**RP2040/RP2350 必需**）、`picolibc`、`segger`、`hal_rpi_pico`、`hal_wch`。

## 3. 编译固件

进入 shell 后，按目标板设置 3 个环境变量，再用 `cmake` + `ninja`。以 RP2040 为例：

```bash
export CROSS_COMPILE=arm-zephyr-eabi-
export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
export TOOLCHAIN_HOME=$(dirname $(command -v arm-zephyr-eabi-gcc))

cmake -B build -GNinja -DBOARD=rpi_pico \
  -DTOOLCHAIN_HOME=$TOOLCHAIN_HOME \
  -DPython3_EXECUTABLE=$(command -v python3) \
  $ZEPHYR_BASE/samples/basic/blinky

ninja -C build
```

输出在 `build/zephyr/`：`zephyr.elf`、`zephyr.bin`、`zephyr.hex`、`zephyr.uf2`。

> `-DPython3_EXECUTABLE=$(command -v python3)` **必须传**：否则 CMake 会找到系统
> Python（缺少 yaml/jsonschema 等依赖）。

各目标板只需替换 `BOARD`、`CROSS_COMPILE` 和工具链前缀：

### RP2350 ARM (Cortex-M33)

```bash
export CROSS_COMPILE=arm-zephyr-eabi-
export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
export TOOLCHAIN_HOME=$(dirname $(command -v arm-zephyr-eabi-gcc))

cmake -B build -GNinja -DBOARD=rpi_pico2/rp2350a/m33 \
  -DTOOLCHAIN_HOME=$TOOLCHAIN_HOME \
  -DPython3_EXECUTABLE=$(command -v python3) \
  $ZEPHYR_BASE/samples/basic/blinky
ninja -C build
```

### RP2350 RISC-V (Hazard3)

```bash
export CROSS_COMPILE=riscv64-zephyr-elf-
export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
export TOOLCHAIN_HOME=$(dirname $(command -v riscv64-zephyr-elf-gcc))

cmake -B build -GNinja -DBOARD=rpi_pico2/rp2350a/hazard3 \
  -DTOOLCHAIN_HOME=$TOOLCHAIN_HOME \
  -DEXTRA_DTC_OVERLAY_FILE=rp2350-hazard3-led.overlay \
  -DPython3_EXECUTABLE=$(command -v python3) \
  $ZEPHYR_BASE/samples/basic/blinky
ninja -C build
```

Zephyr 4.4.2 的 hazard3 板级变体漏掉了 LED 定义（`m33` 变体有，`hazard3`
没有），编译 blinky 需要 `rp2350-hazard3-led.overlay` 补上 `led0`：

```dts
/ {
	leds {
		compatible = "gpio-leds";
		led0: led_0 {
			gpios = <&gpio0 25 GPIO_ACTIVE_HIGH>;
			label = "LED";
		};
	};
	aliases {
		led0 = &led0;
	};
};
```

> 已在 prebuild 中验证：产物为 RV32IMAC（`zba/zbb/zbkb/zbs` 扩展），
> ELF 入口 `0x10000000`。GCC 16.1.0 下无早期 GCC 12.3 的 picolibc ICE
> 问题；RV32 multilib 正常工作。

### CH32V307

```bash
export CROSS_COMPILE=riscv64-zephyr-elf-
export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
export TOOLCHAIN_HOME=$(dirname $(command -v riscv64-zephyr-elf-gcc))

cmake -B build -GNinja -DBOARD=ch32v307v_evt_r1 \
  -DTOOLCHAIN_HOME=$TOOLCHAIN_HOME \
  -DPython3_EXECUTABLE=$(command -v python3) \
  $ZEPHYR_BASE/samples/basic/blinky
ninja -C build
```

### Raspberry Pi 4B

```bash
export CROSS_COMPILE=aarch64-zephyr-elf-
export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
export TOOLCHAIN_HOME=$(dirname $(command -v aarch64-zephyr-elf-gcc))

cmake -B build -GNinja -DBOARD=rpi_4b \
  -DTOOLCHAIN_HOME=$TOOLCHAIN_HOME \
  -DPython3_EXECUTABLE=$(command -v python3) \
  $ZEPHYR_BASE/samples/basic/blinky
ninja -C build
```

### native_sim（本机仿真，无需交叉工具链）

```bash
export ZEPHYR_TOOLCHAIN_VARIANT=host
unset CROSS_COMPILE TOOLCHAIN_HOME

cmake -B build -GNinja -DBOARD=native_sim/native/64 \
  -DPython3_EXECUTABLE=$(command -v python3) \
  $ZEPHYR_BASE/samples/basic/blinky
ninja -C build
./build/zephyr/zephyr.elf        # 直接运行
```

> Zephyr 4.x 中 `native_posix` 已改名为 `native_sim`；64 位变体用
> `native_sim/native/64`（纯 `native_sim` 默认 32 位，需要 32 位 glibc，本环境
> 未提供）。

## 4. 编译自己的项目

把 cmake 的最后一个参数换成你的应用目录（含 `CMakeLists.txt` 与源码）即可：

```bash
cmake -B build -GNinja -DBOARD=rpi_pico \
  -DTOOLCHAIN_HOME=$TOOLCHAIN_HOME \
  -DPython3_EXECUTABLE=$(command -v python3) \
  ~/my-zephyr-app
ninja -C build
```

一个最小的 `CMakeLists.txt`：

```cmake
cmake_minimum_required(VERSION 3.20)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(my_app)

target_sources(app PRIVATE src/main.c)
```

其他常用操作：

```bash
# 传 Kconfig 片段 / overlay
cmake -B build -GNinja -DBOARD=rpi_pico -DEXTRA_DTC_OVERLAY_FILE=app.overlay \
  -DEXTRA_CONF_FILE=debug.conf ... <app-dir>

# 增量编译
ninja -C build

# 完全清理
rm -rf build
```

## 5. 预编译验证固件

`zephyr-prebuild` 包在构建阶段编译全部已验证目标的 blinky，可用来快速检验环境
或直接取用固件：

```bash
guix build zephyr-prebuild
# 输出路径/share/zephyr-prebuild/<目标>/zephyr.{elf,bin,hex,uf2}
```

已验证目标：`rp2040`、`rp2350-arm`、`rp2350-riscv`、`ch32v307`、`rpi4b`、
`native-sim`。

## 6. 刷写固件

### RP2040 / RP2350（UF2，最简单）

按住 BOOTSEL 接入 USB，出现 U 盘后复制：

```bash
cp build/zephyr/zephyr.uf2 /media/$USER/RPI-RP2/
```

### SWD / JTAG（OpenOCD，环境内已含）

```bash
# RP2040 via CMSIS-DAP
openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg \
  -c "program build/zephyr/zephyr.elf verify reset exit"
```

### CH32V307（WCH-Link）

```bash
# 环境外单独安装：guix install wch-link   # 或 wchisp
wchisp flash build/zephyr/zephyr.bin
# 或
openocd -f interface/wlink.cfg -f target/ch32v.cfg \
  -c "program build/zephyr/zephyr.elf verify reset exit"
```

## 7. 包结构

| 包 | 说明 |
|----|------|
| `zephyr-development-environment` | **一键环境**：源码 + 全部模块 + SDK + Python 依赖 |
| `zephyr-source` | Zephyr 4.4.2 核心源码，导出 `ZEPHYR_BASE` |
| `zephyr-modules-cmsis` | CMSIS-Core（Cortex-A/R） |
| `zephyr-modules-cmsis-6` | CMSIS-Core 6（Cortex-M，RP2040/RP2350 必需） |
| `zephyr-modules-picolibc` | picolibc C 库 |
| `zephyr-modules-segger` | SEGGER RTT / SystemView |
| `zephyr-modules-hal-rpi-pico` | RP2040 / RP2350 HAL |
| `zephyr-modules-hal-wch` | WCH CH32V / CH32L HAL |
| `zephyr-sdk` | 三套交叉工具链 + OpenOCD/QEMU/DTC/CMake/Ninja/gperf |
| `zephyr-python-deps` | Zephyr 构建脚本的 Python 依赖 |
| `zephyr-prebuild` | 预编译 blinky（端到端验证） |
| `arm-zephyr-eabi-toolchain` 等 | 单独的工具链（GCC 16.1.0 + newlib 4.6.0） |

### 自动设置的环境变量

| 变量 | 说明 |
|------|------|
| `ZEPHYR_BASE` | Zephyr 核心源码树（profile 内自动指向） |
| `ZEPHYR_MODULES` | 全部模块路径，`;` 分隔（由 dev-env 的 search-path 汇总） |

仍需手动设置的变量（每次进 shell 后）：

| 变量 | 示例 |
|------|------|
| `CROSS_COMPILE` | `arm-zephyr-eabi-` |
| `ZEPHYR_TOOLCHAIN_VARIANT` | `cross-compile`（交叉）/ `host`（native_sim） |
| `TOOLCHAIN_HOME` | `$(dirname $(command -v <前缀>gcc))` |

## 8. 添加新 MCU 家族

以 STM32 为例，在 `ebreak/packages/zephyr.scm` 中两步完成。

**第 1 步：** 从 Zephyr 的 `west.yml` 找到 commit，先填一个假 hash 构建，Guix
会报出正确 hash，填回即可：

```bash
grep -A4 "hal_stm32" $ZEPHYR_BASE/west.yml
```

```scheme
(define-public zephyr-modules-hal-stm32
  (make-zephyr-module
   "zephyr-modules-hal-stm32"
   "STMicroelectronics STM32 HAL"
   "<commit>"                                ; west.yml 里的 revision
   "https://github.com/zephyrproject-rtos/hal_stm32"
   "0000000000000000000000000000000000000000000000000000" ; 先假后真
   "hal/stm32"))                             ; 安装目录
```

**第 2 步：** 把它加到三处：
1. `%zephyr-module-dirs` 列表（`share/zephyr-modules/hal/stm32`）
2. `zephyr-development-environment` 的 `propagated-inputs`
3. （可选）`zephyr-prebuild` 的 `native-inputs` + 一行 `(build-cross ...)`

## 9. 故障排除

### CMake 报 `No module named 'yaml'`

没传 `-DPython3_EXECUTABLE=$(command -v python3)`，CMake 找到了系统 Python。

### 模块丢失 / CMSIS 函数未定义（如 `SCB` undeclared）

1. 确认 `cmsis_6` 在 `ZEPHYR_MODULES` 里（Cortex-M 目标需要它，不是 `cmsis`）。
2. 旧构建目录里可能残留坏缓存：`rm -rf build` 后重新 configure。

### `guix build` 卡在下载 Zephyr 源码

大陆网络下 `codeload.github.com` 常被墙。模块已全部用 `git-fetch`（走
`github.com`）；Zephyr 核心源码是官方 tarball，如失败可手动下载后：

```bash
guix build zephyr-source --with-source=zephyr-4.4.2.tar.gz=./zephyr-4.4.2.tar.gz
```

### 链接器 / DTS 报奇怪的相对路径错误

`ZEPHYR_BASE` 经过了符号链接。进入 shell 后执行：

```bash
export ZEPHYR_BASE=$(readlink -f $ZEPHYR_BASE)
```

### 想看某块板有哪些可用变体

```bash
ls $ZEPHYR_BASE/boards/<vendor>/<board>/      # board.yml 列出 qualifiers
```
