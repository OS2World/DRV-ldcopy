#
# Makefile for LDCOPY device driver
#
# Bob Eager   April 2003
#                          
MFLAGS		= /n /p /t /w2
#
ldcopy.sys:	ldcopy.obj ldcopy.def ldcopy.lnk
		link /batch /nologo @ldcopy.lnk
#
ldcopy.lnk:	makefile
		echo ldcopy      > ldcopy.lnk
		echo ldcopy.sys >> ldcopy.lnk
		echo ldcopy/map >> ldcopy.lnk
		echo os2286        >> ldcopy.lnk
		echo ldcopy.def >> ldcopy.lnk
#
ldcopy.obj:	ldcopy.asm
		masm $(MFLAGS) ldcopy,ldcopy,ldcopy;
#
clean:
		erase *.obj *.lst *.lnk *.map
#
# End of makefile for LDCOPY device driver
#
