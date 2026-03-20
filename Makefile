#
# SPDX-License-Identifier: GPL-3.0-or-later

all:

check: lint

lint:
	shellcheck -s bash $(wildcard profiles/*/profiledef.sh) \
	                   profiles/x13s/airootfs/usr/local/bin/ironrobin-setup

.PHONY: check lint
