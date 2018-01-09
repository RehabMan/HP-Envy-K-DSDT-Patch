# makefile

#
# Patches/Installs/Builds DSDT patches for HP Envy (Haswell K-series)
#
# Created by RehabMan
#
# These patches are based on recent work on my Lenovo u430.  I don't have the Envy
# any more, but thought an update might be useful to others.
#

BUILDDIR=./build
HDA=ALC290
RESOURCES=./Resources_$(HDA)
HDAINJECT=AppleHDA_$(HDA).kext
USBINJECT=USBXHC_Envy.kext
BACKLIGHTINJECT=AppleBacklightInjector.kext

VERSION_ERA=$(shell ./print_version.sh)
ifeq "$(VERSION_ERA)" "10.10-"
	INSTDIR=/System/Library/Extensions
else
	INSTDIR=/Library/Extensions
endif
SLE=/System/Library/Extensions

# set build products
PRODUCTS=$(BUILDDIR)/SSDT-HACK-K1.aml $(BUILDDIR)/SSDT-HACK-K2.aml

IASLFLAGS=-vw 2095 -vw 3144 -vw 2011
IASL=iasl

.PHONY: all
all: $(PRODUCTS) $(HDAINJECT)

$(BUILDDIR)/SSDT-HACK-K1.aml: ./SSDT-HACK.dsl ./SSDT-USB-K1.dsl
	$(IASL) -D ENVY_K1 $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/SSDT-HACK-K2.aml: ./SSDT-HACK.dsl ./SSDT-USB-K2.dsl
	$(IASL) -D ENVY_K2 $(IASLFLAGS) -p $@ $<

.PHONY: clean
clean:
	rm -f $(BUILDDIR)/*.dsl $(BUILDDIR)/*.aml

# Clover Install
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

$(HDAINJECT): $(RESOURCES)/*.plist ./patch_hda.sh
	./patch_hda.sh $(HDA)
	touch $@

$(BACKLIGHTINJECT): Backlight.plist patch_backlight.sh
	./patch_backlight.sh
	touch $@

.PHONY: update_kernelcache
update_kernelcache:
	sudo touch $(SLE)
	sudo kextcache -update-volume /

.PHONY: install_hda
install_hda:
	sudo rm -Rf $(INSTDIR)/$(HDAINJECT)
	sudo cp -R ./$(HDAINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(HDAINJECT); fi
	make update_kernelcache

.PHONY: install_usb
install_usb:
	sudo rm -Rf $(INSTDIR)/$(USBINJECT)
	sudo cp -R ./$(USBINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(USBINJECT); fi
	make update_kernelcache

.PHONY: install_backlight
install_backlight:
	sudo rm -Rf $(INSTDIR)/$(BACKLIGHTINJECT)
	sudo cp -R ./$(BACKLIGHTINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(BACKLIGHTINJECT); fi
	make update_kernelcache
