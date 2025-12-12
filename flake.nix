{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
    self,
    rust-overlay,
    flake-utils,
    nixpkgs,
    }:
    flake-utils.lib.eachDefaultSystem (system: let 
      pkgs = nixpkgs.legacyPackages.${system};
    in
      # TODO: Make this use the toolchain file for more compatibility
      {
      devShells.default =
        let
          pkgsCross = pkgs.pkgsCross.aarch64-multiplatform;
          musl = pkgsCross.musl;
          platformDeps = (if pkgs.stdenv.isDarwin then with pkgsCross; [ 
            libiconv 
          ] else with pkgsCross; [ 
              libdrm.dev 
              libdecor.dev
              mesa
            ]);
          # sdl2-musl = pkgs.sdl3.overrideAttrs (old: {
          sdl2-musl = pkgsCross.SDL2;
          # sdl2-musl = pkgsCross.SDL2.override {
          #   stdenv = pkgsCross.pkgsStatic.stdenv;
          #
          #   sdl3 = pkgsCross.sdl3.override {
          #     stdenv = pkgsCross.pkgsStatic.stdenv;
          #     alsaSupport = false;
          #     dbusSupport = false;
          #     drmSupport = false;
          #     ibusSupport = false;
          #     jackSupport = false;
          #     libdecorSupport = false;
          #     openglSupport = false;
          #     pipewireSupport = false;
          #     pulseaudioSupport = false;
          #     libudevSupport = false;
          #     sndioSupport = false;
          #     traySupport = false;
          #     waylandSupport = false;
          #     x11Support = false;
          #
          #     # tray, etc.
          #     # traySupport = false;
          #
          #     # tests / examples (avoid needing go/test tools)
          #     # doCheck = false;
          #     # checkPhase = ""; # skip tests
          #     #
          #     # # avoid optional deps which bring in systemd, caps, etc.
          #     # enableSystemd = false;
          #     # enableSystemdSupport = false;
          #   };
          # };
          rust-bin = rust-overlay.lib.mkRustBin { } pkgsCross.buildPackages;
          in
            pkgsCross.callPackage ( { mkShell, pkg-config, qemu, openssl, stdenv, }:
          mkShell {
            nativeBuildInputs = with pkgsCross; [
              (rust-bin.fromRustupToolchainFile ./toolchain.toml)
                pkg-config
                xkeyboard_config
                xorg.libX11.dev
                xorg.libXau.dev
                xorg.libXdmcp.dev
                xorg.libfontenc.out
                xorg.libICE.dev
                xorg.libSM.dev
                libuuid.dev
                xorg.libXaw.dev
                xorg.libXext.dev
                xorg.libXpm.dev
                xorg.libXcomposite.dev
                xorg.libXcursor.dev
                xorg.libXrender.dev
                xorg.libXdamage.dev
                xorg.libXi.dev
                xorg.libXinerama.dev
                xorg.libxkbfile.dev
                xorg.libXrandr.dev
                xorg.libXres.dev
                xorg.libXScrnSaver.out
                xorg.libXtst.out
                xorg.libXv.dev
                xorg.libXxf86vm.dev
                xorg.xcbutilwm.dev
                xorg.xcbutilimage.dev
                xorg.xcbutilkeysyms.dev
                xorg.xcbutilrenderutil.dev
                xorg.xcbutil.dev
                xcb-util-cursor.dev
                xorg.xmodmap
                xorg.xev
                libGL.dev
                SDL2
                SDL2.dev
              ] ++ platformDeps;

              depsBuildBuild = [ qemu ];

              buildInputs = with pkgsCross; [ 
                pkg-config
                openssl 
                pkgsCross.pkgsStatic.stdenv.cc
              ] ++ 
              [
                pkgs.cmake
                # sdl2-musl
              ];

              env = {
                LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [ ]);
                DYLD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [ ]);
                
                # RUST_FLAGS = "--emit=link -L${pkgsCross.pkgsStatic.SDL2}/lib";
                # RUSTFLAGS = "-L ${sdl2-musl}/lib -C target-feature=+crt-static";

                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER = "${pkgsCross.pkgsStatic.stdenv.cc}/bin/aarch64-unknown-linux-musl-cc";
                
                # CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER = "${pkgsCross.pkgsStatic.stdenv.cc.targetPrefix}cc";
                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUNNER = "qemu-aarch64";
                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${pkgsCross.pkgsStatic.stdenv.cc.targetPrefix}cc";
                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";
              };
            }
          ) { };
    });
}
