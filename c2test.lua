rosie = require "rosie"
e = rosie.engine.new()

list = rosie._env.list
util = rosie._env.util
common = rosie._env.common
environment = rosie._env.environment
ast = rosie._env.ast
loadpkg = rosie._env.loadpkg
--expand = rosie._env.expand
c2 = rosie._env.c2

-- global tables of intermediate results for examination during testing:
parses = {}
asts = {}

e:load("import rosie/rpl_1_1 as .")

c = {parse_block = c2.make_parse_block(e),
     expand_block = c2.expand_block,
     compile_block = c2.compile_block}

messages = {}
pkgtable = environment.make_module_table()
env = environment.new()

function printf(fmt, ...)
   print(string.format(fmt, ...))
end

function dump_state()
   print("\nPkgtable:")
   print("---------")
   for k,v in pairs(pkgtable) do printf("%-10s %s", k, tostring(v)); end
   print("\nTop level env:")
   print("--------------")
   for k,v in env:bindings() do printf("%-15s %s", k, tostring(v)); end
   print()
end

function goimport(importpath)
   print("Loading " .. importpath)
   fullpath, src, errmsg = common.get_file(importpath, e.searchpath)
   if (not src) then error("go: failed to find import " .. importpath); end
   loadpkg.source(c, pkgtable, env, e.searchpath, src, importpath, fullpath, messages)
   dump_state()
end

function go(src)
   print("Loading source: " .. src:sub(1,60))
   loadpkg.source(c, pkgtable, env, e.searchpath, src, nil, nil, messages)
   dump_state()
end   


goimport("num")
goimport("net")

go("import common")
go("import common as foo")
go("import net, common as .")


print("\n----- Start of cooked/raw tests -----\n")


function test_seq(name, expectation)
   local foo = environment.lookup(env, name)
   assert(ast.sequence.is(foo.ast) or ast.choice.is(foo.ast))
   seq = list.map(function(ex)
		     if ast.ref.is(ex) then return ex.localname
		     elseif ast.predicate.is(ex) then return "predicate"
		     else return tostring(ex)
		     end
		  end,
		  foo.ast.exps)
   print(name, seq)
   if list.equal(seq, list.from(expectation)) then
      print("Correct")
   else
      error("WRONG RESULT!")
   end
end

go('foo = a b c')
test_seq("foo", {"a", "~", "b", "~", "c"})

go('foo = {a b c}')
test_seq("foo", {"a", "b", "c"})

go('foo = ({a b c})')
test_seq("foo", {"a", "b", "c"})

go('foo = {({a b c})}')
test_seq("foo", {"a", "b", "c"})

go('foo = {(a b c)}')
test_seq("foo", {"a", "~", "b", "~", "c"})

go('foo = (!a b c)')
test_seq("foo", {"predicate", "b", "~", "c"})

go('foo = (!a b @c)')
test_seq("foo", {"predicate", "b", "~", "predicate"})

go('foo = (!a @b c)')
test_seq("foo", {"predicate", "predicate", "c"})

go('foo = (!a @b !c)')
test_seq("foo", {"predicate", "predicate", "predicate"})

go('foo = !a @b !c')
test_seq("foo", {"predicate", "predicate", "predicate"})

go('foo = {!a @b !c}')
test_seq("foo", {"predicate", "predicate", "predicate"})

go('foo = a / b / c')
test_seq("foo", {"a", "b", "c"})

go('foo = {a / b / c}')
test_seq("foo", {"a", "b", "c"})

go('foo = (a / b / c)')
test_seq("foo", {"a", "b", "c"})

goimport("json"); print(ast.tostring(c2.asts.json), "\n")
goimport("date"); print(ast.tostring(c2.asts.date), "\n")
goimport("time"); print(ast.tostring(c2.asts.time), "\n")
goimport("os"); print(ast.tostring(c2.asts.os), "\n")