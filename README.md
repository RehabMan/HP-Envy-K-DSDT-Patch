## Haswell HP Envy DSDT patches by RehabMan

This set of patches/makefile can be used to patch your Haswell HP Envy DSDT/SSDTs.  It relies heavily on already existing laptop DSDT patches at github here: https://github.com/RehabMan/Laptop-DSDT-Patch.  There are also post install scripts that can be used to create and install the kexts the are required for this laptop series.

Please refer to this guide thread on tonymacx86.com for a step-by-step process, feedback, and questions:

http://www.tonymacx86.com/yosemite-laptop-guides/162939-guide-hp-envy-haswell-series-j-k-using-clover-uefi.html


### Change Log:

2015-11-18

- SSDT-HACK method from u430 project

- Use USBInjectAll for 10.11 USB optimization

- new AppleHDA files (courtesy macpeet?)... info here:

http://www.insanelymac.com/forum/topic/307083-help-alc290-speaker-and-hp-works-but-mics-doesnt/page-2#entry2154809

http://www.insanelymac.com/forum/index.php?app=core&module=attach&section=attach&attach_id=166972


2015-04-29

- Merge u430 changes


2014-01-14 

- Initial Release


