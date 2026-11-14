#!/usr/bin/env python3
"""Compare Dart observations and game-action scores with pinned upstream DouZero.
Run from app root with --upstream ../../research/DouZero --weights ../../research/weights.
The model network and get_obs are imported from the unmodified upstream checkout.
"""
import argparse,json,sys,pathlib,types
import numpy as np
import torch
p=argparse.ArgumentParser();p.add_argument('--upstream',required=True);p.add_argument('--weights',required=True);a=p.parse_args()
sys.path.insert(0,a.upstream)
from douzero.env.env import get_obs
import importlib.util
spec=importlib.util.spec_from_file_location('official_models',pathlib.Path(a.upstream)/'douzero/dmc/models.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
LandlordLstmModel=module.LandlordLstmModel;FarmerLstmModel=module.FarmerLstmModel
torch.set_num_threads(1)
models={}
for role in ['landlord','landlord_down','landlord_up']:
 m=LandlordLstmModel() if role=='landlord' else FarmerLstmModel();m.load_state_dict(torch.load(pathlib.Path(a.weights)/f'{role}.ckpt',map_location='cpu',weights_only=True),strict=True);m.eval();models[role]=m
rows=json.loads(pathlib.Path('tool/model/observation_traces.json').read_text());max_error=0;actions=0;rank_mismatches=0
for row in rows:
 lord=row['landlord'];seat=row['seat'];roles={lord:'landlord',(lord+1)%3:'landlord_down',(lord+2)%3:'landlord_up'}
 def cards(ids):return [int(c)//4+3 if c<48 else 17 if c<52 else 20 if c==52 else 30 for c in ids]
 history=[cards(x) for x in row['history']];latest=[] if not history else history[-1] if history[-1] else history[-2] if len(history)>1 else []
 unseen=set(range(54))-set(row['hand'])-set(sum(row['played'],[]))
 info=types.SimpleNamespace(player_position=roles[seat],player_hand_cards=cards(row['hand']),other_hand_cards=cards(sorted(unseen)),last_move=latest,last_move_dict={roles[i]:cards(x) for i,x in enumerate(row['last'])},played_cards={roles[i]:cards(x) for i,x in enumerate(row['played'])},num_cards_left_dict={roles[i]:n for i,n in enumerate(row['counts'])},card_play_action_seq=history,bomb_num=row['bombs'],legal_actions=[cards(x) for x in row['candidates']])
 obs=get_obs(info)
 assert np.array_equal(obs['x_no_action'],row['observation']['state'])
 assert np.array_equal(obs['z'].flatten(),row['observation']['history'])
 with torch.no_grad():scores=models[roles[seat]](torch.from_numpy(obs['z_batch']).float(),torch.from_numpy(obs['x_batch']).float(),return_value=True)['values'].numpy().flatten()
 error=np.max(np.abs(scores-np.array(row['scores'])));max_error=max(max_error,float(error));actions+=len(scores);rank_mismatches+=int(np.argmax(scores)!=np.argmax(row['scores']))
 assert error<1e-4
result={'observations':len(rows),'candidates':actions,'roles':sorted(set(x['observation']['role'] for x in rows)),'features_exact_match':True,'max_score_absolute_error':max_error,'argmax_mismatches':rank_mismatches}
pathlib.Path('../../dist/2.0.0-模型一致性.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
