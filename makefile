# makefile

#
# Patches/Installs/Builds DSDT patches for HP Envy (Haswell K-series)
#
# Created by RehabMan
#
# These patches are based on recent work on my Lenovo u430.  I don't have the Envy
# any more, but thought an update might be useful to others.
#

HDA=ALC290
RESOURCES=./Resources_$(HDA)
HDAINJECT=AppleHDA_$(HDA).kext
HDAINJECT_MARK=_hdainject_marker.txt

# set build products
BUILDDIR=./build
HDA_PRODUCTS=$(HDAINJECT_MARK)
AML_PRODUCTS=$(BUILDDIR)/SSDT-HACK-K1.aml $(BUILDDIR)/SSDT-HACK-K2.aml
PRODUCTS=$(AML_PRODUCTS) $(HDA_PRODUCTS)

LE=/Library/Extensions
SLE=/System/Library/Extensions
VERSION_ERA=$(shell ./tools/print_version.sh)
ifeq "$(VERSION_ERA)" "10.10-"
	INSTDIR=$SLE
else
	INSTDIR=$LE
endif

IASLFLAGS=-vw 2095 -vw 2146
IASL=iasl

.PHONY: all
all: $(PRODUCTS)

$(BUILDDIR)/SSDT-HACK-K1.aml: ./SSDT-HACK.dsl ./SSDT-USB-K1.dsl
	$(IASL) -D ENVY_K1 $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/SSDT-HACK-K2.aml: ./SSDT-HACK.dsl ./SSDT-USB-K2.dsl
	$(IASL) -D ENVY_K2 $(IASLFLAGS) -p $@ $<

.PHONY: clean
clean:
	rm -f $(BUILDDIR)/*.dsl $(BUILDDIR)/*.aml
	make clean_hda

.PHONY: install
install: $(PRODUCTS)
	$(eval EFIDIR:=$(shell ./mount_efi.sh))
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/DSDT.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-*.aml
	cp $(BUILDDIR)/SSDT-HACK-K1.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-HACK-K1.aml

.PHONY: install_k2
install_k2: $(PRODUCTS)
	$(eval EFIDIR:=$(shell ./mount_efi.sh))
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/DSDT.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-*.aml
	cp $(BUILDDIR)/SSDT-HACK-K2.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-HACK-K2.aml

$(HDAINJECT_MARK): $(RESOURCES)/*.plist tools/_hda_subs.sh
	./tools/patch_hdainject.sh $(HDA)
	touch $(HDAINJECT_MARK)

.PHONY: clean_hda
clean_hda:
	rm -rf $(HDAINJECT)
	rm $(HDAINJECT_MARK)

.PHONY: update_kernelcache
	update_kernelcache:
	sudo touch $(SLE) && sudo kextcache -update-volume /

.PHONY: install_hda
install_hda:
	sudo rm -Rf $(INSTDIR)/$(HDAINJECT)
	sudo cp -R ./$(HDAINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(HDAINJECT); fi
	make update_kernelcache

