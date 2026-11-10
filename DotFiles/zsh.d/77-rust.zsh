# 77) Rust
# Versions come from the components manifest. Toolchains are installed with the
# standalone installer into ~/Components/Rust/<ver> (not rustup, which
# self-updates). PATH only: CARGO_HOME (registry cache, cargo-installed bins)
# is $XDG_DATA_HOME/cargo, set in 10-env-path.zsh.
rust_list() { components_list rust Rust; }

use_rust() {
  if [[ "$1" == "off" ]]; then rust_clear; return; fi
  components_activate rust Rust _RUST_ACTIVE_BIN "$1" || return 1
  echo "Switched to Rust $CM_V"; rustc --version; cargo --version
}

rust_clear() { components_deactivate rust Rust _RUST_ACTIVE_BIN; echo "Rust removed"; }
alias rust_versions='rust_list'
alias rust_use='use_rust'
alias rust_off='rust_clear'

load_components_completion "use_rust" "rust"
