from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import shutil
root=Path(__file__).resolve().parent
out=root.parent/'source/doudizhu/assets/art'
# Remove only the connected white exterior; preserve cream painted interiors.
for name in ['title','plaque']:
 im=Image.open(root/'originals'/f'{name}.png').convert('RGB')
 mask=Image.new('L',im.size); px=im.load(); m=mask.load()
 for y in range(im.height):
  for x in range(im.width):
   r,g,b=px[x,y]
   if min(r,g,b)>233 and max(r,g,b)-min(r,g,b)<17:m[x,y]=255
 ImageDraw.floodfill(mask,(0,0),128,thresh=0)
 alpha=mask.point(lambda p:0 if p==128 else 255)
 im=im.convert('RGBA');im.putalpha(alpha);im=im.crop(alpha.getbbox())
 if name=='title':im.resize((900,354)).save(out/'menu-title-v3.webp',lossless=True)
 else:im.resize((900,312)).save(out/'menu-plaque-v3.webp',lossless=True)
fontpath='/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
labels={'single':'单机','create':'创建房间','join':'加入房间','settings':'设置','difficulty':'难度','rules':'规则'}
for key,text in labels.items():
 font=ImageFont.truetype(fontpath,90,index=2)
 box=font.getbbox(text); w=box[2]-box[0]+16;h=box[3]-box[1]+16
 im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im)
 d.text((8-box[0],10-box[1]),text,font=font,fill='#fff3cc',stroke_width=1)
 d.text((8-box[0],7-box[1]),text,font=font,fill='#604a2d')
 im.save(out/f'menu-{key}-v3.webp',lossless=True)
shutil.copy('/usr/share/doc/fonts-noto-cjk/copyright',root.parent/'source/doudizhu/assets/licenses/Noto-CJK-OFL.txt')
