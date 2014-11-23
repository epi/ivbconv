# Makefile for ivbconv
#
#	Author: Adrian Matoga
#
#	Poetic License:
#
#	This work 'as-is' we provide.
#	No warranty express or implied.
#	We've done our best,
#	to debug and test.
#	Liability for damages denied.
#
#	Permission is granted hereby,
#	to copy, share, and modify.
#	Use as is fit,
#	free or for profit.
#	These rights, on this notice, rely.

DMD := dmd

src := dos.d flashpack.d freeimage.d ivbconv.d outputformat.d vbxe.d

BUILD_OS  := $(if $(WINDIR),windows,$(shell uname -s | tr A-Z a-z))

exesuf    := $(if $(filter $(BUILD_OS),windows),.exe,)
ldflags   := $(if $(filter $(BUILD_OS),windows),FreeImage.lib,-L-lfreeimage)
progname  := ivbconv$(exesuf)
dflags    := -release
#dflags    := -g

all: $(progname) README.html
.PHONY: all

$(progname): $(src) ivb2.obx vb.obx ivb216.obx vb16.obx
	$(DMD) $(src) -of$@ $(dflags) -J. $(ldflags)

%.obx: %.asx
	xasm $< /o:$@ /d:HIRES=0

%16.obx: %.asx
	xasm $< /o:$@ /d:HIRES=1

README.html: README.asciidoc
	asciidoc $<

clean:
	rm -f $(progname) *.o *.obj *.obx README.html
.PHONY: clean

