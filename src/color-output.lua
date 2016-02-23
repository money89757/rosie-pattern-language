---- -*- Mode: Lua; -*- 
----
---- color-output.lua    Takes json from Rosie, reconstructs the input text while
----                     highlighting recognized items in color.
----
---- (c) 2015, Jamie A. Jennings
----

local common = require "common"

local function csi(rest)
   return "\027[" .. rest
end

-- Colors

local shell_color_table = 
   { -- fg colors
     ["black"] = csi("30m");
     ["red"] = csi("31m");
     ["green"] = csi("32m");
     ["yellow"] = csi("33m");
     ["blue"] = csi("34m");
     ["magenta"] = csi("35m");
     ["cyan"] = csi("36m");
     ["white"] = csi("37m");
     ["default"] = csi("39m");
     ["underline"] = csi("4m");
     -- font attributes
     ["reverse"] = csi("7m");
     ["bold"] = csi("1m");
     ["blink"] = csi("5m");
     ["underline"] = csi("4m");
     ["none"] = csi("0m");
     -- bg colors
     ["bg_black"] = csi("40m");
     ["bg_red"] = csi("41m");
     ["bg_green"] = csi("42m");
     ["bg_yellow"] = csi("43m");
     ["bg_blue"] = csi("44m");
     ["bg_magenta"] = csi("45m");
     ["bg_cyan"] = csi("46m");
     ["bg_white"] = csi("47m");
     ["bg_default"] = csi("49m");
  }


colormap = {["."] = "black";
	    ["basic.unmatched"] = "black";
	    ["simplified_json"] = "yellow";	    -- won't work. need aliases within grammars.
	    ["common.word"] = "yellow";
	    ["common.int"] = "underline";
	    ["common.float"] = "underline";
	    ["common.hex"] = "underline";
	    ["common.denoted_hex"] = "underline";
	    ["common.number"] = "underline";
	    ["common.maybe_identifier"] = "cyan";
	    ["common.identifier_not_word"] = "cyan";
	    ["common.identifier_plus"] = "cyan";
	    ["common.identifier_plus_plus"] = "cyan";
	    ["common.path"] = "green";
	    ["basic.datetime_patterns"] = "blue";
	    ["basic.network_patterns"] = "red";
       
            ["datetime.datetime_RFC3339"] = "blue";
            ["datetime.slash_datetime"] = "blue";
            ["datetime.simple_slash_date"] = "blue";
            ["datetime.shortdate"] = "blue";
            ["datetime.ordinary_date"] = "blue";
            ["datetime.simple_date"] = "blue";
            ["datetime.simple_datetime"] = "blue";
            ["datetime.full_date_RFC3339"] = "blue";
            ["datetime.date_RFC2822"] = "blue";
            ["datetime.time_RFC2822"] = "blue";
            ["datetime.full_time_RFC3339"] = "blue";
            ["datetime.simple_time"] = "blue";
            ["datetime.funny_time"] = "blue";
       
            ["network.http_command"] = "red";
            ["network.url"] = "red";
            ["network.http_version"] = "red";
            ["network.ip_address"] = "red";
            ["network.fqdn"] = "red";
            ["network.email_address"] = "red";

	 }


local already_warned = {}

function color(key)
   local c = colormap[key]
   if not c then
      if not QUIET and not already_warned[key] then
	 io.stderr:write("Warning: No color defined in color map for object of type: '",
			 tostring(key),
			 "'\n");
	 already_warned[key] = true;
      end
      c = "black";
   end
   return c, shell_color_table[c]
end

local reset_color_attributes = shell_color_table["none"]

-- key is, e.g. "basic.matchall"
--function color_print(key, list)
--   local cname, ccode = color(key)
--   local text
--   for i, obj in ipairs(list) do
--      text = tostring(obj);
--      io.write(ccode, text, reset_color_attributes, " ");
--   end
--   io.write("\n");
--end

function color_print_leaf_nodes(t)
   -- t is a match
   local name, pos, text, subs, subidx = common.decode_match(t)
   if not subs then
      -- already at a leaf node
      local cname, ccode = color(name)
      text = tostring(text);			    -- just in case!
      io.write(ccode, text, reset_color_attributes, " ");
   else
      for i = subidx, #subs do
	 color_print_leaf_nodes(subs[i]);
      end -- for all sub-matches
   end
end