#!/usr/bin/env bash

set -euo pipefail

export PATH="$HOME/.cargo/bin:$PATH"

if ! command -v rustup >/dev/null 2>&1; then
	rustup_installer="$(mktemp)"
	trap 'rm -f "$rustup_installer"' EXIT
	curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o "$rustup_installer"
	sh "$rustup_installer" -y --default-toolchain stable --profile default --no-modify-path
fi

rustup update stable
rustup component add rustfmt clippy --toolchain stable
rustup check

mkdir -p "$HOME/.local/bin"
for rust_command in rustup cargo rustc rustfmt cargo-clippy; do
	if [ -x "$HOME/.cargo/bin/$rust_command" ]; then
		ln -sfn "$HOME/.cargo/bin/$rust_command" "$HOME/.local/bin/$rust_command"
	fi
done
