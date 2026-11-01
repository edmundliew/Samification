#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/samification-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
export CLANG_MODULE_CACHE_PATH="$check_dir/modules"
swiftc -module-cache-path "$CLANG_MODULE_CACHE_PATH" Sources/SamificationCore/*.swift scripts/VerifyCore.swift -o "$check_dir/check"
"$check_dir/check"
swiftc -frontend -parse App/*.swift
plutil -lint Samification.xcodeproj/project.pbxproj
