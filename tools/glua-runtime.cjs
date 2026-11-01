// Execution-only GLua adapter. The old normalize() intentionally substitutes
// break for continue for syntax scans; that is unsafe for real health loops.
const {normalize}=require('./glua.cjs');
const parser=require('luaparse');
module.exports=function runtime(source){
 const protectedTokens=/--\[(=*)\[[\s\S]*?\]\1\]|\[(=*)\[[\s\S]*?\]\2\]|--[^\r\n]*|\/\/[^\r\n]*|\/\*[\s\S]*?\*\/|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|\bcontinue\b/g;
 let text=normalize(source.replace(protectedTokens,t=>t==='continue'?'__ix_continue__()':t));
 const ast=parser.parse(text,{luaVersion:'5.2',ranges:true});
 const edits=[],loops=new Map();let counter=0;
 function walk(node,stack){
  if(!node||typeof node!=='object')return;
  if(Array.isArray(node)){for(const child of node)walk(child,stack);return;}
  if(node.type==='FunctionDeclaration')stack=[];
  if(['ForGenericStatement','ForNumericStatement','WhileStatement','RepeatStatement'].includes(node.type))stack=[...stack,node];
  if(node.type==='CallStatement'&&node.expression.base.name==='__ix_continue__'){
   const loop=stack.at(-1);if(!loop)throw Error('continue outside loop');
   if(!loops.has(loop))loops.set(loop,'__ix_continue_'+(++counter));
   edits.push([node.range[0],node.range[1],'goto '+loops.get(loop)]);
  }
  for(const [key,value]of Object.entries(node))if(key!=='range'&&key!=='loc')walk(value,stack);
 }
 walk(ast,[]);
 for(const [loop,label]of loops){
  if(loop.type==='RepeatStatement')throw Error('Repeat/until continue needs a scope-aware condition transform');
  edits.push([loop.body[0].range[0],loop.body[0].range[0],'do ']);
  const end=loop.range[1]-3;
  if(text.slice(end,loop.range[1])!=='end')throw Error('Unexpected loop boundary');
  edits.push([end,end,'end ::'+label+':: ']);
 }
 for(const [start,end,replacement]of edits.sort((a,b)=>b[0]-a[0]))text=text.slice(0,start)+replacement+text.slice(end);
 return text;
};
