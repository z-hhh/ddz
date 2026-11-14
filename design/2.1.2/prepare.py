from PIL import Image,ImageOps
from pathlib import Path
root=Path(__file__).resolve().parent
im=Image.open(root/'originals/home-master.png').convert('RGB')
assert im.size==(2560,1440)
im.save(root.parent/'source/doudizhu/assets/art/home-scene-v4.webp',quality=92)
for w,h in [(844,390),(640,360)]:
 ImageOps.fit(im,(w*3,h*3),method=Image.Resampling.LANCZOS).save(root/f'home-{w}x{h}@3x.png')
