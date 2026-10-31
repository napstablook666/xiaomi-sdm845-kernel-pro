#!/usr/bin/env bash
set -euo pipefail

: "${KSU_CONFIG:?KSU_CONFIG must point to the approved Kconfig fragment}"
: "${KBUILD_JOBS:?KBUILD_JOBS must be fixed by the workflow}"

KSU_CONFIG_PATH="${KSU_CONFIG_PATH:-arch/arm64/configs/vendor/xiaomi/equuleus-resukisu.config}"
DIAGNOSTIC_MODE="${DIAGNOSTIC_MODE:-0}"
# These are real qcom/*.dts stems from the pinned Makefile. The order matches
# the known-good UAPI 5 Image.gz-dtb tail, not the DT model descriptions.
DIAGNOSTIC_DTB_ORDER='sdm845-v2-mtp sdm845-rumi sdm845-v2-cdp equuleus-p1-v2.1 sdm845-qrd sdm845-4k-panel-qrd sdm845-cdp equuleus-p0-v2 equuleus-mp-v2.1 sdm845-4k-panel-cdp sdm845-4k-panel-mtp sdm845-v2-qrd equuleus-p1-v2 equuleus-p0-v2.1 equuleus-mp-v2 sdm845-v2-rumi sdm845-mtp sdm845-sim'

case "$DIAGNOSTIC_MODE" in
  0|1) ;;
  *)
    echo "DIAGNOSTIC_MODE must be 0 or 1" >&2
    exit 1
    ;;
esac

case "$KBUILD_JOBS" in
  ''|*[!0-9]*)
    echo "KBUILD_JOBS must be a positive integer" >&2
    exit 1
    ;;
  0)
    echo "KBUILD_JOBS must be greater than zero" >&2
    exit 1
    ;;
esac

test -f build_for_equuleus.sh
test -f fs/namei.c
test -f "$KSU_CONFIG"
test -f AnyKernel3/anykernel.sh

if ! grep -qx 'CONFIG_KSU=y' "$KSU_CONFIG" || \
   ! grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' "$KSU_CONFIG" || \
   grep -Eq '^CONFIG_KSU_SUSFS(_[A-Za-z0-9_]+)?=y$' "$KSU_CONFIG"; then
  echo "KSU fragment does not match the approved Manual Hook configuration" >&2
  exit 1
fi

read -r -a diagnostic_dtb_names <<< "$DIAGNOSTIC_DTB_ORDER"
test "${#diagnostic_dtb_names[@]}" -eq 18
for diagnostic_dtb_name in "${diagnostic_dtb_names[@]}"; do
  test -f "arch/arm64/boot/dts/qcom/${diagnostic_dtb_name}.dts"
done
# CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES is relative to arch/arm64/boot,
# so each entry must include the qcom/ subdirectory.
diagnostic_dtb_kconfig_order="$(printf 'qcom/%s ' "${diagnostic_dtb_names[@]}")"
diagnostic_dtb_kconfig_order="${diagnostic_dtb_kconfig_order% }"

test "$(wc -w <<< "$diagnostic_dtb_kconfig_order")" -eq 18
test "$(grep -o 'qcom/' <<< "$diagnostic_dtb_kconfig_order" | wc -l)" -eq 18

baseline_build_script_sha256="$(sha256sum build_for_equuleus.sh | awk '{print $1}')"
cp "$KSU_CONFIG" "$KSU_CONFIG_PATH"
if [[ "$DIAGNOSTIC_MODE" == 1 ]]; then
  diagnostic_config_fragment="$(mktemp)"
  cat > "$diagnostic_config_fragment" <<EOF
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
# CONFIG_KSU_SUSFS is not set
CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="$diagnostic_dtb_kconfig_order"
EOF
  cat "$diagnostic_config_fragment" >> "$KSU_CONFIG_PATH"
  rm -f "$diagnostic_config_fragment"
fi
rm -f AnyKernel3/ak3-equuleus.zip AnyKernel3/Image.gz-dtb

# DEC-1 enforces the mutually exclusive top-level Kconfig choice.
# Kconfig resolves dependent SUSFS children when that choice is off.
# The baseline declares tmp only for SUSFS open redirect, but uses pathname when
# that feature is disabled. Keep Manual Hook semantics by making that fallback explicit.
patch --fuzz=0 --forward --batch -p0 <<'PATCH'
--- fs/namei.c
+++ fs/namei.c
@@ -3791,11 +3791,11 @@
-	int flags = op->lookup_flags;
-	struct file *filp;
-#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
-	struct filename *fake_filename = NULL;
-	struct filename *tmp = pathname;
-	bool is_inode_open_redirect = false;
-
-retry:
-#endif
-
-	set_nameidata(&nd, dfd, tmp);
+	int flags = op->lookup_flags;
+	struct file *filp;
+	struct filename *tmp = pathname;
+#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
+	struct filename *fake_filename = NULL;
+	bool is_inode_open_redirect = false;
+
+retry:
+#endif
+
+	set_nameidata(&nd, dfd, tmp);
--- build_for_equuleus.sh
+++ build_for_equuleus.sh
@@ -56,1 +56,11 @@
-scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${VIRTIO_CONFIG}"
+scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${VIRTIO_CONFIG}"
+scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${KSU_CONFIG_PATH}"
+grep -qx 'CONFIG_KSU=y' "${OUT_DIR}/.config"
+make -f scripts/Makefile.asm-generic srctree=. SRCARCH=arm64 src=asm obj="${OUT_DIR}/arch/arm64/include/generated/asm"
+make -f scripts/Makefile.asm-generic srctree=. SRCARCH=arm64 src=uapi/asm obj="${OUT_DIR}/arch/arm64/include/generated/uapi/asm"
+make O="${OUT_DIR}" ARCH=arm64 CC="${CC}" CC_ARM32="arm-linux-gnueabihf-gcc" CROSS_COMPILE="${CROSS_COMPILE}" CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" CROSS_COMPILE_COMPAT="${CROSS_COMPILE_COMPAT}" LLVM_IAS="${LLVM_IAS}" prepare scripts
+grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' "${OUT_DIR}/.config"
+if grep -Eq '^CONFIG_KSU_SUSFS(_[A-Za-z0-9_]+)?=y$' "${OUT_DIR}/.config"; then
+	echo 'The SUSFS family must be disabled for the approved Manual Hook build.' >&2
+	exit 1
+fi
@@ -58,1 +65,1 @@
-make -j"$(nproc)" -Orecurse O="${OUT_DIR}" ARCH=arm64 \
+make -j"${KBUILD_JOBS:-4}" -Orecurse O="${OUT_DIR}" ARCH=arm64 \
@@ -85,1 +92,1 @@
-		zip -r9 "ak3-equuleus.zip" . -x .git README.md "ak3-*.zip"
+		zip -rFS9 "ak3-equuleus.zip" . -x .git README.md "ak3-*.zip"
PATCH

test "$(grep -c '^struct file \*do_filp_open' fs/namei.c)" -eq 1
grep -A8 -F 'struct file *do_filp_open' fs/namei.c | grep -Fqx $'\tstruct filename *tmp = pathname;'
grep -Fqx 'scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${KSU_CONFIG_PATH}"' build_for_equuleus.sh
grep -Fqx 'make -f scripts/Makefile.asm-generic srctree=. SRCARCH=arm64 src=asm obj="${OUT_DIR}/arch/arm64/include/generated/asm"' build_for_equuleus.sh
grep -Fqx 'make -f scripts/Makefile.asm-generic srctree=. SRCARCH=arm64 src=uapi/asm obj="${OUT_DIR}/arch/arm64/include/generated/uapi/asm"' build_for_equuleus.sh
grep -Fqx 'make O="${OUT_DIR}" ARCH=arm64 CC="${CC}" CC_ARM32="arm-linux-gnueabihf-gcc" CROSS_COMPILE="${CROSS_COMPILE}" CROSS_COMPILE_ARM32="${CROSS_COMPILE_ARM32}" CROSS_COMPILE_COMPAT="${CROSS_COMPILE_COMPAT}" LLVM_IAS="${LLVM_IAS}" prepare scripts' build_for_equuleus.sh
grep -Fqx 'make -j"${KBUILD_JOBS:-4}" -Orecurse O="${OUT_DIR}" ARCH=arm64 \' build_for_equuleus.sh
grep -Fqx $'\t\tzip -rFS9 "ak3-equuleus.zip" . -x .git README.md "ak3-*.zip"' build_for_equuleus.sh

if [[ "$DIAGNOSTIC_MODE" == 1 ]]; then
  test "$(grep -c '^dump_boot;$' AnyKernel3/anykernel.sh)" -eq 1
  test "$(grep -c '^write_boot;$' AnyKernel3/anykernel.sh)" -eq 1
  test "$(grep -Fc 'patch_cmdline preinit "preinit=0";' AnyKernel3/anykernel.sh)" -eq 0
  sed -i '/^dump_boot;$/a patch_cmdline preinit "preinit=0";' AnyKernel3/anykernel.sh
  test "$(grep -Fc 'patch_cmdline preinit "preinit=0";' AnyKernel3/anykernel.sh)" -eq 1
  test "$(grep -n '^dump_boot;$' AnyKernel3/anykernel.sh | cut -d: -f1)" -lt \
    "$(grep -n 'patch_cmdline preinit "preinit=0";' AnyKernel3/anykernel.sh | cut -d: -f1)"
  test "$(grep -n 'patch_cmdline preinit "preinit=0";' AnyKernel3/anykernel.sh | cut -d: -f1)" -lt \
    "$(grep -n '^write_boot;$' AnyKernel3/anykernel.sh | cut -d: -f1)"
else
  test "$(grep -Fc 'patch_cmdline preinit "preinit=0";' AnyKernel3/anykernel.sh)" -eq 0
fi

export KSU_CONFIG_PATH
bash build_for_equuleus.sh

test -s out/.config
grep -qx 'CONFIG_KSU=y' out/.config
grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' out/.config
if grep -Eq '^CONFIG_KSU_SUSFS(_[A-Za-z0-9_]+)?=y$' out/.config; then
  echo 'The SUSFS family must be disabled for the approved Manual Hook build.' >&2
  exit 1
fi
if [[ "$DIAGNOSTIC_MODE" == 1 ]]; then
  grep -Fqx "CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES=\"$diagnostic_dtb_kconfig_order\"" out/.config
fi

test -s out/arch/arm64/boot/Image.gz-dtb
test -s AnyKernel3/ak3-equuleus.zip
if [[ "$DIAGNOSTIC_MODE" == 1 ]]; then
  unzip -p AnyKernel3/ak3-equuleus.zip anykernel.sh | grep -Fqx 'patch_cmdline preinit "preinit=0";'
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    printf 'BUILD_ADAPTER_SHA256=%s\n' "$(sha256sum "$0" | awk '{print $1}')"
    printf 'BASELINE_BUILD_SCRIPT_SHA256=%s\n' "$baseline_build_script_sha256"
    printf 'BUILD_SOURCE_COMPAT_PATCH=fs/namei.c:tmp-fallback-to-pathname;build_for_equuleus.sh:prepare-scripts-before-build+vdso32-gcc\n'
    printf 'KBUILD_JOBS=%s\n' "$KBUILD_JOBS"
    printf 'DIAGNOSTIC_MODE=%s\n' "$DIAGNOSTIC_MODE"
    if [[ "$DIAGNOSTIC_MODE" == 1 ]]; then
      printf 'DIAGNOSTIC_DTB_ORDER=%s\n' "$DIAGNOSTIC_DTB_ORDER"
      printf 'DIAGNOSTIC_DTB_KCONFIG_ORDER=%s\n' "$diagnostic_dtb_kconfig_order"
      printf 'DIAGNOSTIC_DTB_TAIL_SIZE=7596122\n'
      printf 'DIAGNOSTIC_PREINIT=preinit=0\n'
    fi
  } >> "$GITHUB_ENV"
fi
