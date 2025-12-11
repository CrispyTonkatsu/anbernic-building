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
          platformDeps = (if pkgs.stdenv.isDarwin then with pkgsCross; [ 
            libiconv 
          ] else with pkgsCross; [ 
              libdrm.dev 
              libdecor.dev
              mesa
            ]);
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
                openssl 
                # SDL2
                # SDL2.dev
              ];

              env = {
                LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
                  SDL2
                  SDL2.dev
                ]);

                DYLD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
                  SDL2
                  SDL2.dev
                ]);

                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER = "${pkgsCross.pkgsStatic.stdenv.cc.targetPrefix}cc";
                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUNNER = "qemu-aarch64";
                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${pkgsCross.pkgsStatic.stdenv.cc.targetPrefix}cc";
                CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";
              };
            }
          ) { };
    });
}
