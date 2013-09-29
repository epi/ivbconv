import os, sys
import Image

img = Image.open(sys.argv[1])
try:
	exif = img._getexif()
	if 0x112 in exif:
		if exif[0x112] == 6:
			img = img.transpose(Image.ROTATE_270)
except AttributeError:
	pass
width = img.size[0]
height = img.size[1]
newwidth = 0
newheight = 0
if height * 640 < width * 480:
	newwidth = 320
	newheight = height * 640 / width
else:
	newheight = 480
	newwidth = width * 240 / height
img = img.resize((newwidth, newheight), Image.ANTIALIAS)
if newwidth < 320:
	out = Image.new("RGB", (320, newheight), "black")
	out.paste(img, (160 - newwidth / 2, 0, 160 - newwidth / 2 + newwidth, newheight))
	img = out
img.save(sys.argv[2])
