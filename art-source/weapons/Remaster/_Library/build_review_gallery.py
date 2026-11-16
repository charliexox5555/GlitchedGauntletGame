from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE=Path(__file__).resolve().parent.parent
ORDER=['Vandal','Classic','Bulldog','Phantom','Guardian','Stinger','Spectre','Shorty','Ghost',
       'Sheriff','Judge','Bucky','Marshal','Outlaw','Operator','Ares','Odin','Knife']
font=lambda size: ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',size)
for page in range(2):
    canvas=Image.new('RGB',(2736,1962),(31,36,44))
    draw=ImageDraw.Draw(canvas)
    draw.text((28,18),f'GUN REMASTER / REVIEW {page+1} OF 2',font=font(36),fill=(235,241,247))
    for i,gun in enumerate(ORDER[page*9:page*9+9]):
        x=24+(i%3)*904; y=90+(i//3)*618
        draw.rectangle((x,y,x+879,y+599),fill=(41,47,57),outline=(77,88,101),width=1)
        draw.text((x+16,y+4),gun.upper(),font=font(29),fill=(232,239,246))
        hero=Image.open(BASE/gun/'renders/hero.png').convert('RGB')
        hero=hero.resize((880,550),Image.Resampling.LANCZOS)
        canvas.paste(hero,(x,y+44))
    path=BASE/'_Library'/f'review-gallery-{page+1:02d}.png'
    canvas.save(path)
    print(path)
