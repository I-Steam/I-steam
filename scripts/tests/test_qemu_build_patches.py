#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

import patch_qemu_meson_ios
import patch_utm_qemu_ios
import verify_qemu_meson_link


class QEMUBuildPatchTests(unittest.TestCase):
    def test_qemu_meson_patch_is_idempotent_and_adds_compiler_runtime(self):
        source = (
            "project('qemu', 'c')\n"
            "config_host_data.set('CONFIG_POSIX_MEMALIGN', "
            "cc.has_function('posix_memalign', prefix: '#include <stdlib.h>'))\n"
        )
        once = patch_qemu_meson_ios.patch_source(source, "/toolchain/libclang_rt.ios.a")
        twice = patch_qemu_meson_ios.patch_source(once, "/toolchain/libclang_rt.ios.a")
        self.assertEqual(once, twice)
        self.assertIn("config_host_data.set('CONFIG_POSIX_MEMALIGN', true)", twice)
        self.assertIn("add_project_link_arguments('-Wl,-force_load,' + ios_compiler_rt, language: 'c')", twice)
        self.assertLess(twice.index("project("), twice.index("add_project_link_arguments"))

    def test_utm_patch_is_idempotent_and_verifies_actual_qemu_link(self):
        source = '''#!/bin/sh
generate_meson_cross() {
    echo "has_function_dup3 = false" >> $cross
}
QEMU_PLATFORM_BUILD_FLAGS="--enable-shared-lib --disable-cocoa --disable-sdl --disable-coreaudio --disable-slirp-smbd --enable-ucontext --with-coroutine=libucontext $HVF_FLAGS $TCI_BUILD_FLAGS"
build () {
    if [ -z "$REBUILD" ]; then
        echo "${GREEN}Configuring ${NAME}...${NC}"
        ./configure --prefix="$PREFIX" --host="$CHOST" $@
    fi
    echo "${GREEN}Building ${NAME}...${NC}"
    make -j$NCPU
}
build $QEMU_DIR --cross-prefix="" $QEMU_PLATFORM_BUILD_FLAGS $QEMU_DEBUG_FLAGS
'''
        once = patch_utm_qemu_ios.patch_script(source)
        twice = patch_utm_qemu_ios.patch_script(once)
        self.assertEqual(once, twice)
        self.assertIn("--target-list=x86_64-softmmu", twice)
        self.assertIn('python3 "$ISTEAM_QEMU_MESON_PATCHER" "$QEMU_DIR/meson.build"', twice)
        self.assertIn('python3 "$ISTEAM_QEMU_LINK_VERIFIER" "$DIR/build/build.ninja" "$IOS_COMPILER_RT"', twice)

    def test_link_verifier_requires_runtime_on_qemu_target_edge(self):
        ninja = '''build libqemu-x86_64-softmmu.dylib: c_LINKER objects
  LINK_ARGS = -Wl,-force_load,/toolchain/libclang_rt.ios.a
build unrelated.dylib: c_LINKER other
  LINK_ARGS = -lm
'''
        verify_qemu_meson_link.verify_link(ninja, "/toolchain/libclang_rt.ios.a")

    def test_link_verifier_rejects_runtime_missing_from_qemu_target_edge(self):
        ninja = '''build libqemu-x86_64-softmmu.dylib: c_LINKER objects
  LINK_ARGS = -lm
'''
        with self.assertRaises(SystemExit):
            verify_qemu_meson_link.verify_link(ninja, "/toolchain/libclang_rt.ios.a")


if __name__ == "__main__":
    unittest.main()
