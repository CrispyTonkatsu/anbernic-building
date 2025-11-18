{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      rust-overlay,
      nixpkgs,
    }:

    # TODO: Make this use the toolchain file for more compatibility
    {
      devShells.x86_64-linux.default =
        let
          pkgsCross = nixpkgs.legacyPackages.x86_64-linux.pkgsCross.aarch64-multiplatform;
          rust-bin = rust-overlay.lib.mkRustBin { } pkgsCross.buildPackages;
        in
        pkgsCross.callPackage (
          {
            mkShell,
            pkg-config,
            qemu,
            openssl,
            stdenv,
          }:
          mkShell {
            nativeBuildInputs = [
              (rust-bin.fromRustupToolchainFile ./toolchain.toml)
              pkg-config
            ];

            depsBuildBuild = [ qemu ];
            buildInputs = [ openssl ];

            env = {
              CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER = "${stdenv.cc.targetPrefix}cc";
              CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_RUNNER = "qemu-aarch64";
              CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
              CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUNNER = "qemu-aarch64";
            };
          }
        ) { };
    };
}
