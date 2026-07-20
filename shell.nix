{ pkgs ? import <nixpkgs> {} }:

let
  # LineageOS/AOSP-compatible cross toolchains via nixpkgs
  aarch64-gcc = pkgs.pkgsCross.aarch64-multiplatform.buildPackages.gcc;
  arm-gcc     = pkgs.pkgsCross.armv7l-hf-multiplatform.buildPackages.gcc;

  # Symlink farm mapping nixpkgs triples → AOSP prefixes so
  # CROSS_COMPILE=aarch64-linux-androidkernel- finds real tools.
  crossTools = pkgs.runCommand "aosp-cross-tools" {
    nativeBuildInputs = [ pkgs.coreutils ];
  } ''
    mkdir -p $out/bin
    for triple in aarch64-unknown-linux-gnu armv7l-unknown-linux-gnueabihf; do
      case "$triple" in
        aarch64*) src=${aarch64-gcc}/bin ;;
        arm*)     src=${arm-gcc}/bin ;;
      esac
      for tool in "$src"/"$triple"-*; do
        base=''$(basename "$tool")
        suffix=''${base#$triple-}
        case "$triple" in
          aarch64*)
            ln -sf "$tool" "$out/bin/aarch64-linux-androidkernel-''${suffix}"
            ln -sf "$tool" "$out/bin/aarch64-linux-android-''${suffix}"
            ln -sf "$tool" "$out/bin/aarch64-linux-gnu-''${suffix}"
            ;;
          arm*)
            ln -sf "$tool" "$out/bin/arm-linux-androidkernel-''${suffix}"
            ln -sf "$tool" "$out/bin/arm-linux-androideabi-''${suffix}"
            ln -sf "$tool" "$out/bin/arm-linux-gnueabihf-''${suffix}"
            ;;
        esac
      done
    done
  '';

in pkgs.mkShell {
  name = "android-kernel-oneplus-sdm845";

  buildInputs = with pkgs; [
    # LLVM / Clang toolchain
    clang
    lld
    llvm

    # Cross binutils + GCC (AOSP-prefixed)
    crossTools

    # ccache
    ccache

    # Kernel build dependencies
    gnumake
    flex
    bison
    bc
    perl
    python3
    which
    openssl
    zlib
    xz
    lz4
    zstd
    ncurses
    elfutils
    dtc
  ];

  # Default environment
  ARCH     = "arm64";
  SUBARCH = "arm64";

  shellHook = ''
    export ARCH=arm64
    export SUBARCH=arm64
    export LLVM=1
    export LLVM_IAS=1
    export CROSS_COMPILE=aarch64-linux-androidkernel-
    export CROSS_COMPILE_ARM32=arm-linux-androidkernel-
    export CLANG_TRIPLE=aarch64-linux-gnu-

    # ccache
    export CCACHE_DIR=''${CCACHE_DIR:-$HOME/.ccache}
    mkdir -p "$CCACHE_DIR"
    export USE_CCACHE=1

    # transparent ccache via PATH
    mkdir -p "$CCACHE_DIR/bin"
    for c in clang clang++; do
      [ -L "$CCACHE_DIR/bin/$c" ] || ln -sf "$(command -v ccache)" "$CCACHE_DIR/bin/$c"
    done
    export PATH="$CCACHE_DIR/bin:$PATH"
  '';
}
