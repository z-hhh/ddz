"""原创程序合成音效；不使用采样或第三方音乐。输出 WAV 采用 CC0-1.0。"""
import math, random, wave, struct
from pathlib import Path
SR=22050
rng=random.Random(1700)
DUR={'click':.045,'select':.035,'deal':.32,'play':.13,'pass':.10,'turn':.24,'bomb':.42,'rocket':.60,'spring':.72,'win':.78,'lose':.55}
root=Path(__file__).resolve().parents[1]/'assets/audio';root.mkdir(exist_ok=True)
for name,duration in DUR.items():
 data=[]; previous=0.0
 for i in range(int(SR*duration)):
  t=i/SR; noise=rng.uniform(-1,1); previous=.75*previous+.25*noise
  s=0.0
  if name in ('click','select','play','pass'):
   freq={'click':1050,'select':1400,'play':360,'pass':240}[name]
   s=(math.sin(2*math.pi*freq*t)*.65+previous*.5)*math.exp(-t/(duration/5))
  elif name=='deal':
   s=previous*sum(math.exp(-max(0,t-k*.055)/.015) if t>=k*.055 else 0 for k in range(5))
  elif name=='bomb':
   s=(.6*math.sin(2*math.pi*70*t)+previous)*math.exp(-t*9)
   s+=.2*math.sin(2*math.pi*310*t)*math.exp(-t*14)
  elif name=='rocket':
   s=.3*math.sin(2*math.pi*(260*t+1100*t*t))*math.sin(math.pi*t/duration)**2
   s+=previous*.35*math.exp(-t*7)
  else:
   notes={'turn':[660,880],'spring':[523,587,659,784,880],'win':[523,659,784,1046],'lose':[392,330,262]}[name]
   step=duration/(len(notes)+.7)
   for k,f in enumerate(notes):
    q=t-k*step
    if q>=0:
     s+=(math.sin(2*math.pi*f*q)+.25*math.sin(2*math.pi*f*2.76*q))*math.exp(-q*14)*min(q/.006,1)*.5
  # 轻微短回响在下方混入，边缘淡入淡出避免爆音。
  s*=min(t/.002,1,max(0,(duration-t)/.012))
  data.append(s)
 dry=data[:];delay=int(.028*SR)
 for i in range(delay,len(data)): data[i]+=.12*dry[i-delay]
 peak=max(max(abs(v) for v in data),.01)
 raw=b''.join(struct.pack('<h',int(max(-1,min(1,v/peak*.65))*32767)) for v in data)
 with wave.open(str(root/f'{name}.wav'),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(raw)
print(sum(p.stat().st_size for p in root.glob('*.wav')), 'bytes')
