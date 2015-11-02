# makefile

#
# Patches/Installs/Builds DSDT patches for HP Envy (Haswell K-series)
#
# Created by RehabMan
#
# These patches are based on recent work on my Lenovo u430.  I don't have the Envy
# any more, but thought an update might be useful to others.
#

LAPTOPGIT=../laptop.git
DEBUGGIT=../debug.git
BUILDDIR=./build
PATCHED=./patched
UNPATCHED=./unpatched
RESOURCES=./Resources_ALC290
HDAINJECT=AppleHDA_ALC290.kext
HDALAYOUT=layout3
USBINJECT=USBXHC_Envy.kext
BACKLIGHTINJECT=AppleBacklightInjector.kext

VERSION_ERA=$(shell ./print_version.sh)
ifeq "$(VERSION_ERA)" "10.10-"
	INSTDIR=/System/Library/Extensions
else
	INSTDIR=/Library/Extensions
endif
SLE=/System/Library/Extensions

# DSDT is easy to find...
DSDT=DSDT

# Name(_ADR,0x0002000) identifies IGPU SSDT
IGPU=$(shell grep -l Name.*_ADR.*0x00020000 $(UNPATCHED)/SSDT*.dsl)
IGPU:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(IGPU)))

# OperationRegion SGOP is defined in optimus SSDT
PEGP=$(shell grep -l OperationRegion.*SGOP $(UNPATCHED)/SSDT*.dsl)
PEGP:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(PEGP)))

# Device(IAOE) identifies SSDT with IAOE
IAOE=$(shell grep -l Device.*IAOE $(UNPATCHED)/SSDT*.dsl)
IAOE:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(IAOE)))

# Name(_PPC, ...) identifies SSDT with _PPC
PPC=$(shell grep -l Name.*_PPC $(UNPATCHED)/SSDT*.dsl)
PPC:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(PPC)))

# Name(SSDT, Package...) identifies SSDT with dynamic SSDTs
DYN=$(shell grep -l Name.*SSDT.*Package $(UNPATCHED)/SSDT*.dsl)
DYN:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(DYN)))

# Determine build products
PRODUCTS=$(BUILDDIR)/$(DSDT).aml $(BUILDDIR)/$(IGPU).aml $(BUILDDIR)/$(PPC).aml $(BUILDDIR)/$(DYN).aml
ALL_PATCHED=$(PATCHED)/$(DSDT).dsl $(PATCHED)/$(IGPU).dsl
ifneq "$(PEGP)" ""
	PRODUCTS:=$(PRODUCTS) $(BUILDDIR)/$(PEGP).aml
	ALL_PATCHED:=$(ALL_PATCHED) $(PATCHED)/$(PEGP).dsl
endif
ifneq "$(IAOE)" ""
	PRODUCTS:=$(PRODUCTS) $(BUILDDIR)/$(IAOE).aml
	ALL_PATCHED:=$(ALL_PATCHED) $(PATCHED)/$(IAOE).dsl
endif

IASLFLAGS=-ve
IASL=iasl

.PHONY: all
all: $(PRODUCTS) $(HDAINJECT) $(BACKLIGHTINJECT)

$(BUILDDIR)/DSDT.aml: $(PATCHED)/$(DSDT).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/$(IGPU).aml: $(PATCHED)/$(IGPU).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/$(PPC).aml: $(PATCHED)/$(PPC).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/$(DYN).aml: $(PATCHED)/$(DYN).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

ifneq "$(PEGP)" ""
$(BUILDDIR)/$(PEGP).aml: $(PATCHED)/$(PEGP).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<
endif

ifneq "$(IAOE)" ""
$(BUILDDIR)/$(IAOE).aml: $(PATCHED)/$(IAOE).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<
endif


.PHONY: clean
clean:
	rm -f $(PATCHED)/*.dsl
	rm -f $(BUILDDIR)/*.dsl $(BUILDDIR)/*.aml

.PHONY: cleanall
cleanall:
	make clean
	rm -f $(UNPATCHED)/*.dsl

.PHONY: cleanallex
cleanallex:
	make cleanall
	rm -f native_patchmatic/*.aml


# Clover Install
.PHONY: install
install: $(PRODUCTS)
	$(eval EFIDIR:=$(shell sudo ./mount_efi.sh /))
	cp $(BUILDDIR)/$(DSDT).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched
	cp $(BUILDDIR)/$(PPC).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-2.aml
	cp $(BUILDDIR)/$(DYN).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-3.aml
	cp $(BUILDDIR)/$(IGPU).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-4.aml
ifneq "$(PEGP)" ""
	cp $(BUILDDIR)/$(PEGP).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-5.aml
endif
ifneq "$(IAOE)" ""
	cp $(BUILDDIR)/$(IAOE).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-7.aml
endif

$(HDAINJECT): $(RESOURCES)/ahhcd.plist $(RESOURCES)/layout/Platforms.xml.zlib $(RESOURCES)/layout/$(HDALAYOUT).xml.zlib ./patch_hda.sh
	./patch_hda.sh
	touch $@

$(RESOURCES)/layout/Platforms.xml.zlib: $(RESOURCES)/layout/Platforms.plist $(SLE)/AppleHDA.kext/Contents/Resources/Platforms.xml.zlib
	./tools/zlib inflate $(SLE)/AppleHDA.kext/Contents/Resources/Platforms.xml.zlib >/tmp/rm_Platforms.plist
	/usr/libexec/plistbuddy -c "Delete ':PathMaps'" /tmp/rm_Platforms.plist
	/usr/libexec/plistbuddy -c "Merge $(RESOURCES)/layout/Platforms.plist" /tmp/rm_Platforms.plist
	./tools/zlib deflate /tmp/rm_Platforms.plist >$@

$(RESOURCES)/layout/$(HDALAYOUT).xml.zlib: $(RESOURCES)/layout/$(HDALAYOUT).plist
	./tools/zlib deflate $< >$@

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

# Patch with 'patchmatic'

.PHONY: patch
patch: $(ALL_PATCHED)

$(PATCHED)/$(DSDT).dsl: $(UNPATCHED)/$(DSDT).dsl patches/syntax_dsdt.txt patches/syntax_dsdt_nvidia.txt patches/cleanup.txt patches/remove_wmi.txt patches/iaoe.txt patches/keyboard.txt patches/audio.txt patches/sensors.txt $(LAPTOPGIT)/system/system_IRQ.txt $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt patches/hdmi_audio.txt $(LAPTOPGIT)/usb/usb_7-series.txt patches/usb.txt $(LAPTOPGIT)/system/system_WAK2.txt $(LAPTOPGIT)/system/system_OSYS_win7.txt $(LAPTOPGIT)/system/system_MCHC.txt $(LAPTOPGIT)/system/system_HPET.txt $(LAPTOPGIT)/system/system_RTC.txt $(LAPTOPGIT)/system/system_SMBUS.txt $(LAPTOPGIT)/system/system_Mutex.txt $(LAPTOPGIT)/system/system_PNOT.txt $(LAPTOPGIT)/system/system_IMEI.txt $(LAPTOPGIT)/battery/battery_HP-G6-2221ss.txt patches/bcm_wifi.txt patches/card_reader.txt
	cp $(UNPATCHED)/$(DSDT).dsl $(PATCHED)
	patchmatic $@ patches/syntax_dsdt.txt
ifneq "$(PEGP)" ""
	patchmatic $@ patches/syntax_dsdt_nvidia.txt
endif
	patchmatic $@ patches/cleanup.txt
	patchmatic $@ patches/remove_wmi.txt
	patchmatic $@ patches/iaoe.txt
	patchmatic $@ patches/keyboard.txt
	patchmatic $@ patches/audio.txt
	#patchmatic $@ patches/sensors.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_IRQ.txt
	patchmatic $@ $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt
	patchmatic $@ patches/hdmi_audio.txt
	#patchmatic $@ $(LAPTOPGIT)/usb/usb_7-series.txt
	patchmatic $@ patches/usb.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_WAK2.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_OSYS_win7.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_MCHC.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_HPET.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_RTC.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_SMBUS.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_Mutex.txt
	#patchmatic $@ $(LAPTOPGIT)/system/system_PNOT.txt
	patchmatic $@ $(LAPTOPGIT)/system/system_IMEI.txt
	patchmatic $@ $(LAPTOPGIT)/battery/battery_HP-G6-2221ss.txt
	#patchmatic $@ patches/ar92xx_wifi.txt
	#patchmatic $@ patches/bcm_wifi.txt
	#patchmatic $@ patches/card_reader.txt
ifeq "$(DEBUG)" "1"
	patchmatic $@ $(DEBUGGIT)/debug.txt
	patchmatic $@ $(DEBUGGIT)/instrument_Qxx.txt
	patchmatic $@ $(DEBUGGIT)/instrument_Lxx.txt
	patchmatic $@ $(DEBUGGIT)/instrument_WAK_PTS.txt
	#patchmatic $@ patches/debug1.txt
endif

$(PATCHED)/$(IGPU).dsl: $(UNPATCHED)/$(IGPU).dsl patches/cleanup.txt $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt $(LAPTOPGIT)/graphics/graphics_PNLF_haswell.txt $(LAPTOPGIT)/graphics/graphics_PNLF.txt patches/hdmi_audio.txt patches/graphics.txt
	cp $(UNPATCHED)/$(IGPU).dsl $(PATCHED)
	patchmatic $@ patches/cleanup.txt
	patchmatic $@ $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt
	#patchmatic $@ $(LAPTOPGIT)/graphics/graphics_PNLF_haswell.txt
	patchmatic $@ $(LAPTOPGIT)/graphics/graphics_PNLF.txt
	patchmatic $@ patches/hdmi_audio.txt
	patchmatic $@ patches/graphics.txt
ifeq "$(DEBUG)" "1"
	patchmatic $@ $(DEBUGGIT)/debug_extern.txt
endif

$(PATCHED)/$(PPC).dsl: $(UNPATCHED)/$(PPC).dsl patches/syntax_ppc.txt
	cp $(UNPATCHED)/$(PPC).dsl $(PATCHED)
	patchmatic $@ patches/syntax_ppc.txt
ifeq "$(DEBUG)" "1"
	patchmatic $@ $(DEBUGGIT)/debug_extern.txt
endif

$(PATCHED)/$(DYN).dsl: $(UNPATCHED)/$(DYN).dsl
	cp $(UNPATCHED)/$(DYN).dsl $(PATCHED)
ifeq "$(DEBUG)" "1"
	patchmatic $@ $(DEBUGGIT)/debug_extern.txt
endif

ifneq "$(IAOE)" ""
$(PATCHED)/$(IAOE).dsl: $(UNPATCHED)/$(IAOE).dsl $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt patches/syntax_iaoe.txt
	cp $(UNPATCHED)/$(IAOE).dsl $(PATCHED)
	patchmatic $@ $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt
	patchmatic $@ patches/syntax_iaoe.txt
endif

ifneq "$(PEGP)" ""
$(PATCHED)/$(PEGP).dsl: $(UNPATCHED)/$(PEGP).dsl patches/nvidia_off.txt $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt patches/cleanup.txt
	cp $(UNPATCHED)/$(PEGP).dsl $(PATCHED)
	patchmatic $@ patches/nvidia_off.txt
	patchmatic $@ patches/cleanup.txt
	patchmatic $@ $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt
ifeq "$(DEBUG)" "1"
	patchmatic $@ $(DEBUGGIT)/debug_extern.txt
endif
endif

# native correlations
# ssdt1 - PTID
# ssdt2 - PM related
# ssdt3 - PM related
# ssdt4 - graphics
# ssdt5 - IAOE (sometimes required for sleep)
# ssdt6, ssdt7, ssdt8 - loaded dynamically (PM related)

# Note: In optimus setup, ssdt5 is PEGP and ssdt6 is IAOE
