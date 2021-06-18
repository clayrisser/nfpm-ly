export MAKE_CACHE := $(shell pwd)/.make
export PARENT := true
include blackmagic.mk

CHROOT := sudo chroot chroot
CODENAME := $(shell cat /etc/os-release | grep -E "^VERSION=" | \
	sed 's|^.*(||g' | sed 's|)"$$||g')

ifeq ($(CODENAME),)
	CODENAME := sid
endif

all: build

.PHONY: build
build: ly/bin/ly
ly/bin/ly:
	@$(MAKE) -s -C ly github
	@$(MAKE) -s -C ly

.PHONY: codename
codename:
	@echo $(CODENAME)

.PHONY: changelog
changelog:
	@git-chglog --output CHANGELOG.md

.PHONY: package
package: build package-rpm package-deb

.PHONY: package-rpm
package-rpm:
	@nfpm pkg --packager rpm --target .

.PHONY: package-deb
package-deb:
	@nfpm pkg --packager deb --target .

.PHONY: sudo
sudo:
	@sudo true

.PHONY: chroot
chroot: sudo chroot/bin/bash
chroot/bin/bash:
	@mkdir -p chroot
	-@sudo debootstrap $(CODENAME) chroot

.PHONY: purge
purge: sudo
	-@sudo umount chroot/code/ly $(NOFAIL)
	-@sudo rm -rf chroot $(NOFAIL)
	-@sudo $(GIT) clean -fXd

.PHONY: deps
deps: sudo
	@sudo apt install -y $(shell cat deps.list)

-include $(patsubst %,$(_ACTIONS)/%,$(ACTIONS))

+%:
	@$(MAKE) -e -s $(shell echo $@ | $(SED) 's/^\+//g')

%: ;

CACHE_ENVS +=
