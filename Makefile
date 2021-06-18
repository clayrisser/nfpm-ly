export MAKE_CACHE := $(shell pwd)/.make
export PARENT := true
include blackmagic.mk

CHROOT := sudo chroot .chroot
DEBFILE := ly_0.1.0_amd64.deb
CODENAME := $(shell cat /etc/os-release | grep -E "^VERSION=" | \
	sed 's|^.*(||g' | sed 's|)"$$||g')

ifeq ($(CODENAME),)
	CODENAME := sid
endif

all: build

.PHONY: build
build: ly/bin/ly
ly/bin/ly: ly/makefile
	@$(MAKE) -s -C ly github
	@$(MAKE) -s -C ly

.PHONY: codename
codename:
	@echo $(CODENAME)

.PHONY: changelog
changelog:
	@git-chglog --output CHANGELOG.md

.PHONY: package
package: package-rpm package-deb

.PHONY: package-rpm
package-rpm: ly/bin/ly
	@nfpm pkg --packager rpm --target .

.PHONY: package-deb
package-deb: ly/bin/ly
	@nfpm pkg --packager deb --target .

.PHONY: sudo
sudo:
	@sudo true

.PHONY: debootstrap
debootstrap: sudo .chroot/bin/bash
.chroot/bin/bash:
	@mkdir -p .chroot
	-@sudo debootstrap $(CODENAME) .chroot

.PHONY: chroot
chroot: sudo debootstrap
	@$(CHROOT)

.PHONY: purge
purge: sudo
	-@sudo umount chroot/code/ly $(NOFAIL)
	-@sudo rm -rf chroot $(NOFAIL)
	-@sudo $(GIT) clean -fXd

.PHONY: deps
deps: sudo
	@sudo apt install -y $(shell cat deps.list)

.PHONY: submodules
submodules: ly/makefile
ly/makefile:
	@git submodule sync
	@git submodule update --init --remote
	@git submodule update --init --recursive --remote

%.deb: package-deb

.PHONY: test
test: sudo usr/bin/ly
usr/bin/ly: $(DEBFILE) .chroot/bin/bash
	@cp $< .chroot/tmp
	-@$(CHROOT) dpkg -i tmp/$<
	@$(CHROOT) apt install -y -f
	@$(CHROOT) dpkg -i tmp/$<
	@[ "$$($(CHROOT) which ly)" = "/usr/bin/ly" ] || (echo TESTS FAILED >&2 && exit 1)
	@echo TESTS PASSED

-include $(patsubst %,$(_ACTIONS)/%,$(ACTIONS))

+%:
	@$(MAKE) -e -s $(shell echo $@ | $(SED) 's/^\+//g')

%: ;

CACHE_ENVS +=
