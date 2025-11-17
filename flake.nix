{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      rust-overlay,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        toolchain = [
          pkgs.rust-bin.fromRustupToolchainFile
          ./toolchain.toml
        ];

      in
      {
        devShells.${system}.default =
          with pkgs;
          mkShell {
            buildInputs = [
              toolchain
              cargo
              rustc
              rustfmt
              rustPackages.clippy
            ];

            RUST_SRC_PATH = rustPlatform.rustLibSrc;
          };
      }
    );
}
