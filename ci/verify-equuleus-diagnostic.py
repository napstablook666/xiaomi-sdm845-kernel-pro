#!/usr/bin/env python3
"""Offline checks for the equuleus ReSukiSU diagnostic artifact.

The optional boot backup is read only. Its command line is transformed in
memory to model AnyKernel3's patch_cmdline call; no boot image is repacked.

DTB order is expressed with the real pinned Kbuild source stems. The older
artifact descriptions used model labels such as ``sdm845-v1-cdp`` and
``sdm845-v1-mtp``; those are not source filenames in this tree.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
import tempfile
import zipfile
import zlib
from pathlib import Path

EXPECTED_DTB_ORDER = (
    "sdm845-v2-mtp",
    "sdm845-rumi",
    "sdm845-v2-cdp",
    "equuleus-p1-v2.1",
    "sdm845-qrd",
    "sdm845-4k-panel-qrd",
    "sdm845-cdp",
    "equuleus-p0-v2",
    "equuleus-mp-v2.1",
    "sdm845-4k-panel-cdp",
    "sdm845-4k-panel-mtp",
    "sdm845-v2-qrd",
    "equuleus-p1-v2",
    "equuleus-p0-v2.1",
    "equuleus-mp-v2",
    "sdm845-v2-rumi",
    "sdm845-mtp",
    "sdm845-sim",
)
EXPECTED_DTB_TAIL_SIZE = 7_596_122
PREINIT_KEY = "preinit"
PREINIT_REPLACEMENT = "preinit=0"
PREINIT_PATCH = 'patch_cmdline preinit "preinit=0";'
FDT_MAGIC = 0xD00DFEED
ANDROID_MAGIC = b"ANDROID!"
ANDROID_PAGE_SIZE_OFFSET = 0x24
ANDROID_KERNEL_SIZE_OFFSET = 0x08
ANDROID_CMDLINE_OFFSET = 0x40
ANDROID_CMDLINE_SIZE = 512
ANDROID_EXTRA_CMDLINE_OFFSET = 0x260
ANDROID_EXTRA_CMDLINE_SIZE = 1024
ANDROID_HEADER_SIZE_OFFSET = 0x66C
ANDROID_HEADER_SIZE_V1 = 0x670


class VerificationError(RuntimeError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_gzip_kernel_and_dtb_tail(image: bytes) -> tuple[bytes, bytes]:
    decompressor = zlib.decompressobj(16 + zlib.MAX_WBITS)
    try:
        kernel = decompressor.decompress(image) + decompressor.flush()
    except zlib.error as exc:
        raise VerificationError(f"Image.gz-dtb is not a valid gzip stream: {exc}") from exc
    if not decompressor.eof:
        raise VerificationError("Image.gz-dtb gzip member is truncated")
    tail = decompressor.unused_data
    if not tail:
        raise VerificationError("Image.gz-dtb has no appended DTB tail")
    return kernel, tail


def parse_dtb_tail(tail: bytes) -> list[bytes]:
    blobs = []
    offset = 0
    while offset < len(tail):
        if len(tail) - offset < 8:
            raise VerificationError(f"truncated FDT header at tail offset {offset}")
        magic, total_size = struct.unpack_from(">II", tail, offset)
        if magic != FDT_MAGIC:
            raise VerificationError(
                f"bad FDT magic at tail offset {offset}: 0x{magic:08x}"
            )
        if total_size < 40 or offset + total_size > len(tail):
            raise VerificationError(
                f"invalid FDT size {total_size} at tail offset {offset}"
            )
        blobs.append(tail[offset : offset + total_size])
        offset += total_size
    return blobs


def source_dtbs(dtb_dir: Path) -> dict[str, bytes]:
    """Read generated DTBs by their actual relative Kbuild source stem."""
    result = {}
    for path in sorted(dtb_dir.rglob("*.dtb")):
        relative_name = path.relative_to(dtb_dir).as_posix()
        if "/" in relative_name:
            raise VerificationError(
                f"DTB source directory contains nested artifact: {relative_name}"
            )
        name = path.stem
        if name in result:
            raise VerificationError(f"duplicate DTB source name: {name}")
        result[name] = path.read_bytes()
    if not result:
        raise VerificationError(f"no .dtb files found below {dtb_dir}")
    return result


def source_dtbs_by_hash(source: dict[str, bytes]) -> dict[str, str]:
    """Map source DTB hashes, rejecting ambiguous duplicate content."""
    result = {}
    for name, data in source.items():
        digest = sha256(data)
        previous = result.get(digest)
        if previous is not None:
            raise VerificationError(
                f"duplicate DTB source hash {digest}: {previous} and {name}"
            )
        result[digest] = name
    return result


def verify_dtbs(image: bytes, dtb_dir: Path) -> tuple[int, str, str, str]:
    _, tail = read_gzip_kernel_and_dtb_tail(image)
    if len(tail) != EXPECTED_DTB_TAIL_SIZE:
        raise VerificationError(
            f"DTB tail size {len(tail)} != {EXPECTED_DTB_TAIL_SIZE}"
        )
    blobs = parse_dtb_tail(tail)
    if len(blobs) != len(EXPECTED_DTB_ORDER):
        raise VerificationError(f"found {len(blobs)} DTBs, expected 18")

    source = source_dtbs(dtb_dir)
    expected_names = set(EXPECTED_DTB_ORDER)
    if set(source) != expected_names:
        missing = sorted(expected_names - set(source))
        extra = sorted(set(source) - expected_names)
        raise VerificationError(
            f"generated DTB source set mismatch: missing={missing}, extra={extra}"
        )

    source_by_hash = source_dtbs_by_hash(source)
    actual_order = []
    hashes = []
    for index, blob in enumerate(blobs, 1):
        digest = sha256(blob)
        name = source_by_hash.get(digest)
        if name is None:
            raise VerificationError(
                f"DTB {index} does not match any generated source .dtb by SHA-256"
            )
        actual_order.append(name)
        hashes.append(f"{name}.dtb={digest}")

    if tuple(actual_order) != EXPECTED_DTB_ORDER:
        differences = "\n".join(
            f"  {index}: expected {expected}, got {actual}"
            for index, (expected, actual) in enumerate(
                zip(EXPECTED_DTB_ORDER, actual_order), 1
            )
            if expected != actual
        )
        raise VerificationError(f"DTB order mismatch:\n{differences}")
    return (
        len(tail),
        sha256(tail),
        " ".join(f"{name}.dtb" for name in actual_order),
        " ".join(hashes),
    )


def package_files(package: Path) -> bytes:
    try:
        with zipfile.ZipFile(package) as archive:
            bad = archive.testzip()
            if bad is not None:
                raise VerificationError(f"ZIP integrity check failed at {bad}")
            image = archive.read("Image.gz-dtb")
            script = archive.read("anykernel.sh").decode("utf-8")
    except KeyError as exc:
        raise VerificationError(f"ZIP is missing {exc.args[0]}") from exc
    except UnicodeDecodeError as exc:
        raise VerificationError("AnyKernel3 script is not UTF-8") from exc
    except zipfile.BadZipFile as exc:
        raise VerificationError(f"invalid AnyKernel3 ZIP: {exc}") from exc

    lines = script.splitlines()
    if lines.count(PREINIT_PATCH) != 1:
        raise VerificationError("AnyKernel3 script must contain exactly one preinit patch")
    if lines.count("dump_boot;") != 1 or lines.count("write_boot;") != 1:
        raise VerificationError("AnyKernel3 script must contain one dump_boot and one write_boot")
    patch_line = lines.index(PREINIT_PATCH)
    dump_line = lines.index("dump_boot;")
    write_line = lines.index("write_boot;")
    if not dump_line < patch_line < write_line:
        raise VerificationError("preinit patch is not between dump_boot and write_boot")
    return image


def read_boot_cmdline(backup: bytes) -> tuple[str, int]:
    if len(backup) < ANDROID_HEADER_SIZE_V1 or backup[:8] != ANDROID_MAGIC:
        raise VerificationError("boot backup is not an Android boot image")
    page_size = struct.unpack_from("<I", backup, ANDROID_PAGE_SIZE_OFFSET)[0]
    header_size = struct.unpack_from("<I", backup, ANDROID_HEADER_SIZE_OFFSET)[0]
    kernel_size = struct.unpack_from("<I", backup, ANDROID_KERNEL_SIZE_OFFSET)[0]
    if page_size == 0 or page_size & (page_size - 1):
        raise VerificationError(f"invalid Android page size {page_size}")
    if header_size != ANDROID_HEADER_SIZE_V1:
        raise VerificationError(
            f"expected Android boot header v1 size 0x{ANDROID_HEADER_SIZE_V1:x}, "
            f"got 0x{header_size:x}"
        )
    if kernel_size == 0:
        raise VerificationError("boot backup has no kernel data")
    first = backup[ANDROID_CMDLINE_OFFSET : ANDROID_CMDLINE_OFFSET + ANDROID_CMDLINE_SIZE]
    extra = backup[
        ANDROID_EXTRA_CMDLINE_OFFSET :
        ANDROID_EXTRA_CMDLINE_OFFSET + ANDROID_EXTRA_CMDLINE_SIZE
    ]
    fields = [
        field
        for field in (first.split(b"\0", 1)[0], extra.split(b"\0", 1)[0])
        if field
    ]
    raw = b" ".join(fields)
    try:
        return raw.decode("ascii"), page_size
    except UnicodeDecodeError as exc:
        raise VerificationError("boot command line is not ASCII") from exc


def patch_preinit_cmdline(command_line: str) -> str:
    """Model ak3-core.sh's grep/sed matching for the fixed key ``preinit``."""
    tokens = command_line.split()
    for index, token in enumerate(tokens):
        match_start = token.find(PREINIT_KEY)
        if match_start >= 0:
            tokens[index] = token[:match_start] + PREINIT_REPLACEMENT
            return " ".join(tokens)
    tokens.append(PREINIT_REPLACEMENT)
    return " ".join(tokens)


def assert_cmdline_preserved(original: str, transformed: str) -> None:
    before = original.split()
    after = transformed.split()
    match_index = next(
        (index for index, token in enumerate(before) if PREINIT_KEY in token),
        None,
    )
    if match_index is None:
        if after != before + [PREINIT_REPLACEMENT]:
            raise VerificationError("preinit model changed a token while appending")
        return
    expected_token = before[match_index]
    expected_token = expected_token[: expected_token.find(PREINIT_KEY)] + PREINIT_REPLACEMENT
    if len(after) != len(before) or after[match_index] != expected_token:
        raise VerificationError("preinit model changed the matching token incorrectly")
    if (
        after[:match_index] != before[:match_index]
        or after[match_index + 1 :] != before[match_index + 1 :]
    ):
        raise VerificationError("preinit model changed a non-preinit command-line token")


def verify_boot_model(backup_path: Path) -> tuple[str, str, str]:
    before = backup_path.read_bytes()
    before_hash = sha256(before)
    original, page_size = read_boot_cmdline(before)
    transformed = patch_preinit_cmdline(original)
    assert_cmdline_preserved(original, transformed)
    if transformed.split().count(PREINIT_REPLACEMENT) != 1:
        raise VerificationError("modeled command line lacks exactly one preinit=0")
    if sha256(backup_path.read_bytes()) != before_hash:
        raise VerificationError("boot backup changed during offline verification")
    return before_hash, transformed, str(page_size)


def verify(args: argparse.Namespace) -> list[str]:
    image = args.image.read_bytes()
    package_image = package_files(args.package)
    if image != package_image:
        raise VerificationError("generated Image.gz-dtb differs from ZIP Image.gz-dtb")
    tail_size, tail_hash, dtb_order, dtb_hashes = verify_dtbs(image, args.dtb_dir)
    report = [
        f"image_sha256={sha256(image)}",
        f"zip_sha256={sha256(args.package.read_bytes())}",
        "zip_integrity=pass",
        "packaged_image=byte-equal",
        f"dtb_tail_size={tail_size}",
        f"dtb_tail_sha256={tail_hash}",
        f"dtb_order={dtb_order}",
        f"dtb_hashes={dtb_hashes}",
        "preinit_script=patch_cmdline preinit=0 between dump_boot/write_boot",
    ]
    if args.boot_backup is None:
        report.append(
            "boot_cmdline_model=deferred (local post-download verification required; "
            "no --boot-backup supplied; no image repacked)"
        )
    else:
        backup_hash, transformed, page_size = verify_boot_model(args.boot_backup)
        report += [
            "boot_cmdline_model=modeled-only (source backup unchanged; no image repacked)",
            f"boot_backup_sha256={backup_hash}",
            f"boot_page_size={page_size}",
            "boot_cmdline_tokens=preinit=0 exactly once; other tokens unchanged",
            f"modeled_cmdline={transformed}",
        ]
    return report


def synthetic_boot_image(command_line: str, extra_command_line: str = "") -> bytes:
    image = bytearray(4096)
    image[:8] = ANDROID_MAGIC
    struct.pack_into("<I", image, ANDROID_KERNEL_SIZE_OFFSET, 1)
    struct.pack_into("<I", image, ANDROID_PAGE_SIZE_OFFSET, 4096)
    struct.pack_into("<I", image, ANDROID_HEADER_SIZE_OFFSET, ANDROID_HEADER_SIZE_V1)
    encoded = command_line.encode("ascii")
    extra_encoded = extra_command_line.encode("ascii")
    image[ANDROID_CMDLINE_OFFSET : ANDROID_CMDLINE_OFFSET + len(encoded)] = encoded
    image[
        ANDROID_EXTRA_CMDLINE_OFFSET :
        ANDROID_EXTRA_CMDLINE_OFFSET + len(extra_encoded)
    ] = extra_encoded
    return bytes(image)


def self_check() -> None:
    def fake_dtb(marker: int) -> bytes:
        return struct.pack(">II", FDT_MAGIC, 40) + bytes([marker]) * 32

    assert patch_preinit_cmdline(
        "console=tty preinit=1 androidboot.hardware=qcom"
    ) == "console=tty preinit=0 androidboot.hardware=qcom"
    assert patch_preinit_cmdline("console=tty") == "console=tty preinit=0"
    assert patch_preinit_cmdline("foo=preinit=1 bar=2") == "foo=preinit=0 bar=2"
    assert parse_dtb_tail(fake_dtb(1) + fake_dtb(2)) == [fake_dtb(1), fake_dtb(2)]
    try:
        source_dtbs_by_hash({"first": b"same", "second": b"same"})
    except VerificationError:
        pass
    else:
        raise AssertionError("duplicate source DTB hashes must be rejected")

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        dtb_dir = root / "out" / "arch" / "arm64" / "boot" / "dts" / "qcom"
        dtb_dir.mkdir(parents=True)
        for index, name in enumerate(EXPECTED_DTB_ORDER):
            (dtb_dir / f"{name}.dtb").write_bytes(fake_dtb(index))
        assert set(source_dtbs(dtb_dir)) == set(EXPECTED_DTB_ORDER)

        kernel = b"synthetic kernel"
        tail = b"".join(
            (dtb_dir / f"{name}.dtb").read_bytes() for name in EXPECTED_DTB_ORDER
        )
        compressor = zlib.compressobj(wbits=16 + zlib.MAX_WBITS)
        synthetic_image = compressor.compress(kernel) + compressor.flush() + tail
        assert read_gzip_kernel_and_dtb_tail(synthetic_image) == (kernel, tail)

        package = root / "diagnostic.zip"
        with zipfile.ZipFile(package, "w") as archive:
            archive.writestr("Image.gz-dtb", synthetic_image)
            archive.writestr(
                "anykernel.sh",
                "dump_boot;\n" + PREINIT_PATCH + "\nwrite_boot;\n",
            )
        assert package_files(package) == synthetic_image

        absent_backup = root / "absent-preinit.img"
        absent_backup.write_bytes(
            synthetic_boot_image("console=tty", "androidboot.hardware=qcom")
        )
        assert read_boot_cmdline(absent_backup.read_bytes()) == (
            "console=tty androidboot.hardware=qcom",
            4096,
        )
        absent_hash, absent_model, _ = verify_boot_model(absent_backup)
        assert absent_model.endswith("preinit=0")
        assert sha256(absent_backup.read_bytes()) == absent_hash

        existing_backup = root / "existing-preinit.img"
        existing_backup.write_bytes(
            synthetic_boot_image("console=tty preinit=1 androidboot.hardware=qcom")
        )
        _, existing_model, _ = verify_boot_model(existing_backup)
        assert existing_model == "console=tty preinit=0 androidboot.hardware=qcom"

    print("self-check: pass")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--dtb-dir", type=Path)
    parser.add_argument("--boot-backup", type=Path)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    try:
        if args.self_check:
            self_check()
            return 0
        if args.image is None or args.package is None or args.dtb_dir is None:
            parser.error("--image, --package, and --dtb-dir are required unless --self-check is used")
        for path in (args.image, args.package, args.dtb_dir, args.boot_backup):
            if path is not None and not path.exists():
                raise VerificationError(f"path does not exist: {path}")
        for line in verify(args):
            print(line)
        return 0
    except VerificationError as exc:
        print(f"verification failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
