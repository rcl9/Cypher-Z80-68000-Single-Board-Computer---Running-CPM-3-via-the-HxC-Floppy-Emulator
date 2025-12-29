rem
rem This requires the "CP/M tools" be installed on your machine
rem

del cyphboot.bin

mkfs.cpm.exe -f cypher -b systrks.img cyphboot.img

rem -- CP/M-3 files
cpmcp -f cypher cyphboot.img contents\ccp.com 0:ccp.com
cpmcp -f cypher cyphboot.img contents\cpm3.sys 0:cpm3.sys
cpmcp -f cypher cyphboot.img contents\d.com 0:dir.com
cpmcp -f cypher cyphboot.img contents\park.com 0:park.com
cpmcp -f cypher cyphboot.img contents\diskinfo.com 0:diskinfo.com
cpmcp -f cypher cyphboot.img contents\nsw.com 0:nsw.com
cpmcp -f cypher cyphboot.img contents\copy.com 0:copy.com
cpmcp -f cypher cyphboot.img contents\erase.com 0:erase.com
cpmcp -f cypher cyphboot.img contents\era.com 0:era.com
cpmcp -f cypher cyphboot.img contents\ren.com 0:ren.com
cpmcp -f cypher cyphboot.img contents\type.com 0:type.com
cpmcp -f cypher cyphboot.img contents\typesq.com 0:typesq.com

rem -- CP/M 68k files 
cpmcp -f cypher cyphboot.img contents\cpm.sys 0:cpm.sys
cpmcp -f cypher cyphboot.img contents\cpm68k.com 0:cpm68k.com
cpmcp -f cypher cyphboot.img contents\pip.68k 0:pip.68k
cpmcp -f cypher cyphboot.img contents\stat.68k 0:stat.68k
cpmcp -f cypher cyphboot.img contents\comp68.68k 0:comp68.68k
cpmcp -f cypher cyphboot.img contents\cpm80.68k 0:cpm80.68k

rem -- Unknown 
cpmcp -f cypher cyphboot.img contents\cpmldr.com 0:cpmldr.com

rem -- List the contents of our new CP/M binary image
cpmls -f cypher cyphboot.img


