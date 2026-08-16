#!/bin/bash
# Verify that the packaged Zephyr environment can build firmware for the
# supported targets:
#   RP2040      (rpi_pico)                   - ARM Cortex-M0+
#   RP2350 ARM  (rpi_pico2/rp2350a/m33)      - ARM Cortex-M33
#   RP2350 RV   (rpi_pico2/rp2350a/hazard3)  - RISC-V Hazard3
#   RPi 4B      (rpi_4b)                     - AArch64 Cortex-A72
#   CH32V307    (ch32v307v_evt_r1)           - RISC-V QingKe V4F
#   native_sim  (native_sim/native/64)       - host toolchain
#
# Run inside the environment:
#   guix shell [-L <channel-checkout>] zephyr-development-environment \
#     -- bash verify-zephyr-builds.sh
set -eu

SAMPLE=samples/basic/blinky
: "${ZEPHYR_BASE:?not set; run inside 'guix shell zephyr-development-environment'}"
ZEPHYR_BASE=$(readlink -f "$ZEPHYR_BASE")
PY=$(command -v python3)

# Zephyr 4.4.2's hazard3 board variant is missing the common LED include;
# supply it via overlay (same as zephyr-prebuild does).
HAZARD3_OVERLAY=$PWD/rp2350-hazard3-led.overlay
cat > "$HAZARD3_OVERLAY" <<'EOF'
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
EOF

build_cross() {
    local label=$1 board=$2 prefix=$3
    shift 3
    echo ""
    echo "==> Building $label ($board) with CROSS_COMPILE=$prefix"
    rm -rf "build-$label"
    export CROSS_COMPILE="$prefix"
    export ZEPHYR_TOOLCHAIN_VARIANT=cross-compile
    export TOOLCHAIN_HOME
    TOOLCHAIN_HOME=$(dirname "$(command -v "${prefix}gcc")")
    cmake -B "build-$label" -GNinja \
        -DBOARD="$board" \
        -DTOOLCHAIN_HOME="$TOOLCHAIN_HOME" \
        -DPython3_EXECUTABLE="$PY" \
        "$@" "$ZEPHYR_BASE/$SAMPLE"
    ninja -C "build-$label"
    report "$label" zephyr.elf zephyr.uf2 zephyr.bin
}

build_native() {
    local label=$1 board=$2
    echo ""
    echo "==> Building $label ($board) with host toolchain"
    rm -rf "build-$label"
    unset CROSS_COMPILE TOOLCHAIN_HOME
    export ZEPHYR_TOOLCHAIN_VARIANT=host
    cmake -B "build-$label" -GNinja \
        -DBOARD="$board" \
        -DPython3_EXECUTABLE="$PY" \
        "$ZEPHYR_BASE/$SAMPLE"
    ninja -C "build-$label"
    report "$label" zephyr.elf
}

report() {
    local label=$1
    shift
    for f in "$@"; do
        [ -f "build-$label/zephyr/$f" ] || continue
        printf '==> %s OK: %s (%s bytes)\n' \
            "$label" "$f" "$(stat -c %s "build-$label/zephyr/$f")"
    done
}

build_cross rp2040       rpi_pico               arm-zephyr-eabi-
build_cross rp2350-arm   rpi_pico2/rp2350a/m33  arm-zephyr-eabi-
build_cross rp2350-riscv rpi_pico2/rp2350a/hazard3 riscv64-zephyr-elf- \
    -DEXTRA_DTC_OVERLAY_FILE="$HAZARD3_OVERLAY"
build_cross ch32v307     ch32v307v_evt_r1       riscv64-zephyr-elf-
build_cross rpi4b        rpi_4b                 aarch64-zephyr-elf-
build_native native-sim  native_sim/native/64

echo ""
echo "==> All builds completed successfully."
