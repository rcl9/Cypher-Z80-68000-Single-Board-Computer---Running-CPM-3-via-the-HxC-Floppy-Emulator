## How to Boot CP/M-3 from the HxC Floppy Emulator on the Cypher Z80/68000 SBC

This file explains how to boot from CP/M-3 via the HxC Floppy Emulator attached to the floppy disk controller interface connector of the 1985-era [Motel Computers Cypher Z80/68000 SBC](https://github.com/rcl9/Cypher-Z80-68000-Single-Board-Computer-1984-by-Motel-Computers---History-and-Documentation). This will allow the Cypher SBC to boot from the floppy emulator rather than its stock 8" floppy disks or 5MB hard disk. 

A much longer and more complex explanation details how to generate a "cyphboot.img" disk image file from the original CP/M-3 Z80 source files .

# The Simplest and Quickest Explanation

- Unzip and copy all of the files from the *Hxc_SDCARD_Contents_For_Cypher_Boot.zip* to the SDCARD to be used with the HxC emulator.

- Put the SDCARD into the HxC emulator and select the "*cyphboot.hfe*" file for Drive A0 (the STARTUPA.HFE and STARTUPB.HFE files will be automatically loaded if the corresponding HxC UI option is enabled). 

- Turn on the Cypher computer, press "s" to switch from the 68k CPU to the Z80 CPU and then "b1" to boot off the HxC emulator. If you do just "b" then the computer will try to boot off the hard disk which is fine as long as the hard disk is powered up.

- Don't forget to do "park.com" to park the heads of the hard disk before powering off.

- And that's all you need to do or know!

# How to compile CP/M-3 to "cpm3.sys" and "systrks.img" from Cypher Source Files

- You will first and foremost want to set up a good CP/M-3 emulation environment on your computer. Fortunately I had spent considerable time to create a "Dream come true" CP/M-3 working environment for the Yaze-AG emulator. I've been very happy with using Yaze-AG to run CP/M-3 except that it can run out of memory if you mount too many disk images. I will not include those related Yaze-AG files herein to keep my repository on the simpler side.

- The following discussion will assume that the '.yazerc-z3plus-cpm3' start-up disk assignment looks like the following:
  
  ```
    mount a disks_rcl_z3plus/rcl_boot_disk.ydsk
    mount b disks_rcl_z3plus/rcl_cpm3_sys.ydsk
    mount c disks_rcl_z3plus/rcl_utils.ydsk
    mount d disks_rcl_z3plus/rcl_cypher_src.ydsk
    mount e disks_rcl_z3plus/rcl_big_utils_collection.ydsk
    mount f disks_rcl_z3plus/rcl_scratch.ydsk
    go
  ```

- You will need access to the Microsoft Z80 assembler (m80.com) and linker (l80.com). The relocating assembler (rmac.com) and linker (link.com) is provided along with the Motel Computers CP/M-3 source code diskette. 

- Start-up the Yaze-AG CP/M-3 emulator and change to drive D0: which I've assigned as my Cypher CP/M-3 source code disk.

- You will need to locate your original  8" software distribution disks provided by Motel Computers for CP/M-3 which has a reference in the file "ldrbios.asm" to "Version 2.1, I.A. Cunningham 05-Dec-1985". That floppy disk will include all of the files needed to compile and link CP/M-3 for the Cypher computer, a subset of which are named:

```
bioskrnl.asm    boot.asm        cboot.com       cboot.mac       cdbios.mac      cdboot.mac      chario.asm
copysys.com     cpm3.sys        cpm3.txt        cpmldr.com      cpmldr.mac      diskio3.asm     drvtbl.asm
gencpm.dat      hdisk3.asm      ldrbios.asm     ldrbiosk.asm    ldrdrvtb.asm    link.com        loadsys.asm
loadsys.com     move.asm        rdisk3.asm      rldrbios.asm    rmac.com        scb.asm
```

- In this GitHub repository I am providing my own versions of boot.asm, diskio3.asm and drvtbl.asm which I had modified back in the day for (1) Cypher/Sorcerer 8" floppies on drives A and B, (2) 80-track 5-1/4" Piped-Piper on drive C, (4) 40-track Morrow on drive D, (5) a RAM disk on drive E and (6) Two 11MB hard disk partitions on drives F and G.

- In the following explanation the files to be copied to/from the Windows environment will be first copied to the "tmp" sub-directory residing within the Yaze-AG home directory folder.

- Copy the files from the Motel Computers CP/M-3 source 8" floppy disk to a "tmp" directory on your Windows machine which has been made available to Yaze-AG. Then copy them into the CP/M virtual drive D0: via the Yaze-AG CP/M command "a:r tmp\\*.*"

- Likewise, copy "rcl-cpm.sub" to Drive D0:

- Optionally copy over and replace my personally modified files: boot.asm, diskio3.asm and drvtbl.asm.

- Read over the info at the top of *rcl-cpm3.sub* file for general reference. 

- While on drive D0: execute the command "*rcl-cpm3.sub*" on the CP/M command line. That will compile and link the system track image "*systrks.img*" file and the "*cpm3.sys*" file. The CP/M batch file will copy these files back over to the Windows "tmp" sub-directory in the Yaze-AG main directory.
  
  ```
    a:w tmp/cpm3.sys b
    a:w tmp/systrks.img b 
  ```
  
    where "a:w" is the Yaze-AG "write.com" program and "a:r" if their "read.com" program.

- On the Windows side of things, copy "*systrks.img*" over to the local "*cypher_boot_disk_contents*" directory and '*cpm3.sys*' to "*cypher_boot_disk_contents\contents*".

- Run "*makedisk.bat*" in the "*cypher_boot_disk_contents*" directory to create the CP/M-3 boot disk image file "*cyphboot.img*". If you want to add more CP/M runtime files to the CP/M disk then do so in this batch file. 

# How to Set up the HxC Floppy Emulator Disk Image

- The HxC floppy emulator is set up as Drive A for the Cypher SBC.

- Run *hxcfloppyemulator.exe*

- Click on the "SD HxC Floppy Emulator Settings" UI button and then:
  
  - Enable the checkboxes for "Force loading STARTUPA.HFE" and "Force loading STARTUPB.HFE" if you wish these files to be auto-loaded at power-on.
  
  - Optionally enable "2 drives emulation"
  
  - "Save config file" and copy to root of the SDCARD ("HXCSDFE.CFG")

- Convert and copy the resulting raw binary "*cyphboot.img*" file over to the SDCARD of the HxC emulator as "STARTUPA.HFE" by way of the hxcfloppyemulator.exe program and as explained below. Note, these .img files must be of the uncompressed variation.
  
  - Click on the "Load Raw Image" UI button and set up these options:
  
  ```
    Track
    Bitrate = 500000
    RPM = 300
    Tracks = 77
    Sectors per track = 8
    Skew = 0 (track skew)
    Number of sides = 1
    Sector size = 1024
    Sector ID start = 1
    Interleave = 3 (sector interleave)
    PRE-Gap lenght = 0
    Auto-Gap enabled = True
  ```
  
  - Press "Save config" and save to the root of the SDCARD for safe keeping as 'rcl_cypher_floppy_profile.fpf'
  
  - Press "Load RAW file" and choose the binary CP/M image file "*cyphboot.img*"
  
  - Press "Export" from the main panel and save the STARTUPA.HFE file to the root of the SDCARD

- Put the SDCARD into the emulator and select the "*cyphboot.hfe*" file for Drive A0 (the STARTUPA.HFE and STARTUPB.HFE files will be automatically loaded). 

- Turn on the Cypher computer, press "s" to switch from the 68k CPU to the Z80 CPU and then "b1" to boot off the HxC emulator. If you do just "b" then the computer will try to boot off the hard disk which is fine as long as the hard disk is powered up.

- Don't forget to do "park.com" to park the heads of the hard disk before powering off.
