#!/usr/bin/env bash
set -euo pipefail

: "${KSU_CONFIG:?KSU_CONFIG must point to the approved Kconfig fragment}"
: "${KBUILD_JOBS:?KBUILD_JOBS must be fixed by the workflow}"

KSU_CONFIG_PATH="${KSU_CONFIG_PATH:-arch/arm64/configs/vendor/xiaomi/equuleus-resukisu.config}"

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

baseline_build_script_sha256="$(sha256sum build_for_equuleus.sh | awk '{print $1}')"
cp "$KSU_CONFIG" "$KSU_CONFIG_PATH"
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
@@ -56,1 +56,8 @@
-scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${VIRTIO_CONFIG}"
+scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${VIRTIO_CONFIG}"
+scripts/kconfig/merge_config.sh -O "${OUT_DIR}/" "${OUT_DIR}/.config" "${KSU_CONFIG_PATH}"
+grep -qx 'CONFIG_KSU=y' "${OUT_DIR}/.config"
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
grep -Fqx 'make -j"${KBUILD_JOBS:-4}" -Orecurse O="${OUT_DIR}" ARCH=arm64 \' build_for_equuleus.sh
grep -Fqx $'\t\tzip -rFS9 "ak3-equuleus.zip" . -x .git README.md "ak3-*.zip"' build_for_equuleus.sh

export KSU_CONFIG_PATH
bash build_for_equuleus.sh

test -s out/.config
grep -qx 'CONFIG_KSU=y' out/.config
grep -qx 'CONFIG_KSU_MANUAL_HOOK=y' out/.config
if grep -Eq '^CONFIG_KSU_SUSFS(_[A-Za-z0-9_]+)?=y$' out/.config; then
  echo 'The SUSFS family must be disabled for the approved Manual Hook build.' >&2
  exit 1
fi

test -s out/arch/arm64/boot/Image.gz-dtb
test -s AnyKernel3/ak3-equuleus.zip

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    printf 'BUILD_ADAPTER_SHA256=%s\n' "$(sha256sum "$0" | awk '{print $1}')"
    printf 'BASELINE_BUILD_SCRIPT_SHA256=%s\n' "$baseline_build_script_sha256"
    printf 'BUILD_SOURCE_COMPAT_PATCH=fs/namei.c:tmp-fallback-to-pathname\n'
    printf 'KBUILD_JOBS=%s\n' "$KBUILD_JOBS"
  } >> "$GITHUB_ENV"
fi
