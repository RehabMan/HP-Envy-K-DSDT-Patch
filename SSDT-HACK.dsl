// Instead of providing patched DSDT/SSDT, just include a single SSDT
// and do the rest of the work in config.plist

// A bit experimental, and a bit more difficult with laptops, but
// still possible.

// Note: No solution for missing IAOE here, but so far, not a problem.

DefinitionBlock ("SSDT-HACK.aml", "SSDT", 1, "hack", "hack", 0x00003000)
{
    External(_SB.PCI0, DeviceObj)
    External(_SB.PCI0.LPCB, DeviceObj)

    // All _OSI calls in DSDT are routed to XOSI...
    // XOSI simulates "Windows 2012" (which is Windows 8)
    // Note: According to ACPI spec, _OSI("Windows") must also return true
    //  Also, it should return true for all previous versions of Windows.
    Method(XOSI, 1)
    {
        // simulation targets
        // source: (google 'Microsoft Windows _OSI')
        //  http://download.microsoft.com/download/7/E/7/7E7662CF-CBEA-470B-A97E-CE7CE0D98DC2/WinACPI_OSI.docx
        Store(Package()
        {
            "Windows",              // generic Windows query
            "Windows 2001",         // Windows XP
            "Windows 2001 SP2",     // Windows XP SP2
            //"Windows 2001.1",     // Windows Server 2003
            //"Windows 2001.1 SP1", // Windows Server 2003 SP1
            "Windows 2006",         // Windows Vista
            "Windows 2006 SP1",     // Windows Vista SP1
            //"Windows 2006.1",     // Windows Server 2008
            "Windows 2009",         // Windows 7/Windows Server 2008 R2
            "Windows 2012",         // Windows 8/Windows Sesrver 2012
            //"Windows 2013",       // Windows 8.1/Windows Server 2012 R2
            //"Windows 2015",       // Windows 10/Windows Server TP
        }, Local0)
        Return (LNotEqual(Match(Local0, MEQ, Arg0, MTR, 0, 0), Ones))
    }

//
// ACPISensors configuration (ACPISensors.kext is not installed by default)
//

    // Not implemented for the Haswell Envy

//
// USB related
//

    // In DSDT, native GPRW is renamed to XPRW with Clover binpatch.
    // As a result, calls to GPRW land here.
    // The purpose of this implementation is to avoid "instant wake"
    // by returning 0 in the second position (sleep state supported)
    // of the return package.
    Method(GPRW, 2)
    {
        If (LEqual(Arg0, 0x0d)) { Return(Package() { 0x0d, 0 }) }
        If (LEqual(Arg0, 0x6d)) { Return(Package() { 0x6d, 0 }) }
        External(\XPRW, MethodObj)
        Return(XPRW(Arg0, Arg1))
    }

    // Override for USBInjectAll.kext
    Device(UIAC)
    {
        Name(_HID, "UIA00000")
        Name(RMCF, Package()
        {
            // EH01 has no ports (XHCIMux is used to force USB3 routing OFF)
            "EH01", Package()
            {
                //"port-count", Buffer() { 8, 0, 0, 0 },
                "ports", Package()
                {
                    "PR11", Package()
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x01, 0, 0, 0 },
                    },
                },
            },
            // HUB1 customization
            "HUB1", Package()
            {
                //"port-count", Buffer() { 8, 0, 0, 0 },
                "ports", Package()
                {
                    "HP11", Package()   // USB2 routed from XHC
                    {
                        "UsbConnector", 0,
                        "port", Buffer() { 0x01, 0, 0, 0 },
                    },
                    "HP12", Package()   // USB2 routed from XHC
                    {
                        "UsbConnector", 0,
                        "port", Buffer() { 0x02, 0, 0, 0 },
                    },
                    "HP13", Package()   // camera
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x03, 0, 0, 0 },
                    },
                    // HP14 not used
                    // HP15 not used
                    "HP16", Package()   // USB2 routed from XHC
                    {
                        "UsbConnector", 0,
                        "port", Buffer() { 0x06, 0, 0, 0 },
                    },
                    "HP17", Package()   // bluetooth
                    {
                        "UsbConnector", 255,
                        "port", Buffer() { 0x07, 0, 0, 0 },
                    },
                    // HP18 not used
                },
            },
            // EH02 not present
            // XHC overrides
            "8086_9xxx", Package()
            {
                //"port-count", Buffer() { 0xd, 0, 0, 0 },
                "ports", Package()
                {
                    // HSxx ports not used due to FakePCIID_XHCIMux
                    "SS01", Package()   // USB3
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0xa, 0, 0, 0 },
                    },
                    "SS02", Package()   // USB3
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0xb, 0, 0, 0 },
                    },
                    "SS03", Package()   // USB3
                    {
                        "UsbConnector", 3,
                        "port", Buffer() { 0xc, 0, 0, 0 },
                    },
                },
            },
        })
    }


//
// Backlight control
//

    Device(PNLF)
    {
        Name(_ADR, Zero)
        Name(_HID, EisaId ("APP0002"))
        Name(_CID, "backlight")
        Name(_UID, 10)
        Name(_STA, 0x0B)
        Name(RMCF, Package()
        {
            "PWMMax", 0,
        })
        Method(_INI)
        {
            // disable discrete graphics (Nvidia) if it is present
            External(\_SB.PCI0.RP05.PEGP._OFF, MethodObj)
            If (CondRefOf(\_SB.PCI0.RP05.PEGP._OFF))
            {
                \_SB.PCI0.RP05.PEGP._OFF()
            }
        }
    }

//
// Standard Injections/Fixes
//

    Scope(_SB.PCI0)
    {
        Device(IMEI)
        {
            Name (_ADR, 0x00160000)
        }

        Device(SBUS.BUS0)
        {
            Name(_CID, "smbus")
            Name(_ADR, Zero)
            Device(DVL0)
            {
                Name(_ADR, 0x57)
                Name(_CID, "diagsvault")
                Method(_DSM, 4)
                {
                    If (LEqual (Arg2, Zero)) { Return (Buffer() { 0x03 } ) }
                    Return (Package() { "address", 0x57 })
                }
            }
        }

        External(IGPU, DeviceObj)
        Scope(IGPU)
        {
            // need the device-id from PCI_config to inject correct properties
            OperationRegion(RMIG, PCI_Config, 2, 2)
            Field(RMIG, AnyAcc, NoLock, Preserve)
            {
                GDID,16
            }

            // inject properties for integrated graphics on IGPU
            Method(_DSM, 4)
            {
                If (LEqual(Arg2, Zero)) { Return (Buffer() { 0x03 } ) }
                Store(Package()
                {
                    "model", Buffer() { "place holder" },
                    "device-id", Buffer() { 0x12, 0x04, 0x00, 0x00 },
                    "hda-gfx", Buffer() { "onboard-1" },
                    "AAPL,ig-platform-id", Buffer() { 0x06, 0x00, 0x26, 0x0a },
                }, Local1)
                Store(GDID, Local0)
                If (LEqual(Local0, 0x0a16)) { Store("Intel HD Graphics 4400", Index(Local1,1)) }
                ElseIf (LEqual(Local0, 0x0416)) { Store("Intel HD Graphics 4600", Index(Local1,1)) }
                ElseIf (LEqual(Local0, 0x0a1e)) { Store("Intel HD Graphics 4200", Index(Local1,1)) }
                Else
                {
                    // others (HD5000 and Iris) are natively supported
                    Store(Package()
                    {
                        "hda-gfx", Buffer() { "onboard-1" },
                        "AAPL,ig-platform-id", Buffer() { 0x06, 0x00, 0x26, 0x0a },
                    }, Local1)
                }
                Return(Local1)
            }
        }
    }

//
// Keyboard/Trackpad
//

    External(_SB.PCI0.LPCB.PS2K, DeviceObj)
    Scope (_SB.PCI0.LPCB.PS2K)
    {
        // Select specific keyboard map in VoodooPS2Keyboard.kext
        Method(_DSM, 4)
        {
            If (LEqual (Arg2, Zero)) { Return (Buffer() { 0x03 } ) }
            Return (Package()
            {
                "RM,oem-id", "HPQOEM",
                "RM,oem-table-id", "Haswell-Envy-RMCF",
            })
        }

        // overrides for VoodooPS2 configuration... (much more could be done here)
        Name(RMCF, Package()
        {
            "Sentelic FSP", Package()
            {
                "DisableDevice", ">y",
            },
            "ALPS GlidePoint", Package()
            {
                "DisableDevice", ">y",
            },
            "Mouse", Package()
            {
                "DisableDevice", ">y",
            },
            "Keyboard", Package()
            {
                "Custom PS2 Map", Package()
                {
                    Package() { },
                    "e045=e037",
                    "e0ab=0",   // bogus Fn+F2/F3
                },
                "Custom ADB Map", Package()
                {
                    Package() { },
                    "e019=42",  // next track
                    "e010=4d",  // previous track
                },
            },
        })
    }

    External(_SB.PCI0.LPCB.EC0, DeviceObj)
    Scope(_SB.PCI0.LPCB.EC0)
    {
        // The native _Qxx methods in DSDT are renamed XQxx,
        // so notifications from the EC driver will land here.

        // _Q10/Q11 called on brightness down/up
        Method (_Q10, 0, NotSerialized)
        {
            // Brightness Down
            Notify(\_SB.PCI0.LPCB.PS2K, 0x0405)
        }
        Method (_Q11, 0, NotSerialized)
        {
            // Brightness Up
            Notify(\_SB.PCI0.LPCB.PS2K, 0x0406)
        }
    }

//
// Battery Status
//

    // Override for ACPIBatteryManager.kext
    External(_SB.BAT0, DeviceObj)
    Name(_SB.BAT0.RMCF, Package()
    {
        "StartupDelay", 10,
    })

    Scope(_SB.PCI0.LPCB.EC0)
    {
        // This is an override for battery methods that access EC fields
        // larger than 8-bit.

        OperationRegion (RMEC, EmbeddedControl, Zero, 0xFF)
        Field (RMEC, ByteAcc, Lock, Preserve)
        {
            Offset (0x04), 
            SMWX,8,SMWY,8,
            //...
            Offset (0x70),
            ADC0,8,ADC1,8,
            FCC0,8,FCC1,8,
            //...
            Offset (0x82),
            /*MBST*/,   8,
            CUR0,8,CUR1,8,
            BRM0,8,BRM1,8,
            BCV0,8,BCV1,8,
        }

        // SMD0, 256 bits, offset 4
        // FLD0, 64 bits, offset 4
        // FLD1, 128 bits, offset 4
        // FLD2, 198 bits, offset 4
        // FLD3, 256 bits, offset 4

        Method (RSMD, 0, NotSerialized) { Return(RECB(4,256)) }
        Method (WSMD, 1, NotSerialized) { WECB(4,256,Arg0) }
        Method (RFL3, 0, NotSerialized) { Return(RECB(4,256)) }
        Method (RFL2, 0, NotSerialized) { Return(RECB(4,198)) }
        Method (RFL1, 0, NotSerialized) { Return(RECB(4,128)) }
        Method (RFL0, 0, NotSerialized) { Return(RECB(4,64)) }

    // Battery utility methods

        Method (\B1B2, 2, NotSerialized) { Return (Or (Arg0, ShiftLeft (Arg1, 8))) }

        Method (WE1B, 2, Serialized)
        {
            OperationRegion(ERAM, EmbeddedControl, Arg0, 1)
            Field(ERAM, ByteAcc, NoLock, Preserve) { BYTE, 8 }
            Store(Arg1, BYTE)
        }
        Method (WECB, 3, Serialized)
        // Arg0 - offset in bytes from zero-based EC
        // Arg1 - size of buffer in bits
        // Arg2 - value to write
        {
            ShiftRight(Arg1, 3, Arg1)
            Name(TEMP, Buffer(Arg1) { })
            Store(Arg2, TEMP)
            Add(Arg0, Arg1, Arg1)
            Store(0, Local0)
            While (LLess(Arg0, Arg1))
            {
                WE1B(Arg0, DerefOf(Index(TEMP, Local0)))
                Increment(Arg0)
                Increment(Local0)
            }
        }
        Method (RE1B, 1, Serialized)
        {
            OperationRegion(ERAM, EmbeddedControl, Arg0, 1)
            Field(ERAM, ByteAcc, NoLock, Preserve) { BYTE, 8 }
            Return(BYTE)
        }
        Method (RECB, 2, Serialized)
        // Arg0 - offset in bytes from zero-based EC
        // Arg1 - size of buffer in bits
        {
            ShiftRight(Arg1, 3, Arg1)
            Name(TEMP, Buffer(Arg1) { })
            Add(Arg0, Arg1, Arg1)
            Store(0, Local0)
            While (LLess(Arg0, Arg1))
            {
                Store(RE1B(Arg0), Index(TEMP, Local0))
                Increment(Arg0)
                Increment(Local0)
            }
            Return(TEMP)
        }

    // Replaced battery methods
    
        External(ECOK, IntObj)
        External(MUT0, MutexObj)
        External(SMST, FieldUnitObj)
        External(SMCM, FieldUnitObj)
        External(SMAD, FieldUnitObj)
        External(SMPR, FieldUnitObj)
        External(SMB0, FieldUnitObj)
        
        External(BCNT, FieldUnitObj)
        External(\_SB.GBFE, MethodObj)
        External(\_SB.PBFE, MethodObj)
        External(\_SB.BAT0.PBIF, PkgObj)
        External(\SMA4, FieldUnitObj)
        External(\_SB.BAT0.FABL, IntObj)
        External(MBNH, FieldUnitObj)
        External(BVLB, FieldUnitObj)
        External(BVHB, FieldUnitObj)
        External(\_SB.BAT0.UPUM, MethodObj)
        External(\_SB.BAT0.PBST, PkgObj)
        External(SW2S, FieldUnitObj)
        External(BACR, FieldUnitObj)
        External(MBST, FieldUnitObj)
        External(\_SB.BAT0._STA, MethodObj)
        
        Method (SMRD, 4, NotSerialized)
        {
            If (LNot (ECOK))
            {
                Return (0xFF)
            }

            If (LNotEqual (Arg0, 0x07))
            {
                If (LNotEqual (Arg0, 0x09))
                {
                    If (LNotEqual (Arg0, 0x0B))
                    {
                        If (LNotEqual (Arg0, 0x47))
                        {
                            If (LNotEqual (Arg0, 0xC7))
                            {
                                Return (0x19)
                            }
                        }
                    }
                }
            }

            Acquire (MUT0, 0xFFFF)
            Store (0x04, Local0)
            While (LGreater (Local0, One))
            {
                And (SMST, 0x40, SMST)
                Store (Arg2, SMCM)
                Store (Arg1, SMAD)
                Store (Arg0, SMPR)
                Store (Zero, Local3)
                While (LNot (And (SMST, 0xBF, Local1)))
                {
                    Sleep (0x02)
                    Increment (Local3)
                    If (LEqual (Local3, 0x32))
                    {
                        And (SMST, 0x40, SMST)
                        Store (Arg2, SMCM)
                        Store (Arg1, SMAD)
                        Store (Arg0, SMPR)
                        Store (Zero, Local3)
                    }
                }

                If (LEqual (Local1, 0x80))
                {
                    Store (Zero, Local0)
                }
                Else
                {
                    Decrement (Local0)
                }
            }

            If (Local0)
            {
                Store (And (Local1, 0x1F), Local0)
            }
            Else
            {
                If (LEqual (Arg0, 0x07))
                {
                    Store (SMB0, Arg3)
                }

                If (LEqual (Arg0, 0x47))
                {
                    Store (SMB0, Arg3)
                }

                If (LEqual (Arg0, 0xC7))
                {
                    Store (SMB0, Arg3)
                }

                If (LEqual (Arg0, 0x09))
                {
                    Store (B1B2(SMWX,SMWY), Arg3)
                }

                If (LEqual (Arg0, 0x0B))
                {
                    Store (BCNT, Local3)
                    ShiftRight (0x0100, 0x03, Local2)
                    If (LGreater (Local3, Local2))
                    {
                        Store (Local2, Local3)
                    }

                    If (LLess (Local3, 0x09))
                    {
                        Store (RFL0(), Local2)
                    }
                    Else
                    {
                        If (LLess (Local3, 0x11))
                        {
                            Store (RFL1(), Local2)
                        }
                        Else
                        {
                            If (LLess (Local3, 0x19))
                            {
                                Store (RFL2(), Local2)
                            }
                            Else
                            {
                                Store (RFL3(), Local2)
                            }
                        }
                    }

                    Increment (Local3)
                    Store (Buffer (Local3) {}, Local4)
                    Decrement (Local3)
                    Store (Zero, Local5)
                    While (LGreater (Local3, Local5))
                    {
                        GBFE (Local2, Local5, RefOf (Local6))
                        PBFE (Local4, Local5, Local6)
                        Increment (Local5)
                    }

                    PBFE (Local4, Local5, Zero)
                    Store (Local4, Arg3)
                }
            }

            Release (MUT0)
            Return (Local0)
        }

        Method (SMWR, 4, NotSerialized)
        {
            If (LNot (ECOK))
            {
                Return (0xFF)
            }

            If (LNotEqual (Arg0, 0x06))
            {
                If (LNotEqual (Arg0, 0x08))
                {
                    If (LNotEqual (Arg0, 0x0A))
                    {
                        If (LNotEqual (Arg0, 0x46))
                        {
                            If (LNotEqual (Arg0, 0xC6))
                            {
                                Return (0x19)
                            }
                        }
                    }
                }
            }

            Acquire (MUT0, 0xFFFF)
            Store (0x04, Local0)
            While (LGreater (Local0, One))
            {
                If (LEqual (Arg0, 0x06))
                {
                    Store (Arg3, SMB0)
                }

                If (LEqual (Arg0, 0x46))
                {
                    Store (Arg3, SMB0)
                }

                If (LEqual (Arg0, 0xC6))
                {
                    Store (Arg3, SMB0)
                }

                If (LEqual (Arg0, 0x08))
                {
                    // Store(Arg3, SMW0)
                    Store(Arg3, SMWX) Store(ShiftRight(Arg3, 8), SMWY)
                }

                If (LEqual (Arg0, 0x0A))
                {
                    WSMD(Arg3)
                }

                And (SMST, 0x40, SMST)
                Store (Arg2, SMCM)
                Store (Arg1, SMAD)
                Store (Arg0, SMPR)
                Store (Zero, Local3)
                While (LNot (And (SMST, 0xBF, Local1)))
                {
                    Sleep (0x02)
                    Increment (Local3)
                    If (LEqual (Local3, 0x32))
                    {
                        And (SMST, 0x40, SMST)
                        Store (Arg2, SMCM)
                        Store (Arg1, SMAD)
                        Store (Arg0, SMPR)
                        Store (Zero, Local3)
                    }
                }

                If (LEqual (Local1, 0x80))
                {
                    Store (Zero, Local0)
                }
                Else
                {
                    Decrement (Local0)
                }
            }

            If (Local0)
            {
                Store (And (Local1, 0x1F), Local0)
            }

            Release (MUT0)
            Return (Local0)
        }
    }

    Scope (_SB.BAT0)
    {
        Method (UPBI, 0, NotSerialized)
        {
            Store (B1B2(^^PCI0.LPCB.EC0.FCC0,^^PCI0.LPCB.EC0.FCC1), Local5)
            If (LAnd (Local5, LNot (And (Local5, 0x8000))))
            {
                ShiftRight (Local5, 0x05, Local5)
                ShiftLeft (Local5, 0x05, Local5)
                Store (Local5, Index (PBIF, One))
                Store (Local5, Index (PBIF, 0x02))
                Divide (Local5, 0x64, , Local2)
                Add (Local2, One, Local2)
                If (LLess (B1B2(^^PCI0.LPCB.EC0.ADC0,^^PCI0.LPCB.EC0.ADC1), 0x0C80))
                {
                    Multiply (Local2, 0x0E, Local4)
                    Add (Local4, 0x02, Index (PBIF, 0x05))
                    Multiply (Local2, 0x09, Local4)
                    Add (Local4, 0x02, Index (PBIF, 0x06))
                    Multiply (Local2, 0x0B, Local4)
                }
                Else
                {
                    If (LEqual (SMA4, One))
                    {
                        Multiply (Local2, 0x0C, Local4)
                        Add (Local4, 0x02, Index (PBIF, 0x05))
                        Multiply (Local2, 0x07, Local4)
                        Add (Local4, 0x02, Index (PBIF, 0x06))
                        Multiply (Local2, 0x09, Local4)
                    }
                    Else
                    {
                        Multiply (Local2, 0x0A, Local4)
                        Add (Local4, 0x02, Index (PBIF, 0x05))
                        Multiply (Local2, 0x05, Local4)
                        Add (Local4, 0x02, Index (PBIF, 0x06))
                        Multiply (Local2, 0x07, Local4)
                    }
                }

                Add (Local4, 0x02, FABL)
            }

            If (^^PCI0.LPCB.EC0.MBNH)
            {
                Store (^^PCI0.LPCB.EC0.BVLB, Local0)
                Store (^^PCI0.LPCB.EC0.BVHB, Local1)
                ShiftLeft (Local1, 0x08, Local1)
                Or (Local0, Local1, Local0)
                Store (Local0, Index (PBIF, 0x04))
                Store ("OANI$", Index (PBIF, 0x09))
                Store ("NiMH", Index (PBIF, 0x0B))
            }
            Else
            {
                Store (^^PCI0.LPCB.EC0.BVLB, Local0)
                Store (^^PCI0.LPCB.EC0.BVHB, Local1)
                ShiftLeft (Local1, 0x08, Local1)
                Or (Local0, Local1, Local0)
                Store (Local0, Index (PBIF, 0x04))
                Sleep (0x32)
                Store ("LION", Index (PBIF, 0x0B))
            }

            Store ("Primary", Index (PBIF, 0x09))
            UPUM ()
            Store (One, Index (PBIF, Zero))
        }
        Method (UPBS, 0, NotSerialized)
        {
            Store (B1B2(^^PCI0.LPCB.EC0.CUR0,^^PCI0.LPCB.EC0.CUR1), Local0)
            If (And (Local0, 0x8000))
            {
                If (LEqual (Local0, 0xFFFF))
                {
                    Store (Ones, Index (PBST, One))
                }
                Else
                {
                    Not (Local0, Local1)
                    Increment (Local1)
                    And (Local1, 0xFFFF, Local3)
                    Store (Local3, Index (PBST, One))
                }
            }
            Else
            {
                Store (Local0, Index (PBST, One))
            }

            Store (B1B2(^^PCI0.LPCB.EC0.BRM0,^^PCI0.LPCB.EC0.BRM1), Local5)
            If (LNot (And (Local5, 0x8000)))
            {
                ShiftRight (Local5, 0x05, Local5)
                ShiftLeft (Local5, 0x05, Local5)
                If (LNotEqual (Local5, DerefOf (Index (PBST, 0x02))))
                {
                    Store (Local5, Index (PBST, 0x02))
                }
            }

            If (LAnd (LNot (^^PCI0.LPCB.EC0.SW2S), LEqual (^^PCI0.LPCB.EC0.BACR, One)))
            {
                Store (FABL, Index (PBST, 0x02))
            }

            Store (B1B2(^^PCI0.LPCB.EC0.BCV0,^^PCI0.LPCB.EC0.BCV1), Index (PBST, 0x03))
            Store (^^PCI0.LPCB.EC0.MBST, Index (PBST, Zero))
        }
    }

    Method (\_SB.PCI0.ACEL.CLRI, 0, Serialized)
    {
        Store (Zero, Local0)
        If (LEqual (^^LPCB.EC0.ECOK, One))
        {
            If (LEqual (^^LPCB.EC0.SW2S, Zero))
            {
                If (LEqual (^^^BAT0._STA (), 0x1F))
                {
                    If (LLessEqual (B1B2(^^LPCB.EC0.BRM0,^^LPCB.EC0.BRM1), 0x96))
                    {
                        Store (One, Local0)
                    }
                }
            }
        }
        Return (Local0)
    }
}

