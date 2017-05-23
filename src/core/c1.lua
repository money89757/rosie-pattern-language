-- -*- Mode: Lua; -*-                                                                             
--
-- c1.lua    rpl compiler internals for rpl 1.1
--
-- © Copyright IBM Corporation 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

local c1 = {}
local c0 = require "c0"

local string = require "string"
local lpeg = require "lpeg"
local common = require "common"
local decode_match = common.decode_match
local throw = common.throw_error

function c1.process_package_decl(typ, pos, text, subs, fin)
   assert(typ=="package_decl")
   local typ, pos, text = decode_match(subs[1])
   assert(typ=="packagename")
   common.note("In package " .. text)
   return text					    -- return package name
end

function c1.compile_local(ast, gmr, source, env)
   assert(not gmr, "the rpl grammar allowed a local decl inside a grammar???")
   local typ, _, _, subs = decode_match(ast)
   assert(typ=="local_")
   local name, pos, text = decode_match(subs[1])
   local pat = c0.compile_ast(subs[1], source, env)
   pat.exported = false;
   return pat
end

function c1.compile_ast(ast, env)
   assert(type(ast)=="table", "Compiler: first argument not an ast: "..tostring(ast))
   local functions = {"compile_ast";
		      local_ = c1.compile_local;
		      binding=c0.compile_binding;
		      new_grammar=c0.compile_grammar;
		      exp=c0.compile_exp;
		      default=c0.compile_exp;
		   }
   return common.walk_ast(ast, functions, false, env)
end

----------------------------------------------------------------------------------------
-- Coroutine body
----------------------------------------------------------------------------------------

-- the load procedure enforces the structure of an rpl module:
--     rpl_module = language_decl? package_decl? import_decl* statement* ignore
--
-- We could parse a module using that rpl_module pattern, but we can give better
-- error messages this way.
--
-- The load procedure compiles in a fresh environment (creating new bindings there) UNLESS
-- importpath is nil, which indicates "top level" loading into env.  Each dependency must already
-- be compiled and have an entry in modtable, else the compilation will fail.
--
-- importpath: a relative filesystem path to the source file, or nil
-- astlist: the already preparsed, parsed, and expanded input to be compiled
-- modtable: the global module table (one per engine) because modules can be shared
-- 
-- return value are success, packagename/nil, table of messages

function c1.load(importpath, astlist, modtable, env)
   assert(type(importpath)=="string" or importpath==nil)
   assert(type(astlist)=="table")
   assert(type(modtable)=="table")
   assert(environment.is(env))
   local thispkg
   local i = 1
   if not astlist[i] then return true, nil, {"Empty input"}; end
   local typ, pos, text, subs, fin = common.decode_match(astlist[i])
   assert(typ~="language_decl", "language declaration should be handled in preparse/parse")
   if typ=="package_decl" then
      thispkg = c1.process_package_decl(typ, pos, text, subs, fin)
      i=i+1;
      if not astlist[i] then
	 return true, thispkg, {"Empty module (nothing after package declaration)"}
      end
      typ, pos, text, subs, fin = common.decode_match(astlist[i])
   end
   -- If there is a package_decl, then this code is a module.  It gets its own fresh
   -- environment, and it is registered (by its importpath) in the per-engine modtable.
   -- Otherwise, if there is no package decl, then the code is compiled in the default, or
   -- "top level" environment.  
   if thispkg then
      assert(not common.modtableref(modtable, importpath), "module " .. importpath .. " already compiled and loaded?")
   end
   -- Dependencies must have been compiled and imported before we get here, so we can skip over
   -- the import declarations.
   while typ=="import_decl" do
      i=i+1
      if not astlist[i] then return true, thispkg, {"Module consists only of import declarations"}; end
      typ, pos, text, subs, fin = common.decode_match(astlist[i])
   end -- while skipping import_decls
   local results, messages = {}, {}
   repeat
      results[i], message = c1.compile_ast(astlist[i], env)
      if message then table.insert(messages, message); end
      i=i+1
   until not astlist[i]
   -- success! save this env in the modtable, if we have an importpath.
   if importpath and thispkg then common.modtableset(modtable, importpath, thispkg, env); end
   return true, thispkg, messages
end


return c1
