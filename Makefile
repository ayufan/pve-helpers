export RELEASE ?= 1
export RELEASE_NAME ?= $(shell cat VERSION)-$(RELEASE)
export RELEASE_VERSION ?= $(RELEASE_NAME)-g$(shell git rev-parse --short HEAD)

all: pve-helpers

.PHONY: pve-helpers
pve-helpers: pve-helpers-$(RELEASE_NAME)_all.deb

pve-helpers-$(RELEASE_NAME)_all.deb:
	fpm -s dir -t deb -n pve-helpers-$(RELEASE_NAME) -v $(RELEASE_NAME) \
		-p $@ \
		--deb-priority optional \
		--category admin \
		--force \
		--depends inotify-tools \
		--depends qemu-server \
		--depends expect \
		--depends util-linux \
		--depends parted \
		--depends device-tree-compiler \
		--depends linux-base \
		--deb-compression bzip2 \
		--deb-field "Provides: pve-helpers, pve-helpers" \
		--deb-field "Replaces: pve-helpers, pve-helpers" \
		--deb-field "Conflicts: pve-helpers, pve-helpers" \
		--after-install scripts/postinst.deb \
		--url https://gitlab.com/ayufan/pve-helpers-build \
		--description "Proxmox VE Helpers" \
		-m "Kamil Trzciński <ayufan@ayufan.eu>" \
		--license "MIT" \
		--vendor "Kamil Trzciński" \
		-a all \
		--deb-systemd root/lib/systemd/system/pve-qemu-hooks.service \
		root/usr/=/usr/ \
