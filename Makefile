FVM ?= fvm
RUSTUP_BIN_DIR ?= $(CURDIR)/.fvm/tools
RUSTUP_HOME ?= $(CURDIR)/.fvm/tools/rustup-home
RUST_TOOLCHAIN_FILE ?= $(CURDIR)/packages/localsend_isolates/rust-toolchain.toml
PREFIX ?= $(HOME)/.local
BINDIR ?= $(HOME)/bin
LIBDIR ?= $(PREFIX)/lib
DATADIR ?= $(PREFIX)/share
DESKTOPDIR ?= /usr/share/applications
DESTDIR ?=
DRY_RUN ?= 0

BUILD_MODE ?= release
LINUX_ARCH ?= x64
FLUTTER_BUILD_ARGS ?=
BUNDLE_DIR ?= app/build/linux/$(LINUX_ARCH)/$(BUILD_MODE)/bundle

.DEFAULT_GOAL := help
.PHONY: help setup-rust setup build install install-desktop

ifneq ($(DRY_RUN),0)
ifneq ($(DRY_RUN),1)
$(error DRY_RUN must be 0 or 1)
endif
endif

help:
	@printf '%s\n' \
	  'make setup    Prepare the pinned local Rust toolchain, install Flutter, and resolve packages.' \
	  'make setup-rust  Prepare only the pinned local Rust toolchain.' \
	  'make build    Build the native Linux release bundle with the pinned FVM Flutter SDK.' \
	  'make install  Build and install into BINDIR, LIBDIR, and DATADIR.' \
	  'make install-desktop  Install only the desktop entry into DESKTOPDIR.' \
	  'make -n install  Preview the commands without running them.' \
	  'make DRY_RUN=1 install  Print install actions without building or writing files.'

setup-rust:
	PATH="$(RUSTUP_BIN_DIR):$$PATH" RUSTUP_BIN_DIR="$(RUSTUP_BIN_DIR)" \
	  RUSTUP_HOME="$(RUSTUP_HOME)" RUST_TOOLCHAIN_FILE="$(RUST_TOOLCHAIN_FILE)" \
	  DRY_RUN="$(DRY_RUN)" ./support/scripts/setup_linux_rust.sh

ifeq ($(DRY_RUN),1)
setup: setup-rust
	@printf 'DRY RUN: %s install --skip-pub-get && cd app && %s flutter pub get\n' '$(FVM)' '$(FVM)'

build: setup
	@printf 'DRY RUN: cd app && PATH=%s:$$PATH RUSTUP_HOME=%s %s flutter build linux --%s --no-pub %s\n' '$(RUSTUP_BIN_DIR)' '$(RUSTUP_HOME)' '$(FVM)' '$(BUILD_MODE)' '$(FLUTTER_BUILD_ARGS)'
else

setup: setup-rust
	PATH="$(RUSTUP_BIN_DIR):$$PATH" RUSTUP_HOME="$(RUSTUP_HOME)" "$(FVM)" install --skip-pub-get
	cd app && PATH="$(RUSTUP_BIN_DIR):$$PATH" RUSTUP_HOME="$(RUSTUP_HOME)" "$(FVM)" flutter pub get

build: setup
	cd app && PATH="$(RUSTUP_BIN_DIR):$$PATH" RUSTUP_HOME="$(RUSTUP_HOME)" "$(FVM)" flutter build linux --$(BUILD_MODE) --no-pub $(FLUTTER_BUILD_ARGS)
endif

install: build
	./support/scripts/install_linux_local.sh \
	  "$(BUNDLE_DIR)" "$(DESTDIR)" "$(BINDIR)" "$(LIBDIR)" "$(DATADIR)" "$(DRY_RUN)"

install-desktop:
	./support/scripts/install_linux_desktop.sh \
	  "$(BINDIR)" "$(DESTDIR)" "$(DESKTOPDIR)" "$(DRY_RUN)"
