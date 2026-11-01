const assert = require('node:assert/strict');
const {DatabaseSync} = require('node:sqlite');
const {native} = require('./restored-test-runner.cjs');

// Exercise the query taken from production against native SQLite as well as
// the actual Lua allocator/loader. No existing game database is opened.
module.exports = suite => {
 const file = 'helix/gamemode/game/items/sh_item.lua';
 const allocator = native(file, '\tfunction Item:GenerateID()', '\tfunction Item:LoadInstanceByID');
 const loader = native(file, '\tfunction Item:LoadInstanceCount()', '\tfunction Item:Instance(');
 const query = loader.match(/mysql:RawQuery\("([^"]+)"/)[1];
 const db = new DatabaseSync(':memory:');
 let emptyRows, populatedRows;
 try {
  db.exec('CREATE TABLE ix_items (item_id INTEGER PRIMARY KEY, data TEXT)');
  emptyRows = db.prepare(query).all();
  assert.equal(emptyRows.length, 1);
  assert.equal(emptyRows[0].max_id, 0);
  db.exec("WITH RECURSIVE n(id) AS (VALUES(1) UNION ALL SELECT id + 1 FROM n WHERE id < 10000) INSERT INTO ix_items SELECT id * 2, '{}' FROM n");
  populatedRows = db.prepare(query).all();
  assert.equal(populatedRows.length, 1);
  assert.equal(populatedRows[0].max_id, 20000);
  assert.equal(populatedRows[0].max_id, db.prepare('SELECT item_id FROM ix_items ORDER BY item_id DESC LIMIT 1').get().item_id);
  db.exec('DELETE FROM ix_items WHERE item_id = 20000');
  assert.equal(db.prepare(query).get().max_id, 19998);
 } finally { db.close(); }

 const setup = `
 Item={instances={},instance_count=0}
 errors={};function ErrorNoHalt(message) errors[#errors+1]=message end
 queries={};callbacks={};mysql={module='mysqloo'}
 function mysql:RawQuery(query,callback)
  eq(query,${JSON.stringify(query)})
  queries[#queries+1]=query;callbacks[#callbacks+1]=callback
 end
 ${allocator}
 ${loader}
 `;

 suite('Core ID aggregate returns one row for empty and 10,000-item native SQLite tables', [], `
 Item:LoadInstanceCount();eq(#queries,1);eq(Item.idsReady,nil)
 callbacks[1]({{max_id='${emptyRows[0].max_id}'}})
 eq(Item.idsReady,true);eq(Item.idsLoading,nil);eq(Item:GenerateID(),1)
 Item:LoadInstanceCount();callbacks[2]({{max_id='${populatedRows[0].max_id}'}})
 eq(Item:GenerateID(),20001);eq(#errors,0)
 `, setup);

 suite('Core ID aggregate accepts numeric and string maxima without rewinding allocated IDs', [], `
 Item:LoadInstanceCount();callbacks[1]({{max_id=17}})
 eq(Item:GenerateID(),18)
 Item:LoadInstanceCount();callbacks[2]({{max_id='12'}})
 eq(Item.instance_count,18);eq(Item:GenerateID(),19)
 Item:LoadInstanceCount();callbacks[3]({{max_id=0}})
 eq(Item.instance_count,19);eq(Item:GenerateID(),20)
 `, setup);

 suite('Delayed ID lookup is single-flight, survives library reload and preserves newer live IDs', [], `
 eq(Item:GenerateID(),nil);eq(Item:GenerateID(),nil);eq(#queries,1)
 ${loader}
 eq(Item:GenerateID(),nil);eq(#queries,1)
 Item.instance_count=900;Item.instances[1200]={}
 callbacks[1]({{max_id='315'}})
 eq(Item.instance_count,900);eq(Item:GenerateID(),1201)
 eq(Item:GenerateID(),1202);eq(#queries,1)
 `, setup);

 const invalid = [
  ['false', 'false'], ['nil', 'nil'], ['empty rowset', '{}'],
  ['missing value', '{{}}'], ['NULL value', '{{max_id="NULL"}}'],
  ['non-numeric', '{{max_id="broken"}}'], ['boolean', '{{max_id=true}}'],
  ['negative', '{{max_id=-1}}'], ['fractional', '{{max_id=3.5}}'],
  ['infinite', '{{max_id=math.huge}}'], ['NaN', '{{max_id=0/0}}'],
  ['malformed row', '{42}'], ['non-table rowset', '"broken"']
 ];
 for (const [name, result] of invalid) {
  suite('Core ID aggregate refuses ' + name + ' and permits a fresh successful lookup', [], `
  Item.instance_count=123
  Item:LoadInstanceCount();callbacks[1](${result})
  eq(Item.idsReady,false);eq(Item.idsLoading,nil);eq(Item.instance_count,123);eq(#errors,1)
  eq(Item:GenerateID(),nil);eq(#queries,2)
  callbacks[2]({{max_id='315'}})
  eq(Item:GenerateID(),316);eq(Item.idsReady,true)
  `, setup);
 }

 suite('SQL exceptions and unacknowledged asynchronous errors never unlock ID allocation', [], `
 function mysql:RawQuery() error('simulated SQL failure') end
 local ok=pcall(Item.LoadInstanceCount,Item)
 eq(ok,false);eq(Item.idsReady,nil);eq(Item.idsLoading,true)
 eq(Item:GenerateID(),nil);eq(Item.instance_count,0)
 -- The existing MySQLOO wrapper logs errors without invoking callbacks.
 -- Keeping a request pending must continue to fail closed in that case.
 Item.idsLoading=nil;function mysql:RawQuery() end
 Item:LoadInstanceCount();eq(Item.idsLoading,true)
 eq(Item:GenerateID(),nil);eq(Item.idsReady,nil);eq(Item.instance_count,0)
 `, setup);

 suite('SQLite allocation still independently checks saved maxima after startup or refresh', [], `
 mysql.module='sqlite';local fail=false
 sql={Query=function(query)
  eq(query,${JSON.stringify(query)})
  if fail then return false end
  return {{max_id='315'}}
 end}
 Item.idsReady=nil;eq(Item:GenerateID(),316);eq(#queries,0)
 Item.instances[900]={};eq(Item:GenerateID(),901)
 fail=true;eq(Item:GenerateID(),nil);eq(Item.instance_count,901)
 `, setup);
};
