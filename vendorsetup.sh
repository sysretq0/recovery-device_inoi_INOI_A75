#!/bin/bash
#
#	This file is part of the OrangeFox Recovery Project
# 	Copyright (C) 2024-2025 The OrangeFox Recovery Project
#
#	OrangeFox is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	any later version.
#
#	OrangeFox is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
# 	This software is released under GPL version 3 or any later version.
#	See <http://www.gnu.org/licenses/>.
#
# 	Please maintain this if you use this script or any part of it
#

fetch_mt6789_common_repo() {
	local URL=https://github.com/ramabondanp/twrp-device_transsion_mt6789-common.git
	local common="$1/device/transsion/mt6789-common"
	if [ ! -d "$common" ]; then
		echo "Cloning $URL ... to $common"
		git clone "$URL" -b twrp-16.0-tos16 "$common" || return 1
	else
		echo "Device common repository: \"$common\" found ..."
	fi
	if [ ! -e "$common/.git" ]; then
		echo "ERROR: $common is not a Git checkout." >&2
		return 1
	fi
	local branch
	branch=$(git -C "$common" branch --show-current) || return 1
	if [ "$branch" != twrp-16.0-tos16 ]; then
		echo "ERROR: Common tree must be on twrp-16.0-tos16 (found: ${branch:-detached HEAD})." >&2
		return 1
	fi
}

apply_INOI_A75_patch() {
	local tree="$1"
	local patch="$2"
	if [ ! -f "$patch" ]; then
		return 0
	fi
	if git -C "$tree" apply --reverse --check "$patch" >/dev/null 2>&1; then
		echo "Already applied: $(basename "$patch")"
	elif git -C "$tree" apply --check "$patch"; then
		git -C "$tree" apply "$patch" || return 1
		echo "Applied: $(basename "$patch")"
	else
		echo "ERROR: Cannot apply $patch to $tree; resolve the conflict first." >&2
		return 1
	fi
}

setup_INOI_A75() {
	local root
	root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd) || return 1

	# Clone to fix build on minimal manifest
	if [ ! -d "$root/external/gflags" ]; then
		git clone https://android.googlesource.com/platform/external/gflags/ -b android-12.1.0_r4 "$root/external/gflags" || return 1
	else
		echo "Dependency: \"external/gflags\" found ..."
	fi

	# mt6789-common
	fetch_mt6789_common_repo "$root" || return 1

	# Patches
	apply_INOI_A75_patch "$root/bootable/recovery" \
		"$root/device/transsion/mt6789-common/patches/0002-Respect-disabled-repacking.patch" || return 1
	apply_INOI_A75_patch "$root/build/make" \
		"$root/device/transsion/mt6789-common/patches/0001-Add-zstd-ramdisk-compression.patch" || return 1
	echo "OK: All patched"
}

setup_INOI_A75
