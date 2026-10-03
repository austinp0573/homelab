.PHONY: fmt test check release-amd64 release-arm64

fmt:
	cargo fmt --all

check:
	cargo check --all-targets

test:
	cargo test

release-amd64:
	rustup target add x86_64-unknown-linux-musl
	cargo build --release --target x86_64-unknown-linux-musl

release-arm64:
	rustup target add aarch64-unknown-linux-musl
	cargo build --release --target aarch64-unknown-linux-musl
