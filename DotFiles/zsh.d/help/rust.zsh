# --- rust help module --------------------------------------------------------
_devhelp_rust() {
cat <<'EOF2'
Rust — Quick Reference
======================

Your portable layout
--------------------
~/Components/Rust/<ver>/        # standalone installer output (no rustup)
  ├─ bin/     # rustc, cargo, rustfmt, clippy-driver, rust-analyzer, rustdoc
  └─ lib/     # rustlib (std for aarch64-apple-darwin)

Helper commands
---------------
rust_list            # approved Rust versions (from the components manifest)
use_rust [ver]|off   # put that toolchain on PATH (no ver = manifest default)
rust_clear           # remove it from PATH

Aliases
-------
rust_versions -> rust_list
rust_use      -> use_rust
rust_off      -> rust_clear

Install a new toolchain (not rustup — it self-updates)
-------------------------------------------------------
1. download rust-<ver>-aarch64-apple-darwin.tar.xz and unpack it anywhere
2. ./install.sh --prefix=$HOME/Components/Rust/<ver> --disable-ldconfig
3. add "rust <ver>" to the components manifest; components_check
   (delete the unpacked installer afterwards)

Everyday
--------
cargo new app && cd app      # new project
cargo build / run / test     # build, run, test
cargo fmt / cargo clippy     # format / lint
rustc --version              # confirm toolchain

Notes
-----
• PATH only. CARGO_HOME stays ~/.cargo (registry cache, cargo-installed bins).
• Targets other than aarch64-apple-darwin need their rust-std installed too.
EOF2
}

_devhelp_register "rust" _devhelp_rust
