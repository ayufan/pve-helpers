export RELEASE_START_SHA ?= $(shell git rev-list -1 HEAD VERSION)
export RELEASE ?= $(shell git rev-list $(RELEASE_START_SHA).. --count)
export RELEASE_NAME ?= $(shell cat VERSION)-$(RELEASE)
export RELEASE_VERSION ?= $(RELEASE_NAME)-g$(shell git rev-parse --short HEAD)

PACKAGE_FILE ?= pve-helpers-$(RELEASE_VERSION)_all.deb
TARGET_HOST ?= fill-me.home

all: pve-helpers

.PHONY: pve-helpers
pve-helpers: $(PACKAGE_FILE)

$(PACKAGE_FILE):
	fpm \
		--input-type dir \
		--output-type deb \
		--name pve-helpers \
		--version $(RELEASE_VERSION) \
		--package $@ \
		--architecture all \
		--category admin \
		--url https://gitlab.com/ayufan/pve-helpers-build \
		--description "Proxmox VE Helpers" \
		--vendor "Kamil Trzciński" \
		--maintainer "Kamil Trzciński <ayufan@ayufan.eu>" \
		--license "MIT" \
		--deb-priority optional \
		--depends inotify-tools \
		--depends qemu-server \
		--depends expect \
		--depends util-linux \
		--deb-compression bzip2 \
		--deb-systemd scripts/pve-qemu-hooks.service \
		root/=/

install: pve-helpers
	dpkg -i $(PACKAGE_FILE)

deploy: pve-helpers
	scp $(PACKAGE_FILE) $(TARGET_HOST):
	ssh $(TARGET_HOST) dpkg -i $(PACKAGE_FILE)

clean:
	rm -f $(PACKAGE_FILE)
