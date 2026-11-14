#!/usr/bin/env python3
"""Float32 DouZero-WP exporter; original network unchanged.
Modified by this project: transposed tensor storage, binary format and references.
Upstream Apache-2.0: see assets/licenses and upstream_models.py.
Requires numpy + CPU torch; no inference runtime is added to the app.
"""
import argparse, hashlib, io, json, pathlib, struct, urllib.request
import numpy as np
import torch
from upstream_models import LandlordLstmModel, FarmerLstmModel
MIRROR='57b3914046c2a0877016b8b8830fd07cf5b0ba08'
CODE='718a5c920bf3361e34178a38f3b80458e176b351'
ROLES=['landlord','landlord_down','landlord_up']
EXPECTED={'landlord': '132e26479fcb69f457ddbf1ad32a7bdc3aa73cde80a28cc91f29a62c6075955a', 'landlord_down': '964720faf583f4905662c94aaf73b1a97352b76ae3686fcc949beabbacdd95d1', 'landlord_up': 'b849ea518e66f088d635d3a29956da880f7b5ca89fabc5f70fc356c106ca6a15'}
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--weights',type=pathlib.Path);p.add_argument('--out',type=pathlib.Path,default=pathlib.Path('assets/models'));a=p.parse_args()
 a.out.mkdir(parents=True,exist_ok=True);torch.set_num_threads(1);torch.manual_seed(2000)
 report={'code_commit':CODE,'mirror_commit':MIRROR,'format':'DZ01, Float32 LE, input-major weights, no quantization','roles':{},'references':[]}
 for role in ROLES:
  url=f'https://huggingface.co/palemoky/douzero-baselines/resolve/{MIRROR}/checkpoints/douzero_WP/{role}.ckpt'
  data=(a.weights/f'{role}.ckpt').read_bytes() if a.weights else urllib.request.urlopen(url).read()
  assert sha(data)==EXPECTED[role],f'{role}: source hash mismatch'
  state=torch.load(io.BytesIO(data),map_location='cpu',weights_only=True)
  model=LandlordLstmModel() if role=='landlord' else FarmerLstmModel();model.load_state_dict(state,strict=True);model.eval()
  arrays=[];metadata={'role':role,'tensors':[]}
  for name,tensor in state.items():
   arr=tensor.detach().numpy();arr=arr.T.copy() if arr.ndim==2 else arr.copy();arr=arr.astype('<f4');arrays.append(arr.tobytes())
   assert np.isfinite(arr).all()
   metadata['tensors'].append({'name':name,'shape':list(arr.shape),'length':int(arr.size)})
  meta=json.dumps(metadata,separators=(',',':')).encode();meta+=b' '*((-len(meta))%4)
  binary=b'DZ01'+struct.pack('<I',len(meta))+meta+b''.join(arrays);(a.out/f'{role}.dzf').write_bytes(binary)
  outputs=[]
  for i in range(12):
   z=torch.randint(0,2,(1,5,162)).float();x=torch.randint(0,2,(1,373 if role=='landlord' else 484)).float()
   with torch.no_grad():value=model(z,x,return_value=True)['values'].item()
   outputs.append(value);report['references'].append({'role':role,'z':z.flatten().tolist(),'x':x.flatten().tolist(),'value':value})
  report['roles'][role]={'url':url,'checkpoint_sha256':sha(data),'binary_sha256':sha(binary),'bytes':len(binary),'parameters':sum(x.numel() for x in state.values()),'tensors':metadata['tensors'],'reference_output_range':[min(outputs),max(outputs)]}
 (a.out/'manifest.json').write_text(json.dumps({k:v for k,v in report.items() if k!='references'},indent=2)+'\n')
 pathlib.Path('tool/model/reference.json').write_text(json.dumps(report['references'],separators=(',',':'))+'\n')
 print(json.dumps(report['roles'],indent=2))
if __name__=='__main__':main()
