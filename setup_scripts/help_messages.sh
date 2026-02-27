# Help messages for the scripts
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --use-copilot    Enable use of copilot, only use in trusted environments"
  echo "  -h, --help       Show this help message"
  echo ""
  echo "Manual utilities:"
  echo "  bash setup_scripts/update_rust_stable.sh         Update Rust stable toolchain with confirmation"
  echo "  bash setup_scripts/update_rust_stable.sh --check Show Rust status only (no changes)"
}
