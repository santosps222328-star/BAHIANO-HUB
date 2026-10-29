import fs from 'node:fs';
import path from 'node:path';
import { LuauState } from 'luau-web';
const root=path.resolve(process.argv[2] || '/home/user/bahiano-farm');
const support=import.meta.dirname;
const testsPath=fs.existsSync(path.join(support,'tests.luau')) ? path.join(support,'tests.luau') : path.join(support,'testes-luau.txt');
const sourceDir=fs.existsSync(root+'/AUDITORIA/Fontes') ? root+'/AUDITORIA/Fontes' : '/home/user/bahiano-sources-review';
const state=await LuauState.createAsync();
const files=[];
function scan(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){
  if(item.name==='AUDITORIA')continue;
  const full=path.join(dir,item.name);
  if(item.isDirectory())scan(full);else if(/\.(lua|luau)$/.test(full)) files.push(full);
}}
scan(root);
try {
  for(const file of files){state.loadstring(fs.readFileSync(file,'utf8'),'@'+file,true);}
  console.log(`COMPILE PASS: ${files.length} Lua/Luau files (including preserved optimizer and library).`);
  const modules={Config:'Modules/FarmConfig.luau',Resolver:'Modules/QuestResolver.luau',Controller:'Modules/AutoFarm.luau',Quests:'Data/QuestFallback.luau',
    Services:'Modules/HubServices.luau',Target:'Modules/TargetFarm.luau',Integration:'Modules/SourceIntegration.luau',Extras:'Modules/FruitRaid.luau',
    Actions:'Data/SourceActions.luau',Catalog:'Data/FeatureCatalog.luau',Targets:'Data/FarmTargets.luau'};
  let suite='';
  for(const [name,file] of Object.entries(modules))suite+=`local ${name} = (function()\n${fs.readFileSync(path.join(root,file),'utf8')}\nend)()\n`;
  suite+=fs.readFileSync(testsPath,'utf8');
  const result=await state.loadstring(suite,'@offline-tests',true)();
  console.log('OFFLINE TEST RESULT:', result);
  const originals=[];
  for(const file of fs.readdirSync(sourceDir)){
    if(!file.endsWith('.txt'))continue;
    try {state.loadstring(fs.readFileSync(sourceDir+'/'+file,'utf8'),'@original/'+file,true);originals.push({file,compile:'pass'});}
    catch(error){originals.push({file,compile:'fail',error:String(error)});}
  }
  fs.writeFileSync(root+'/AUDITORIA/compilacao-originais.json',JSON.stringify(originals,null,2));
  fs.writeFileSync(root+'/AUDITORIA/testes.json',JSON.stringify({compiledFiles:files.length,result,originalsExecuted:false,robloxRuntimeTested:false},null,2));
  console.log('Original source compilation (never executed):',originals.map(x=>x.file+': '+x.compile).join('\n'));
} finally {state.destroy();}