# contact_sheet.py: lays review renders out on one labelled sheet (plain Python + Pillow, no Blender).
#   python contact_sheet.py <out.png> <cols> <cell_w> "Label=path" ...
import sys
from PIL import Image, ImageDraw, ImageFont

out, cols, cw = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
items = [a.split("=", 1) for a in sys.argv[4:]]
ims = []
for label, path in items:
	im = Image.open(path).convert("RGB")
	h = int(im.height * cw / im.width)
	ims.append((label, im.resize((cw, h), Image.LANCZOS)))
rows = [ims[i:i + cols] for i in range(0, len(ims), cols)]
pad, lab = 12, 30
H = sum(max(im.height for _, im in r) + lab + pad for r in rows) + pad
W = cols * (cw + pad) + pad
sheet = Image.new("RGB", (W, H), (24, 25, 28))
d = ImageDraw.Draw(sheet)
try:
	font = ImageFont.truetype("arial.ttf", 20)
except OSError:
	font = ImageFont.load_default()
y = pad
for r in rows:
	x = pad
	for label, im in r:
		d.text((x, y + 4), label, fill=(225, 228, 235), font=font)
		sheet.paste(im, (x, y + lab))
		x += cw + pad
	y += max(im.height for _, im in r) + lab + pad
sheet.save(out)
print(out, sheet.size)
