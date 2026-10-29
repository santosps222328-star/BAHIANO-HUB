"""Extração estática: não executa os hubs. Tokens preservam offsets para auditoria."""
import re, json, hashlib, unicodedata
from pathlib import Path
ROOT=Path('/home/user/bahiano-sources-review')
OUT=Path('/home/user/bahiano-farm')
TOKEN=re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_][\w]*|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?|\s+|.',re.S)
METHODS={'AddToggle','NewToggle','Toggle','AddButton','NewButton','Button','AddDropdown','NewDropdown','Dropdown','AddSlider','NewSlider','Slider','AddInput','NewInput','Input','Textbox','TextBox','AddColorpicker','Colorpicker','NewColorPicker','AddKeybind'}
def text(t):
 s=t[0]
 if not s.startswith(('"',"'")):return None
 return s[1:-1].replace('\\"','"').replace("\\'", "'").replace('\\n','\n').replace('\\t','\t')
def norm(s):
 s=unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower()
 return re.sub(r'[^a-z0-9]','',s)
def category(label):
 s=norm(label)
 for cat,words in [('PvP',['aimbot','player','pvp','spectate','fov','trialplayers']),('Raça e V4',['race','v4','trial','gear','mirage','lever','moon','mink','skypiea','cyborg','ghoul','drago','dojo']),('Raids',['raid','chip','dungeon','awak','law','kill aura']),('Frutas',['fruit','trai','demonfruit']),('Eventos marítimos',['sea beast','seabeast','seaevent','shark','piranha','leviathan','terror','boat','kitsune','volcan','prehistoric','azure','ember','dino','dragon egg','frozen']),('Loja e estilos',['buy','craft','mua','superhuman','deathstep','godhuman','sharkman','sanguine','electro','blackleg','dragonclaw','dragontalon','electricclaw']),('Farm e itens',['farm','mastery','material','boss','bone','chest','berry','ectoplasm','yama','tushita','saber','cdk','guitar','soul','dough','cake','indra','elite','observation','level','quest','melee','sword','gun','stats','defense']),('Viagem e servidor',['tele','tween','travel','island','portal','hop','rejoin','job','server','team','pirate','marine'])]:
  if any(norm(w) in s for w in words):return cat
 return 'Configurações e utilitários'
records=[]; actions={}; source_info=[]
for path in sorted(ROOT.glob('*.txt')):
 source=path.read_text(errors='replace')
 tokens=[(m.group(),m.start(),m.end()) for m in TOKEN.finditer(source) if not m.group().isspace() and not m.group().startswith('--')]
 pairs={}; stack=[]
 for i,t in enumerate(tokens):
  if t[0] in ('(','{','['):stack.append((t[0],i))
  elif t[0] in (')','}',']') and stack:
   op,k=stack.pop()
   if {'(':')','{':'}','[':']'}[op]==t[0]:pairs[k]=i
 for i in range(len(tokens)-3):
  if tokens[i][0]!=':' or tokens[i+1][0] not in METHODS or tokens[i+2][0]!='(':continue
  start=i+2;end=pairs.get(start)
  if end is None:continue
  method=tokens[i+1][0];subset=tokens[start+1:end]
  # Title/Name de tabela de opções, ou primeiro argumento textual nas bibliotecas antigas.
  label=None
  for k in range(len(subset)-2):
   if subset[k][0] in ('Title','Name','Text') and subset[k+1][0]=='=' and text(subset[k+2]) is not None:
    label=text(subset[k+2]);break
  if label is None and subset:label=text(subset[0])
  if not label or label in ('Toggle','Slider','Dropdown','Input','Default','Name'):continue
  body=source[tokens[start][1]:tokens[end][2]]
  line=source.count('\n',0,tokens[i][1])+1
  record={'label':label,'key':norm(label),'category':category(label),'kind':method,'source':path.name,'line':line}
  # Só callbacks de UMA chamada CommF_ com argumentos literais são portados automaticamente.
  callback=re.search(r'Callback\s*=\s*function\(\)\s*([^\n]*(?:\n.*?)*?)\s*end\s*}',body,re.S)
  if 'Button' in method and callback:
   cb=callback.group(1).strip().rstrip(';')
   pure=re.fullmatch(r'(?:game:GetService\("ReplicatedStorage"\)|replicated|game\.ReplicatedStorage)\.Remotes\.CommF_:InvokeServer\((.*?)\)',cb,re.S)
   if pure:
    args=re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|-?\d+(?:\.\d+)?|true|false',pure.group(1))
    remainder=re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|-?\d+(?:\.\d+)?|true|false','',pure.group(1))
    if not re.sub(r'\s|,','',remainder):
     try:
      values=[text((a,0,0)) if a.startswith(('"',"'")) else (a=='true' if a in ('true','false') else float(a) if '.' in a else int(a)) for a in args]
      if values and isinstance(values[0],str):
       signature=json.dumps(values,ensure_ascii=False)
       record['action']=signature
       item=actions.setdefault(signature,{'label':label,'args':values,'sources':[],'category':category(label)})
       item['sources'].append({'file':path.name,'line':line,'label':label})
     except ValueError:pass
  records.append(record)
 source_info.append({'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'controls':sum(r['source']==path.name for r in records)})
# Agrupamento exato normalizado; aliases semânticos recebem o mesmo implementationId depois.
groups={}
for r in records:
 item=groups.setdefault(r['key'],{'label':r['label'],'category':r['category'],'aliases':[],'sources':[]})
 if r['label'] not in item['aliases']:item['aliases'].append(r['label'])
 item['sources'].append({'file':r['source'],'line':r['line'],'kind':r['kind']})
 if r.get('action'):item['action']=r['action']
ordered=sorted(actions.items(),key=lambda kv:kv[1]['label'])
for index,(sig,act) in enumerate(ordered,1):act['id']='action'+str(index)
for g in groups.values():
 if g.get('action'):g['implementation']=actions[g.pop('action')]['id']
for r in records:
 if r.get('action'):r['implementation']=actions[r.pop('action')]['id']
SUPPORTED={
 'Farm / Auto Farm Level':['Auto Farm Level','Auto Level','Farm Cấp Độ'],
 'Farm / alvos — NPCs locais, sem invocar boss':['Auto Farm Nearest','Kill Near','Farm Quái Gần Nhất','Auto Bone','Auto Bones','Farm Xương','Auto Materials','Auto Material','Auto Farm Ectoplasm','Farm Ectoplasm','Choose Material','Chọn Nguyên Liệu Để Farm','Select Boss','Chọn Boss Để Farm','Auto Farm Boss'],
 'Farm / escolha de equipamento':['Select Weapon','Weapon','Choose Weapon Type','Chọn Vũ Khí'],
 'Utilitários / Anti AFK':['Anti AFK','Anti Afk'],
 'Utilitários / FPS Booster reversível':['Fps Booster','Boost FPS','Turn on Fast Mode'],
 'Utilitários / iluminação local':['Remove Fog','Xóa Sương Mù','Turn on Full Bright'],
 'Utilitários / ESP':['Esp Player','ESP Player','Esp Players','Esp Fruits','Esp Devil Fruit','ESP Fruits','Esp Fruit','Esp Island','Esp Island Location','Esp Island Location','Esp Islands'],
 'Utilitários / Job ID':['Copy Job ID','Copy Job Id','Copy JobID'],
 'Utilitários / Rejoin (confirmado por 2 cliques)':['Rejoin Server'],
 'Utilitários / Auto Stats (experimental)':['Auto Melee','Auto Defense','Auto Sword','Auto Swords','Auto Gun','Auto Blox Fruit','Auto Demon Fruit'],
 'Frutas / consultar e comprar estoque (manual, experimental)':['Select Fruit','Select Fruit Stock','Buy Basic Stock','Buy Fruit Sniper'],
 'Frutas / guardar com OriginalName reconhecido (experimental)':['Store Fruit','Auto Store Fruit','Auto Keep Fruit'],
 'Frutas / random manual (experimental)':['Random Fruit'],
 'Frutas / raids — comprar chip (manual, experimental)':['Select Chip','Buy Chip','Buy Dungeon Chips [Beli]'],
 'Jogadores / câmera — Spectate local':['Spectate Player','Spectate Choose Players'],
}
support={norm(alias):implementation for implementation,aliases in SUPPORTED.items() for alias in aliases}
for group in groups.values():
 if not group.get('implementation') and norm(group['label']) in support:group['implementation']=support[norm(group['label'])]
for record in records:
 if not record.get('implementation') and record['key'] in support:record['implementation']=support[record['key']]
report={'sources':source_info,'records':records,'features':list(groups.values()),'actions':[a for _,a in ordered],
 'note':'Inventário estático de controles. Não comprova correção, licença, compatibilidade ou execução.'}
(OUT/'AUDITORIA').mkdir(exist_ok=True)
(OUT/'AUDITORIA'/'inventario.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
def lua(value):
 if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
 if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
 if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
 if value is None:return 'nil'
 if isinstance(value,bool):return str(value).lower()
 return str(value)
(OUT/'Data'/'SourceActions.luau').write_text('-- Extraído estaticamente de callbacks simples; não executa os hubs.\nreturn '+lua(report['actions'])+'\n')
(OUT/'Data'/'FeatureCatalog.luau').write_text('-- Inventário de controles dos seis hubs. Sem callbacks externos.\nreturn '+lua(report['features'])+'\n')
print('CONTROLS',len(records),'DISTINCT NORMALIZED',len(groups),'PURE REMOTE ACTIONS',len(actions))
for source in source_info:print(source['file'],source['controls'])