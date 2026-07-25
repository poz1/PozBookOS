#
# SPDX-License-Identifier: GPL-3.0-or-later

all:

check: lint

lint:
	shellcheck -s bash $(wildcard profiles/*/profiledef.sh)
	shellcheck -s bash $(wildcard profiles/*/airootfs/usr/local/bin/*)

.PHONY: all check lint
