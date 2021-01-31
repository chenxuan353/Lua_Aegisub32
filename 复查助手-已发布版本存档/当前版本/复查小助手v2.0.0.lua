-- 辅助支持表
local cx_help = require"CX_AEG插件辅助函数库"
-- 创建合适的函数环境
cx_help.table.merge(_G,cx_help)

-- 脚本名
script_name = "复查小助手"
-- 脚本描述
script_description = "用于检查当前轴文件可能存在的问题"
-- 作者
script_author = "晨轩°"

-- CX插件扩展值
-- 脚本签名(同一脚本签名请保持不变，签名不能含特殊字符，防止配置冲突)
script_signature = "com.chenxuan.查轴助手"
-- 版本号
script_version = "2.0.0"
-- 关于
script_about = [[

Hello ASSman!
选项菜单内存在部分说明
或至本项目github地址上包含的说明文档中查看
字体检测功能依赖“Yutils”，本体依赖“CXkara_函数辅助库”
链接：https://github.com/chenxuan353/Lua_Aegisub32

支持多功能可配置的轴文件检查
1.智能60FPS修复(视频已打开)
2.识别可能导致压制乱码的字符(包含检查当前已打开文件名)
3.识别单行字幕过长(视频已打开)
4.识别不存在的样式
5.同样式非注释行重叠以及包含
6.识别未安装的字体(需要Yutils支持)
7.闪轴检测及修复(行间隔<300ms-默认,单行<300ms-默认)
8.检查格式，及格式化(自定义检查规则)
注：60FPS修复经过测试多次使用对ASS无负面影响
注：注释、说话人或特效不为空的行配置后可被忽略
注：本助手的提示等级为level 3 如果不能正常显示信息或者其他异常请检查您的设置
注：闪轴的自动修复是有极限的，请以提高自身水平为基础。
注：本插件所做修改可由AEG的撤销功能撤回
作者：晨轩°(QQ3309003591)
本关于的最后修改时间：2021年1月25日
感谢您的使用！
]]

-- 更新日志
script_ChangeLog = [[
v2.0.0正式版
与之前的版本相比，大幅增强了配置功能。
并增加了格式化检测与格式化功能
可以通过配置不同的格式化文件
实现不同样式不同格式的格式化操作
降低复查或校对时的工作量
提供的统计功能也能很好的了解
当前文件的状态
]]

local Yutils = require('Yutils')
local re = require('re')
local lfs = require("lfs")
local unicode = require("unicode")

-- 快捷菜单设置
-- 设置的值会随着用户的操作而变化(绑定表会同步这个变化，文件也会，使用set方法设置值也会同步到文件里)
-- 自动检查设置
autocheck_options = {
	["60FPS修复"] = true -- 多选菜单的默认值，加载后会优先读取文件中的缓存
	,["乱码字符"] = true
	,["乱码字符(文件名)"] = true
	,["超长行"] = true
	,["闪轴(间隔)"] = true
	,["修复闪轴(间隔)"] = false -- 不推荐长期开启，此功能会改变内容
	,["闪轴(短轴)"] = true
	,["闪轴(联动)"] = true
	,["样式不存在"] = true
	,["重叠行(支持联动)"] = true
	,["字体未安装"] = true
	,["格式化检测"] = true	-- 字面意思
	,["自动格式化"] = false -- 不推荐长期开启，此功能会改变内容
	,["DEBUG"] = false
}
-- 复查模式
recheck_option={
	["开关"] = false
}
-- 乱码字符检测
errchar_options={
	["严格模式"] = true
}

--[[
	检查序列
]]
-- 整体初始化
local cache_ac_config = {}
function AC_init()
	cache_ac_config = {}
	local function tool_defaultValue(val,defval)
		return van == nil and defval or val
	end
	-- 字符白名单
	local default_whilelist = [[﹝﹞•¿·︸︷︶︵︿﹀︺︹︽︾﹂﹁﹃﹄︼︻〖〗】【`ˋ¦①②③④⑤⑥⑦⑧⑨⑩㈠㈡㈢㈣㈤㈥㈦㈧㈨㈩ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ± ≠ ≈ ≡ ＜ ＞ ≤ ≥ ∧ ∨ ≮ ≯ ∑ ∏ ∈ ∩ ∪ ⌒ ∽ ≌ ⊙ √ ⊥ ∥∠ ∫ ∮ ∝ ∞ · ∶ ∵ ∴ ∷ ‰ ℅ ￥ ＄ ° ℃ ℉ ′ ″ ￠ 〒 ¤ ○ ￡ ㏒ ㏑ ㏕ ㎎ ㎏ ㎜ ㎝ ㎞ ㏄ ㎡ ◇ ◆ ■ □ ☆ ○ △ ▽ ★ ● ▲ ▼ ♠ ♣ ♥ ♀ ♂ √ ✔ ✘ × ♪ ㈱ ↔ ↕ 卐 卍 ↖ ↑ ↗ → ↘ ↓ ↙ ← ㊣]]
	cache_ac_config["ac_errchar_whilelist"] = tool_defaultValue(tools.getConfig("ac_errchar_whilelist"),default_whilelist)
	-- 字符黑名单
	local default_blacklist = [[㊚₂㊤₃㊛㊧㊥₄㊨㊙㊦▦▧㎥▤▥⁴▨▩・♬☞◑₁◐☜▷◁♢♤♧♡▶◀㏘]]
	cache_ac_config['ac_errchar_blacklist'] = tool_defaultValue(tools.getConfig("ac_errchar_blacklist"),default_blacklist)
	-- 闪轴间隔
	cache_ac_config['ac_flash_interval'] = tool_defaultValue(tools.getConfig("ac_flash_interval"),300)
	-- 短轴间隔
	cache_ac_config['ac_flash_short'] = tool_defaultValue(tools.getConfig("ac_flash_short"),300)
	-- 联动间隔
	cache_ac_config['ac_flash_linkage'] = tool_defaultValue(tools.getConfig("ac_flash_linkage"),50)
end
function tool_getConfig(key)
	if cache_ac_config[key] == nil then
		cache_ac_config[key] = tools.getConfig(key)
	end
	return cache_ac_config[key]
end
-- DEBUG
function AC_debug_init(psubs)
	local log = tools.func_partial(println,"DEBUG 初始化 : ")
	log("初始化")
	log("debug仍然是个很废物的模式...")
end
function AC_debug(line,meta,orderly_dialogues,psubs)
	local log = tools.func_partial(println,"DEBUG 行 ",line.i," : ")
	log(line.text)
	return random(1,100) > 50
end
-- 乱码字符检测
local tool_RE_FIX = {"\\*","\\.","\\?","\\+","\\$","\\^","\\[","\\]","\\(","\\)","\\{","\\}","\\|","\\\\","\\/"}
function tool_getReEncode(text)
	local res = text
	for _,v in ipairs(tool_RE_FIX) do
		res = string.gsub(res,v,"\\"..v)
	end
	return res
end
function tool_getReDecode(text)
	local res = text
	for _,v in ipairs(tool_RE_FIX) do
		res = string.gsub(res,"\\"..v,v)
	end
	return res
end
function tool_getErrcharRule()
	local resStr = ''
	if errchar_options.get("严格模式") then
		-- 严格模式基础白名单规则(不应乱码的字符.jpg)
		local baseRule = [[\x{2E80}-\x{9FFF}\sA-Za-z0-9`~!@#$%^&*()_\-\^…+=<>?:"{}|,.\/;'\\[\]·~！～＠﹪＃￥％＾＄＆*＊（）－＿＼\—＋＝⋯｛｝｜•《》？：“”【】、；‘’＇，。、]]
		resStr = "[^"..resStr..baseRule..tool_getConfig("ac_errchar_whilelist")
	else
		resStr = "["..resStr..tool_getConfig("ac_errchar_blacklist")
	end
	return resStr.."]+"
end
function tool_errchar_check(text)
	-- 包含错误字符时返回false
	local mathrule = tool_getErrcharRule()
	local mathres = nil
	xpcall(
		function()
			mathres = re.match(text, mathrule,re.NOSUB)
		end, 
		function()
			println("[警告]：乱码字符检测设置异常，请检查设置")
			mathres = nil
		end
	)
	if mathres then
		-- 发现了存在可能引起压制错误的行
		return false, '可疑字符 '..mathres[1].str
	end
	return true
end

function AC_errchar(line)
	local log = tools.func_partial(println,"乱码检测 行 ",line.i," : ")
	local res, errstr = tool_errchar_check(line.text)
	if not res then
		log(errstr)
		return false
	end
	return true
end

function AC_overline(line,meta)
	local log = tools.func_partial(println,"越界检测 行 ",line.i," : ")
	local msg = ""
	if line.styleref == nil then
		-- 样式不存在时无法计算
		return true
	end
	if meta.res_x == 0 or meta.res_y == 0 then
		-- 视频无分辨率时无法检测
		return true
	end
	if line.left < 0 or line.left > meta.res_x then
		msg = msg..(msg == "" and "" or " ")..'左越界'
	end
	if line.right > meta.res_x then
		msg = msg..(msg == "" and "" or " ")..'右越界'
	end
	if line.top < 0 or line.top > meta.res_y then
		msg = msg..(msg == "" and "" or " ")..'上越界'
	end
	if line.bottom > meta.res_y then
		msg = msg..(msg == "" and "" or " ")..'下越界'
	end
	if msg ~= "" then
		log(msg)
		return false
	end
	return true
end

function AC_emptystyle(line)
	local log = tools.func_partial(println,"空样式 行 ",line.i," : ")
	if line.styleref == nil then
		log("样式 ",line.style," 不存在")
		return false
	end
	return true
end

function AC_overlap(line,meta)
	local log = tools.func_partial(println,"重叠检查 行 ",line.i," : ")
	if meta.lastline ~= nil then
		local lastline = meta.lastline
		-- 同一样式 本行的开始时间小于上一行的结束时间(同一个人能多线程说话？)
		if line.start_time < lastline.end_time then
			log("该行与行 ",lastline.i," 重叠")
			return false
		end
		-- 一行的开始时间大于结束时间的畸形种(不知道会不会出现)
		if line.start_time > line.end_time then
			log("这合理吗？开始时间居然大于了结束时间。")
			return false
		end
	end
	return true
end

function AC_flash_interval(line,meta,orderly_dialogues,psubs)
	local log = tools.func_partial(println,"闪轴(间隔)检测 行 ",line.i," : ")
	if meta.lastline ~= nil then
		local aotofix = autocheck_options.get("修复闪轴(间隔)")
		local interval_conf = tonumber(tool_getConfig("ac_flash_interval"))
		local lastline = meta.lastline
		local interval = line.start_time - lastline.end_time
		if interval < interval_conf and interval > 0 then
			log("此行与行 ",lastline.i," 之间的间距小于 ",interval_conf," ms")
			if aotofix then
				lastline.end_time = line.start_time
				psubs[lastline.i] = lastline
			end
			return false
		end
	end
	return true
end

function AC_flash_short(line)
	local log = tools.func_partial(println,"闪轴(短轴)检测 行 ",line.i," : ")
	local short_conf = tonumber(tool_getConfig("ac_flash_short"))
	local interval = line.end_time - line.start_time
	if interval < short_conf then
		log("短，真的短，仅 ",interval,"ms")
		return false
	end
	return true
end

local var_ac_flash_linkage_pos = {}
function AC_flash_linkage_init(psubs)
	var_ac_flash_linkage_pos = {}
end
function AC_flash_linkage(line,meta,orderly_dialogues)
	local log = tools.func_partial(println,"闪轴(联动)检测 行 ",line.i," : ")
	local linkage_conf = tonumber(tool_getConfig('ac_flash_linkage'))
	local cmp_i = line.i
	local start_msg = ''
	local end_msg = ''
	for _,cmpline in ipairs(var_ac_flash_linkage_pos) do
		local start_interval = line.start_time - cmpline.start_time
		local end_interval = math.abs(line.end_time - cmpline.end_time)
		if start_interval > 0 and start_interval < linkage_conf then
			start_msg = start_msg..(start_msg == '' and '' or ',')..tostring(cmpline.i).."("..start_interval..")"
		end
		if end_interval > 0 and end_interval < linkage_conf then
			end_msg = end_msg..(end_msg == '' and '' or ',')..tostring(cmpline.i)
		end
	end
	table.insert(var_ac_flash_linkage_pos,{
		i = line.i,
		start_time = line.start_time,
		end_time = line.end_time
	})

	if start_msg ~= '' then
		log("该行与 ",start_msg," 行的起始时间过于接近，考虑合并这个时间差")
	end
	if end_msg ~= '' then
		log("该行与 ",end_msg," 行的结束时间过于接近(<",linkage_conf,"ms)，考虑合并这个时间差")
	end
	if start_msg ~= '' or end_msg ~= '' then
		return false
	end
	return true
end

-- 格式化配置
local FORMAT_PATH = aeg.path.config..script_signature.."\\format\\"
local FORMAT_SUFFIX = ".assformat"
function format_getFilePath(name)
	return FORMAT_PATH..name..FORMAT_SUFFIX
end
function format_read(name)
	local filepath = format_getFilePath(name)
	local file = io.open (filepath, "r")
	if not io.type(file) then
		println("[读取]格式化文件 "..filepath.." 无法打开！")
		return
	end
	local formatrule = {
		name = name, -- 名称
		scoperule = "*", -- 作用范围集
		rules = {} -- 匹配与替换规则集
	}
	local line_count = 0
	local line = file:read()
	line_count = line_count + 1
	if line ~= "---assformat---" then 
		file:close()
		println("[读取]格式化文件 "..name.." 内容不合法！ 行 "..tostring(line_count).." 异常")
		return
	end
	line = file:read()
	line_count = line_count + 1
	if line == nil or string.trim(line) == "" then 
		file:close()
		println("[读取]格式化文件 "..name.." 内容不合法！ 行 "..tostring(line_count).." 异常")
		return
	end
	formatrule.scoperule = line
	line = file:read()
	while line do
		local unit = {}
		line_count = line_count + 1
		if line == nil or string.trim(line) == '' then
			file:close()
			println("[读取]格式化文件 "..name.." 内容不合法！ 行 "..tostring(line_count).." 异常")
			return
		end
		unit[1] = line
		line = file:read()
		line_count = line_count + 1
		if line == nil or string.trim(line) == '' then
			file:close()
			println("[读取]格式化文件 "..name.." 内容不合法！ 行 "..tostring(line_count).." 异常")
			return
		end
		unit[2] = line
		table.insert(formatrule.rules,unit)
		line = file:read()
	end
	-- 关闭打开的文件
	file:close()
	return formatrule
end
function format_write(name,formatrule)
	--[[
		local formatrule = {
			name = name, -- 名称
			scoperule = "*", -- 作用范围集
			rules = {} -- 匹配与替换规则集
		}
	]]
	lfs.mkdir(aeg.path.config..script_signature.."\\format\\")
	if type(formatrule) ~= "table" then
		error("[写入]写入格式化文件时错误！写入类型异常！错误文件->"..filepath)
	end
	local filepath = format_getFilePath(name)
	local file = io.open (filepath, "w+")
	if not io.type(file) then
		file:close()
		println("[写入]格式化文件 "..name.." 无法打开！")
		return false
	end
	local errflag = false
	xpcall(
		function()
			file:write("---assformat---\n")
			file:write(formatrule.scoperule)
			for _,ruleunit in ipairs(formatrule.rules) do
				file:write("\n"..ruleunit[1].."\n")
				file:write(ruleunit[2])
			end
		end, 
		function()
			println(debug.debug())
			println("未预料到的写入错误，请联系插件作者！")
			errflag = true
		end
	)
	-- 关闭打开的文件
	file:close()
	if errflag then
		return false
	end
	return true
end
function format_getlist()
	-- 收集格式化文件列表
	local flist = {}
	for path in lfs.dir(FORMAT_PATH) do
		if string.sub(path,-string.len(FORMAT_SUFFIX)) == FORMAT_SUFFIX then
			local unit = string.sub(path,0,-string.len(FORMAT_SUFFIX)-1)
			table.insert(flist,unit)
		end
	end
	return flist
end
function format_getCollection()
	local collection = {}
	local formatnames = {}
	for _,name in ipairs(format_getlist()) do
		local formatrule = format_read(name)
		if formatrule ~= nil then
			collection[name] = formatrule
			table.insert(formatnames,name)
		else
			println("规则 "..name.." 无法加载")
		end
	end
	return collection, formatnames
end
function format_getRuleStr(rule)
	local function catstr(str,length)
		if string.len(str) <= length then
			return str
		end
		local count = 0
		local resstr = ""
		for c in unicode.chars(str) do
			if count > length then
				break
			end
			resstr = resstr..c
			count = count + 1
		end
		return resstr.."..."
	end
	return catstr(rule[1],15).." => "..catstr(rule[2],25)
end
local var_ac_formatCollection = {}
local var_ac_formatNames = {}
function AC_format_init(psubs)
	var_ac_formatCollection,var_ac_formatNames = format_getCollection()
end
function AC_format(line,meta,orderly_dialogues,psubs)
	local log = tools.func_partial(println,"格式化检测 行 ",line.i," : ")
	local resflag = true
	-- 迭代规则列表
	for _,name in ipairs(var_ac_formatNames) do
		local formatrule = var_ac_formatCollection[name]
		if not pcall(
			function () 
				if re.match(line.style,formatrule.scoperule,re.NOSUB) ~= nil then
					-- 迭代子规则列表
					for _,rule in ipairs(formatrule.rules) do
						if re.match(line.text,rule[1],re.NOSUB) ~= nil then
							log("与 ",formatrule.name," 规则的 ",format_getRuleStr(rule)," 规则匹配")
							resflag = false
							if autocheck_options.get("自动格式化") then
								out_str, rep_count = re.sub(line.text,rule[1],rule[2])
								line.text = out_str
								psubs[line.i] = line
							end
						end
					end
				end
			end
		) then
			log("规则 ",formatrule.name," 执行时错误，请检查规则文件！")
		end
	end
	-- 应用更改
	if resflag == false and autocheck_options.get("自动格式化") then
		psubs[line.i] = line
	end
	return resflag
end
--[[
1.智能60FPS修复(视频已打开) --功能完成
2.识别可能导致压制乱码的字符(包含检查当前已打开文件名) --功能完成
3.识别单行字幕过长(视频已打开) --功能完成
4.识别不存在的样式 --功能完成
5.同样式非注释行重叠以及包含
6.识别未安装的字体(需要Yutils支持) --功能完成
7.闪轴检测及修复(行间隔<300ms-默认,单行<300ms-默认)
8.检查格式，及格式化(自定义检查规则)
9.加载指定格式化文件，及指定样式格式化文件(关键词)。
]]
--[[
	["60FPS修复"] = true -- 多选菜单的默认值，加载后会优先读取文件中的缓存
	,["乱码字符"] = true --
	,["乱码字符(文件名)"] = true --
	,["超长行"] = true --
	,["闪轴(间隔)"] = true --
	,["闪轴(短轴)"] = true --
	,["闪轴(联动)"] = true --
	,["样式不存在"] = true --
	,["重叠行(支持联动)"] = true --
	,["字体未安装"] = true --
	,["格式化检测"] = true --
	,["自动格式化"] = false 
	,["DEBUG"] = false --
]]

-- 检查表
local auto_check = {
	-- 一个检查单元
	{
		-- 是否可用
		enable = true
		-- 标题
		,title = "测试行"
		-- 绑定 autocheck_options 中的键
		,bindkey = "DEBUG"
		-- 初始化函数
		,init_func = AC_debug_init
		-- 处理函数
		,deal_func = AC_debug
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "乱码行"
		-- 绑定 autocheck_options 中的键
		,bindkey = "乱码字符"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_errchar
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "超长行"
		-- 绑定 autocheck_options 中的键
		,bindkey = "超长行"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_overline
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "空样式行"
		-- 绑定 autocheck_options 中的键
		,bindkey = "样式不存在"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_emptystyle
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "重叠行"
		-- 绑定 autocheck_options 中的键
		,bindkey = "重叠行(支持联动)"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_overlap
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "闪轴(间隔)"
		-- 绑定 autocheck_options 中的键
		,bindkey = "闪轴(间隔)"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_flash_interval
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "闪轴(短轴)"
		-- 绑定 autocheck_options 中的键
		,bindkey = "闪轴(短轴)"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_flash_short
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "闪轴(联动)"
		-- 绑定 autocheck_options 中的键
		,bindkey = "闪轴(联动)"
		-- 初始化函数
		,init_func = AC_flash_linkage_init
		-- 处理函数
		,deal_func = AC_flash_linkage
		-- 用于保存异常行的行号
		,errline = {}
	}
	,{
		-- 是否可用
		enable = true
		-- 标题
		,title = "格式化警告"
		-- 绑定 autocheck_options 中的键
		,bindkey = "格式化检测"
		-- 初始化函数
		,init_func = AC_format_init
		-- 处理函数
		,deal_func = AC_format
		-- 用于保存异常行的行号
		,errline = {}
	}
}

--[[
	前置操作函数
]]
-- 60FPS修复
function oprate_fix_60fps(subs)
	-- 代码来自 Kiriko 的 60FPS修复
	for i = 1, #subs do
        if subs[i].class == "dialogue" then
			local line=subs[i]
	        if line.start_time%50 == 0 and line.start_time ~= 0 then
		        line.start_time=line.start_time+10
	        end
	        if line.end_time%50 == 0 then
		        line.end_time=line.end_time+10
	        end
	        subs[i]=line			
        end
    end
end
-- 文件路径检查
function oprate_pathcheck(path)
	local log = tools.func_partial(println,"文件名检查：")
	--[[
		aeg.path.script
		aeg.path.video
		aeg.path.audio
	]]
	local errstr = ""
	if aeg.path.script then
		local res, errstr = tool_errchar_check(aeg.path.script)
		if not res then
			errstr = errstr..(errstr == "" and "" or ",").."字幕路径"
			log("字幕文件路径发现异常,",errstr)
		end
	end
	if aeg.path.video then
		local res, errstr = tool_errchar_check(aeg.path.video)
		if not res then
			errstr = errstr..(errstr == "" and "" or ",").."视频路径"
			log("视频文件路径发现异常,",errstr)
		end
	end
	if aeg.path.audio then
		local res, errstr = tool_errchar_check(aeg.path.audio)
		if not res then
			errstr = errstr..(errstr == "" and "" or ",").."音频路径"
			log("音频文件路径发现异常,",errstr)
		end
	end
	return errstr == "" and "无" or err_str
end
-- 字体未安装检查
function oprate_fontcheck(psubs)
	local log = tools.func_partial(println,"字体检查：")
	if not Yutils then
		log("Yutils 未安装，字体检查无法执行...")
		return
	end
	
	log("通过 Yutils 获取系统字体列表...")
	local fonts = Yutils.decode.list_fonts(false)
	
	-- 建立样式的字体映射表
	local styles_front = {}
	local err_str = ""
	local err_count = 0
	log("标记及检查")
	
	for i,style in psubs.StylesIter do
		styles_front[style.fontname] = {}
		styles_front[style.fontname].name = style.name
	end
	
	-- 对字体进行标记
	for i = 1,#fonts do
		if styles_front[fonts[i].name] then
			styles_front[fonts[i].name].check = true
		end
	end
	-- 输出错误信息(如果存在)
	for frontname,style_info in pairs(styles_front) do
		if not style_info.check then
			-- 这个鬼样式的对应字体不存在
			log('样式 ',style_info.name,' 的字体 ',frontname,' 未安装')
			err_count = err_count + 1
			err_str = err_str..(err_str == '' and '' or ',')..frontname.."("..style_info.name..")"
		end
	end
	err_str = err_str == '' and '无' or err_str
	return err_count, err_str
end

--[[
	检查核心
]]
cancel_func = function() println("\n\n>>>已取消执行<<<\n\n") end
NO_CHECK_TYPE = "-NOC"
autocheck_settings = {
	["忽略所有评论行"] = true
	,["忽略含说话人的行"] = true
	,["忽略特效行"] = true
	,["忽略不检查行"] = true
}
-- 计算并返回脚本分辨率信息
function meta_resolution(playresx, playresy)
	-- 修改自 karaskel 的函数
	local meta = {
		-- X和Y脚本分辨率
		res_x = 0, res_y = 0,
		-- 视频/脚本分辨率不匹配的宽高比校正比值
		video_x_correct_factor = 1.0
	}

	-- 修正解析度数据(分辨率数据？)
	if playresx then
		meta.res_x = math.floor(playresx)
	end
	if playresy then
		meta.res_y = math.floor(playresy)
	end
	if meta.res_x == 0 and meta_res_y == 0 then
		meta.res_x = 384
		meta.res_y = 288
	elseif meta.res_x == 0 then
		-- This is braindead, but it's how TextSub does things...
		-- 这真是令人头疼，但是这是TextSub做事的方式...
		if meta.res_y == 1024 then
			meta.res_x = 1280
		else
			meta.res_x = meta.res_y / 3 * 4
		end
	elseif meta.res_y == 0 then
		-- As if 1280x960 didn't exist
		-- 好像不存在1280x960
		if meta.res_x == 1280 then
			meta.res_y = 1024
		else
			meta.res_y = meta.res_x * 3 / 4
		end
	end
	
	local video_x, video_y = aegisub.video_size()
	if video_y then
		-- 分辨率校正因子
		meta.video_x_correct_factor =
			(video_y / video_x) / (meta.res_y / meta.res_x)
	end
	return meta
end

-- 计算行尺寸信息(来自 karaskel 的函数)
function karaskel_preproc_line_pos(meta,line)
	-- 有效边距
	line.margin_v = line.margin_t
	line.eff_margin_l = ((line.margin_l > 0) and line.margin_l) or line.styleref.margin_l
	line.eff_margin_r = ((line.margin_r > 0) and line.margin_r) or line.styleref.margin_r
	line.eff_margin_t = ((line.margin_t > 0) and line.margin_t) or line.styleref.margin_t
	line.eff_margin_b = ((line.margin_b > 0) and line.margin_b) or line.styleref.margin_b
	line.eff_margin_v = ((line.margin_v > 0) and line.margin_v) or line.styleref.margin_v
	-- 以及定位
	if line.styleref.align == 1 or line.styleref.align == 4 or line.styleref.align == 7 then
		-- Left aligned::左对齐
		line.left = line.eff_margin_l
		line.center = line.left + line.width / 2
		line.right = line.left + line.width
		line.x = line.left
		line.halign = "left"
	elseif line.styleref.align == 2 or line.styleref.align == 5 or line.styleref.align == 8 then
		-- Centered::中心对齐
		line.left = (meta.res_x - line.eff_margin_l - line.eff_margin_r - line.width) / 2 + line.eff_margin_l
		line.center = line.left + line.width / 2
		line.right = line.left + line.width
		line.x = line.center
		line.halign = "center"
	elseif line.styleref.align == 3 or line.styleref.align == 6 or line.styleref.align == 9 then
		-- Right aligned::右对齐
		line.left = meta.res_x - line.eff_margin_r - line.width
		line.center = line.left + line.width / 2
		line.right = line.left + line.width
		line.x = line.right
		line.halign = "right"
	end
	line.hcenter = line.center
	if line.styleref.align >=1 and line.styleref.align <= 3 then
		-- Bottom aligned::底部对齐
		line.bottom = meta.res_y - line.eff_margin_b
		line.middle = line.bottom - line.height / 2
		line.top = line.bottom - line.height
		line.y = line.bottom
		line.valign = "bottom"
	elseif line.styleref.align >= 4 and line.styleref.align <= 6 then
		-- Mid aligned::中间对齐
		line.top = (meta.res_y - line.eff_margin_t - line.eff_margin_b - line.height) / 2 + line.eff_margin_t
		line.middle = line.top + line.height / 2
		line.bottom = line.top + line.height
		line.y = line.middle
		line.valign = "middle"
	elseif line.styleref.align >= 7 and line.styleref.align <= 9 then
		-- Top aligned::顶部对齐
		line.top = line.eff_margin_t
		line.middle = line.top + line.height / 2
		line.bottom = line.top + line.height
		line.y = line.top
		line.valign = "top"
	end
	line.vcenter = line.middle
end

-- 计算行尺寸信息，参数(分辨率数据,行对应样式,行对象)
function line_math_pos(resmeta,style,line)
	local def_style = {
		 fontname = "SimSun"
		 ,italic = false
		 ,color2 = "&H000000FF&"
		 ,margin_t = 10
		 ,color4 = "&H00000000&"
		 ,fontsize = 60
		 ,color3 = "&H00000000&"
		 ,class = "style"
		 ,relative_to = 2
		 ,spacing = 0
		 ,strikeout = false
		 ,encoding = 1
		 ,margin_r = 10
		 ,angle = 0
		 ,bold = false
		 ,scale_y = 100
		 ,margin_b = 10
		 ,color1 = "&H00FFFFFF&"
		 ,margin_l = 10
		 ,align = 2
		 ,scale_x = 100
		 ,borderstyle = 1
		 ,outline = 2
		 ,underline = false
		 ,name = "_backup_Default"
		 ,shadow = 2
	}
	line.styleref = (style == nil and def_style or style)
	-- 计算行的尺寸信息
	line.width, line.height, line.descent, line.ext_lead = aegisub.text_extents(line.styleref, line.text)
	line.width = line.width * resmeta.video_x_correct_factor
	
	-- 计算行的布局信息
	karaskel_preproc_line_pos(resmeta,line)
	line.styleref = style
end

-- 函数核心
function line_count(line, collect_count)
	--[[
		local collect_count = {
			normal = 0 -- 普通行(包括空行，不包括评论)
			,no_empty = 0 -- 非空行
			,empty = 0 -- 空行
			,comment = 0 -- 评论行
			,actor = 0 -- 编辑了说话人的行
			,effect = 0 -- 特效行
			,max_dur = 0 -- 轴最大持续
			,min_dur = 0 -- 轴最短持续
			,start_time = nil -- 轴的起始时间
			,end_time = 0 -- 轴的结束时间
			,empty_length = 0 -- 轴间距总长(起始轴与结束轴之间空白部分总长)
			,total_length = 0 -- 总轴长度
		}
	]]
	-- 时间统计
	local line_interval = line.end_time - line.start_time
	if collect_count.start_time == nil then
		collect_count.start_time = line.start_time
		collect_count.end_time = line.end_time
		collect_count.max_dur = line_interval
		collect_count.min_dur = line_interval
	end
	if line_interval > collect_count.max_dur then
		collect_count.max_dur = line_interval
	end
	collect_count.total_length = collect_count.total_length + line_interval
	if line.end_time - collect_count.end_time > 0 then
		collect_count.empty_length = collect_count.empty_length + line.end_time - collect_count.end_time
	end
	if line.end_time >  collect_count.end_time then
		collect_count.end_time = line.end_time
	end
	
	-- 计数器统计
	local function countAdd(key)
		collect_count[key] = collect_count[key] + 1
	end
	
	if string.trim(line.text) == '' then
		countAdd("empty")
	else
		countAdd("no_empty")
	end

	if line.comment then
		countAdd("comment")
		if line.effect ~= '' then
			countAdd("effect")
		end
	else
		countAdd("normal")
	end
	
	if line.actor ~= '' then
		countAdd("actor")
	end
end
function predeal_filter(psubs,resmeta)
	-- 排序并过滤掉不需要的行
	-- 是否启用复查模式
	local recheck = recheck_option['开关']
	-- 有序对话行
	local orderly_dialogues = {}
	-- 行信息收集
	local collect_count = {
		normal = 0 -- 普通行(包括空行，不包括评论)
		,no_empty = 0 -- 非空行
		,empty = 0 -- 空行
		,comment = 0 -- 评论行
		,actor = 0 -- 编辑了说话人的行
		,effect = 0 -- 特效行
		,max_dur = 0 -- 轴最大持续
		,min_dur = 0 -- 轴最短持续
		,start_time = nil -- 轴的起始时间
		,end_time = 0 -- 轴的结束时间
		,empty_length = 0 -- 轴间距总长(起始轴与结束轴之间空白部分总长)
		,total_length = 0 -- 总轴长度
	}

	-- 收集行
	for i,line in psubs.DialogueIter do
		-- 行计数
		line_count(line, collect_count)
		-- 过滤行
		if recheck then
			if string.trim(line.text) == '' then
				goto nextCollectLoop
			end
		end
		if line.comment and autocheck_settings.get("忽略所有评论行") then
			goto nextCollectLoop
		end
		if line.effect ~= '' and autocheck_settings.get("忽略特效行") then
			goto nextCollectLoop
		end
		if string.find(line.actor, NO_CHECK_TYPE) ~= nil and autocheck_settings.get("忽略含说话人的行") then
			goto nextCollectLoop
		end
		if line.actor ~= '' and autocheck_settings.get("忽略不检查行") then
			goto nextCollectLoop
		end
		-- 预处理行与收集行
		line_style = psubs.styles[line.style] and psubs.styles[line.style].line or nil
		line_math_pos(resmeta,line_style,line)
		line.i = i
		table.insert(orderly_dialogues,line)
		::nextCollectLoop::
	end
	-- 排序
	-- 排序函数
	local function sort_comp(element1, elemnet2)
		if element1 == nil then
			return false;
		end
		if elemnet2 == nil then
			return true;
		end
		return element1.start_time < elemnet2.start_time
	end
	table.sort(orderly_dialogues,sort_comp)
	
	return orderly_dialogues, collect_count
end
function auto_check_clear(psubs)
	--[[
		-- 一个检查单元
		{
			-- 是否可用
			enable = true
			-- 标题
			,title = "DEBUG"
			-- 绑定 autocheck_options 中的键
			,bindkey = "DEBUG"
			-- 初始化函数
			,init_func = AC_debug_init
			-- 处理函数
			,deal_func = AC_debug
			-- 用于保存异常行的行号
			,errline = {}
		}
	]]
	for _,dealitem in ipairs(auto_check) do
		if dealitem.enable and autocheck_options.get(dealitem.bindkey) then
			dealitem.errline = {}
			if dealitem.init_func ~= nil then
				dealitem.init_func(psubs)
			end
		end
	end
end
function run_dealitem_unit(dealitem,line,resmeta,orderly_dialogues,psubs)
	--[[
		-- 一个检查单元
		{
			-- 是否可用
			enable = true
			-- 标题
			,title = "DEBUG"
			-- 绑定 autocheck_options 中的键
			,bindkey = "DEBUG"
			-- 处理函数
			,deal_func = function(line)
				DD(line.i,">>",line.text)
				end
			-- 用于保存异常行的行号
			,errline = {}
		}
	]]
	if not dealitem.enable then
		return true
	end
	if not autocheck_options.get(dealitem.bindkey) then
		return true
	end
	if dealitem.deal_func == nil then
		return true
	end
	if not dealitem.deal_func(line,resmeta,orderly_dialogues,psubs) then
		return false
	end
	aeg.waitAeg(cancel_func)
	return true
end
function real_run_auto_check(psubs, only_one)
	local log = tools.func_partial(println)
	aeg.setProgress(0)
	aeg.setTask("初始化数据")
	log("- 初始化数据 -")
	log("获取分辨率数据")
	-- 获取分辨率信息
	local playresx = psubs.infos.playresx and psubs.infos.playresx.value or 0
	local playresy = psubs.infos.playresy and psubs.infos.playresy.value or 0
	local resmeta = meta_resolution(playresx,playresy)
	aeg.setProgress(30)
	-- 获取有效且有序的行列表
	log("排序后的有效行列表")
	local orderly_dialogues, collect_count = predeal_filter(psubs, resmeta)
	aeg.setProgress(80)
	-- 清空前一次操作
	log("初始化缓存空间")
	AC_init()
	auto_check_clear(psubs)
	aeg.setProgress(100)
	log("")
	aeg.setTask("前置操作...")
	log("- 前置操作 -")
	--[[
		{
			["60FPS修复"] = true -- 多选菜单的默认值，加载后会优先读取文件中的缓存
			,["乱码字符"] = true --
			,["乱码字符(文件名)"] = true --
			,["超长行"] = true --
			,["闪轴(间隔)"] = true
			,["闪轴(短轴)"] = true
			,["闪轴(联动)"] = true
			,["样式不存在"] = true --
			,["重叠行(支持联动)"] = true
			,["字体未安装"] = true --
			,["DEBUG"] = false --
		}
	]]
	-- 预操作搜集
	local err_collect = {}
	
	if autocheck_options.get("60FPS修复") then
		log("60FPS修复...")
		oprate_fix_60fps(psubs.subs)
		log("60FPS修复完成")
	else
		log("60FPS修复未启用，已跳过")
	end

	if autocheck_options.get("乱码字符(文件名)") then
		log("乱码字符(文件名)检查...")
		local patherrstr = oprate_pathcheck(psubs.subs)
		err_collect['文件名异常'] = patherrstr
		log("乱码字符(文件名)检查完成")
	else
		log("乱码字符(文件名)检查未启用，已跳过")
	end
	
	if autocheck_options.get("字体未安装") then
		log("字体检查...")
		local font_err_count, font_err_str = oprate_fontcheck(psubs)
		err_collect['缺失字体'] = font_err_str
		err_collect['缺失字体数'] = font_err_count
		log("字体检查完成")
	else
		log("字体检查未启用，已跳过")
	end


	log("")
	aeg.setTask("检查中...")
	log("↓↓↓检查启动↓↓↓")
	-- 异常行列表
	local errline = {}
	-- 关系行存储
	local laststylecache = {}
	resmeta.laststylecache = laststylecache
	aeg.setProgress(0)
	for i,line in ipairs(orderly_dialogues) do
		err_flag = false
		aeg.waitAeg(cancel_func)
		aeg.setProgress(math.floor(i/#orderly_dialogues * 100 + 0.5))
		resmeta.lastline = laststylecache[line.style]
		laststylecache[line.style] = line
		if only_one ~= nil then
			if not only_one.deal_func(line,resmeta,orderly_dialogues,psubs) then
				err_flag = true
				table.insert(only_one.errline,line.i)
			end
		else
			for _,dealitem in ipairs(auto_check) do
				if not run_dealitem_unit(dealitem,line,resmeta,orderly_dialogues,psubs) then
					err_flag = true
					table.insert(dealitem.errline,line.i)
				end
			end
		end
		if err_flag then
			table.insert(errline,line.i)
		end
	end
	log("")
	return errline,err_collect,collect_count,orderly_dialogues
end
-- 将毫秒单位转换到合适的格式
function time_str(timeint)
		local timestr = ''
		-- ms
		timestr = tostring(timeint % 1000).."秒"
		timeint = math.floor(timeint / 1000)
		if timeint >= 0 then
			--s
			timestr = tostring(timeint % 60).."."..timestr
			timeint = math.floor(timeint / 60)
		end
		if timeint > 0 then
			--m
			timestr = tostring(timeint % 60).."分"..timestr
			timeint = math.floor(timeint / 60)
		end
		if timeint > 0 then
			--h
			timestr = tostring(timeint % 60).."时"..timestr
			timeint = math.floor(timeint / 60)
		end
		if timeint > 0 then
			--day
			timestr = tostring(timeint).."天 "..timestr
		end
		return timestr
end
function display_counts(orderly_dialogues,collect_count)
	println("—— 计数统计 ——")
	println("有效的行数：",#orderly_dialogues)
	println("非空行总数：",collect_count.no_empty)
	println("空白行总数：",collect_count.empty)
	println("特效行总数：",collect_count.effect)
	println("行最长持续：",time_str(collect_count.max_dur))
	println("行最短持续：",time_str(collect_count.min_dur))
	println("行的总长度：",time_str(collect_count.total_length))
	println("行端点距离：",time_str(collect_count.end_time - collect_count.start_time))
	println("行平均长度：",math.floor(collect_count.total_length / #orderly_dialogues +0.5)/1000,"s")
end
function _run_auto_check(subs, only_one)
	-- 获取代理对象
	println(">>> 开始检查 <<<")
	local psubs = subsTool.presubs(subs)
	local errline, err_collect, collect_count, orderly_dialogues = real_run_auto_check(psubs, only_one)
	--[[
		local collect_count = {
			normal = 0 -- 普通行(包括空行，不包括评论)
			,no_empty = 0 -- 非空行
			,empty = 0 -- 空行
			,comment = 0 -- 评论行
			,actor = 0 -- 编辑了说话人的行
			,effect = 0 -- 特效行
			,max_dur = 0 -- 轴最大持续
			,min_dur = 0 -- 轴最短持续
			,start_time = nil -- 轴的起始时间
			,end_time = 0 -- 轴的结束时间
			,empty_length = 0 -- 轴间距总长(起始轴与结束轴之间空白部分总长)
			,total_length = 0 -- 总轴长度
		}
	]]

	aeg.setTask("操作完成")
	-- 输出文件统计
	display_counts(orderly_dialogues,collect_count)
	println("")
	println("—— 异常统计 ——")
	println("警告行总数：",#errline)
	-- 预检查统计
	for title,val in pairs(err_collect) do
		println(title,"：",val)
	end
	-- 行检查统计
	for _,dealitem in ipairs(auto_check) do
		if dealitem.enable and autocheck_options.get(dealitem.bindkey) then
			println(dealitem.title,"：",#dealitem.errline)
		end
	end
	-- 返回前转换为标准AEG返回值
	for i,v in ipairs(errline) do
		errline[i] = psubs.getSourceIndex(v)
	end
	return errline
end
function run_auto_check(subs)
	return _run_auto_check(subs)
end


--[[
	配置菜单函数
]]
-- 黑白名单设置
function macro_errchar_whilelist_config()
	-- ac_errchar_whilelist
	AC_init()
	local lconf = tool_getReDecode(tool_getConfig("ac_errchar_whilelist"))
	local newinput = inputTextArea("设置白名单列表",lconf)
	if newinput == nil then
		return
	end
	newinput = string.trim(newinput)
	newinput = tool_getReEncode(newinput)
	if newinput == '' then
		return
	end
	if lconf ~= newinput then
		tools.setConfig("ac_errchar_blacklist",newinput)
	end
	alert("设置成功！")
end
function macro_errchar_blacklist_config()
	-- ac_errchar_blacklist
	AC_init()
	local lconf = tool_getReDecode(tool_getConfig("ac_errchar_blacklist"))
	local newinput = inputTextArea("设置黑名单列表",tool_getReDecode(lconf))
	if newinput == nil then
		return
	end
	newinput = string.trim(newinput)
	newinput = tool_getReEncode(newinput)
	if newinput == '' then
		return
	end
	if lconf ~= newinput then
		tools.setConfig("ac_errchar_blacklist",newinput)
	end
	alert("设置成功！")
end
-- 闪轴(间隔)
function macro_flash_interval_config()
	-- ac_flash_interval
	AC_init()
	local lconf = tonumber(tool_getConfig("ac_flash_interval"))
	local newinterval = inputInt("输入闪轴界限(ms)：",lconf)
	if newinterval == nil then
		return
	end
	if newinterval < 100 then
		alert("设置的值过低！")
		return
	end
	if newinterval > 10000 then
		alert("设置的值过高！")
		return
	end
	tools.setConfig("ac_flash_interval",newinterval)
	alert("设置成功！")
end
-- 闪轴(短轴)
function macro_flash_short_config()
	-- ac_flash_short
	AC_init()
	local lconf = tonumber(tool_getConfig("ac_flash_short"))
	local newinterval = inputInt("输入短轴界限(ms)：",lconf)
	if newinterval == nil then
		return
	end
	if newinterval < 100 then
		alert("设置的值过低！")
		return
	end
	if newinterval > 10000 then
		alert("设置的值过高！")
		return
	end
	tools.setConfig("ac_flash_short",newinterval)
	alert("设置成功！")
end
-- 闪轴(联动)
function macro_flash_linkage_config()
	-- ac_flash_linkage
	AC_init()
	local lconf = tonumber(tool_getConfig("ac_flash_linkage"))
	local newinterval = inputInt("输入联动对齐界限(ms)：",lconf)
	if newinterval == nil then
		return
	end
	if newinterval < 10 then
		alert("设置的值过低！")
		return
	end
	if newinterval > 1000 then
		alert("设置的值过高！")
		return
	end
	tools.setConfig("ac_flash_linkage",newinterval)
	alert("设置成功！")
end

-- 二进制复制文件
function copyFile(sourcePath,targetPath)
	local rf = io.open(sourcePath,"rb") --使用“rb”打开二进制文件，如果是“r”的话，是使用文本方式打开，遇到‘0’时会结束读取
	local len = rf:seek("end")  --获取文件长度
	local wf = io.open(targetPath,"wb")  --用“wb”方法写入二进制文件
	if len ~= 0 then
		rf:seek("set",0)--重新设置文件索引为0的位置
		local data = rf:read(len)  --根据文件长度读取文件数据
		wf:write(data)
	end
	rf:close()
	wf:close()
	
end


-- 规则定义说明
function macro_format_des()
	println("————格式化编辑————")
	println("所有的匹配均使用正则表达式进行")
	println("正则表达式库为AEG自带的re模块")
	println("一个格式化文件组成分为三部分")
	println("规则(文件)名、规则(文件)作用域、子规则列表")
	println("规则(文件)名：用于唯一标识一个规则")
	println("规则(文件)作用域：会与行的样式名称匹配，匹配通过的才会应用子规则")
	println("子规则列表：存储子规则的列表，子规则有匹配规则与替换规则")
	println("匹配规则：会与每行的行内容进行匹配，匹配到的会进行提示")
	println("替换规则：用于格式化替换，可类比于AEG自带的正则替换功能")
end
-- 规则编辑
function display_rule_edit(rule_unit)
	local display_config = {
		{class="label", label="正在编辑 "..format_getRuleStr(rule_unit), x=0, y=0,width=31},
		{class="label", label="匹配规则", x=0, y=1,width=31},
		{class="edit",name="matchrule",text=rule_unit[1], x=0, y=2,width=31},
		{class="label", label="替换规则(为空则不替换)", x=0, y=3,width=31},
		{class="edit",name="replacerule",text=rule_unit[2], x=0, y=4,width=31},
	}
	local buttons = {'Save',aegisub.gettext'No'}
	local buttons_id = {cancel = aegisub.gettext'No'}
	local function testRule(matchrule,replacerule)
		re.sub("test", matchrule, replacerule)
	end
	while true do
		btn, btnresult = aegisub.dialog.display(display_config,buttons,buttons_id)
		if btn == buttons[1] then
			local matchrule = btnresult.matchrule
			local replacerule = btnresult.replacerule
			display_config[3].text = matchrule
			display_config[5].text = replacerule
			if matchrule == '' then
				alert("匹配规则不应为空！")
				goto display_rule_edit_continue
			end
			if not pcall(testRule,matchrule,matchrule) then
				alert("匹配规则不合法(编译失败)\n请检查表达式！")
				goto display_rule_edit_continue
			end
			rule_unit[1] = display_config[3].text
			rule_unit[2] = display_config[5].text
			break
		else
			return nil
		end
		break
		::display_rule_edit_continue::
	end
	-- 显示对话框
	return rule_unit
end
-- 格式化文件编辑
function display_format_edit(formatrule)
	local last_select = ''
	local rules = formatrule.rules
	local selitems = {}
	local display_config = {
		{class="label", label="正在编辑规则 "..formatrule.name, x=0, y=0,width=31},
		{class="label", label="样式匹配(作用域匹配)", x=0, y=1,width=31},
		{class="edit",name="scoperule",text=formatrule.scoperule, x=0, y=2,width=31},
		{class="label", label="选择一个规则进行编辑 序号 - 匹配规则 => 替换规则", x=0, y=3,width=31},
		{class="dropdown",name="dropdown" ,items={},value='', x=0, y=4,width=31},
	}
	local buttons = {'Save','New','Edit','Del',aegisub.gettext'No'}
	local buttons_id = {cancel = aegisub.gettext'No'}
	local function getSelect(str)
		if str == nil or str == '' then
			return nil
		end
		local fres = string.find(str,"-") - 1
		return tonumber(string.trim(string.sub(str,0,fres)))
	end
	local getRuleStr = format_getRuleStr
	local function testScope(matchrule)
		re.match("test", matchrule,re.NOSUB)
	end
	while true do
		selitems = {}
		for i,rule in ipairs(rules) do
			table.insert(selitems,tostring(i).." - "..getRuleStr(rule))
		end
		display_config[5].value= last_select == '' and (selitems[1] or '') or last_select
		display_config[5].items=selitems
		aeg.waitAeg()
		-- 显示对话框
		btn, btnresult = aegisub.dialog.display(display_config,buttons,buttons_id)
		if btn == buttons[1] then
			if string.trim(formatrule.scoperule) == "" or btnresult.scoperule ~= formatrule.scoperule then
				if string.trim(btnresult.scoperule) == "" then
					alert("作用域不能为空！\n请检查设置")
					goto display_format_list_continue
				end
				if not pcall(testScope,btnresult.scoperule) then
					alert("作用域不合法(编译失败)！\n请检查设置")
					goto display_format_list_continue
				end
				display_config[1].text = btnresult.scoperule
				formatrule.scoperule = btnresult.scoperule
			end
			if format_write(formatrule.name,formatrule) then
				alert("保存成功！")
				break
			else
				alert("保存失败")
			end
		elseif btn == buttons[2] then
			local new_rule = display_rule_edit({"",""})
			if new_rule ~= nil then
				table.insert(rules,new_rule)
			end
		elseif btn == buttons[3] then
			local sel = getSelect(btnresult.dropdown)
			if sel == nil or sel == '' or rules[sel] == nil then
				alert("您没有选择任何项")
				goto display_format_list_continue
			end
			display_rule_edit(rules[sel])
			last_select = tostring(sel).." - "..getRuleStr(rules[sel])
		elseif btn == buttons[4] then
			local sel = getSelect(btnresult.dropdown)
			if sel == nil or sel == '' or rules[sel] == nil then
				alert("您没有选择任何项")
				goto display_format_list_continue
			end
			if confirm("确认要删除规则 ？\n"..getRuleStr(rules[sel])) then
				last_select = ''
				rules[sel] = nil
			end
		elseif btn == buttons[5] or btn == false then
			break
		end
		::display_format_list_continue::
	end
	return formatrule
end
-- 格式化文件列表
local display_format_last_select = ''
function display_format_list()
	local display_config = {
		{class="label", label="选择一个格式化文件进行操作", x=0, y=0,width=26},
		{class="dropdown",name="dropdown" ,items={},value='', x=0, y=1,width=26},
	}
	local buttons = {'New','Edit','Del',aegisub.gettext'No'}
	local buttons_id = {cancel = aegisub.gettext'No'}
	while true do
		local formatrules,formatnames = format_getCollection()
		display_config[2].items = formatnames or {}
		display_config[2].value = display_format_last_select == '' and (formatnames[1] or '') or display_format_last_select
		aeg.waitAeg()
		-- 显示对话框
		btn, btnresult = aegisub.dialog.display(display_config,buttons,buttons_id)
		if btn == buttons[1] then
			local newf = input("请输入新规则名(文件名规则)")
			if newf == nil then
				goto display_format_list_continue
			end
			if newf == '' or re.match(newf ,[[[\\/:*?"<>|\\.]+]]) ~= nil then
				alert("规则名不能为空或包含 \\/:*?\"<>|\\. 字符")
				goto display_format_list_continue
			end
			if formatrules[newf] ~= nil then
				alert("规则不能与已有规则重名")
				goto display_format_list_continue
			end
			display_format_edit({
				name = newf,
				scoperule = "",
				rules = {}
			})
		elseif btn == buttons[2] then
			local sel = btnresult.dropdown
			if sel == nil or sel == '' or formatrules[sel] == nil then
				alert("您没有选择任何项")
				goto display_format_list_continue
			end
			display_format_last_select = sel
			-- 打开编辑界面
			display_format_edit(formatrules[sel])
		elseif btn == buttons[3] then
			local sel = btnresult.dropdown
			if sel == nil or sel == '' or formatrules[sel] == nil then
				alert("您没有选择任何项")
				goto display_format_list_continue
			end
			display_format_last_select = ''
			if confirm("确认要删除规则 "..formatrules[sel].name.."吗？") then
				success,err = os.remove(format_getFilePath(formatrules[sel].name))
				if success then
					alert("删除成功")
				else
					println("[删除文件]错误,"..err)
					alert("删除失败！")
				end
			end
		elseif btn == buttons[4] or btn == false then
			break
		end
		::display_format_list_continue::
	end
end
function macro_format_config()
	display_format_list()
end
-- 格式化应用
function macro_format_apply(subs)
	local ac_item = {
		-- 是否可用
		enable = true
		-- 标题
		,title = "格式化警告"
		-- 绑定 autocheck_options 中的键
		,bindkey = "格式化检测"
		-- 初始化函数
		,init_func = AC_format_init
		-- 处理函数
		,deal_func = AC_format
		-- 用于保存异常行的行号
		,errline = {}
	}
	local sf = autocheck_options['自动格式化']
	autocheck_options['自动格式化'] = true
	slines = _run_auto_check(subs,ac_item)
	autocheck_options['自动格式化'] = sf
	return slines
end
-- 正则表达式测试
function macro_format_retest()
	local display_config = {
		{class="label", label="匹配规则", x=0, y=0,width=25},
		{class="edit",name="matchrule",text="", x=0, y=1,width=25},
		{class="label", label="替换规则", x=0, y=2,width=25},
		{class="edit",name="replacerule",text="", x=0, y=3,width=25},
		{class="label", label="测试文本", x=0, y=4,width=25},
		{class="textbox",name="teststr",text="", x=0, y=5,width=25,height=10},
	}
	local buttons = {'Match','Replace',aegisub.gettext'No'}
	local buttons_id = {cancel = aegisub.gettext'No'}
	while true do
		-- 显示对话框
		btn, btnresult = aegisub.dialog.display(display_config,buttons,buttons_id)
		display_config[2].text = btnresult.matchrule
		display_config[4].text = btnresult.replacerule
		display_config[6].text = btnresult.teststr
		local result = {}
		if btn == buttons[1] then
			if btnresult.matchrule == "" then
				alert("匹配规则为空！")
				goto macro_format_retest_continue
			end
			if not pcall(
				function () 
					result = re.match(btnresult.teststr, btnresult.matchrule)
				end)
			then
				alert("正则编译错误！")
				result = "匹配 -> 编译错误！"
			end
		elseif btn == buttons[2] then
			if btnresult.matchrule == "" then
				alert("匹配规则为空！")
				goto macro_format_retest_continue
			end
			if not pcall(
				function () 
					result = re.sub(btnresult.teststr, btnresult.matchrule, btnresult.replacerule)
				end)
			then
				alert("正则编译错误！")
				result = "替换 -> 编译错误！"
			end
		else
			break
		end
		println("——————————————————")
		println("测试字符串：",btnresult.teststr)
		println("匹配字符串：",btnresult.matchrule)
		println("替换字符串：",btnresult.replacerule)
		DD("测试结果：\n",result)
		::macro_format_retest_continue::
	end
end

-- 闪轴修复
function macro_flash_fix_apply(subs)
	local ac_item = {
		-- 是否可用
		enable = true
		-- 标题
		,title = "闪轴(间隔)"
		-- 绑定 autocheck_options 中的键
		,bindkey = "闪轴(间隔)"
		-- 初始化函数
		,init_func = nil
		-- 处理函数
		,deal_func = AC_flash_interval
		-- 用于保存异常行的行号
		,errline = {}
	}
	local sf = autocheck_options['修复闪轴(间隔)']
	autocheck_options['修复闪轴(间隔)'] = true
	slines = _run_auto_check(subs,ac_item)
	autocheck_options['修复闪轴(间隔)'] = sf
	return slines
end

-- 默认方法
function os_openpath(path)
	os.execute("explorer "..path)
end
function default_processing()
	alert("暂无实现...")
end
function macro_ass_counts(subs)
	aeg.setTask("文件统计")
	-- 获取分辨率信息
	local psubs = subsTool.presubs(subs)
	local playresx = psubs.infos.playresx and psubs.infos.playresx.value or 0
	local playresy = psubs.infos.playresy and psubs.infos.playresy.value or 0
	local resmeta = meta_resolution(playresx,playresy)
	local orderly_dialogues, collect_count = predeal_filter(psubs, resmeta)
	-- 输出文件统计
	display_counts(orderly_dialogues,collect_count)
end

-- 当前配置
function macro_display_settings()
	AC_init()
	local flist = format_getlist()
	local fstr = ""
	for _,name in ipairs(flist) do
		fstr = fstr..(fstr == "" and "" or ",")..name
	end
	println("————————当前配置————————")
	println("———白名单字符设置———")
	println(tool_getReDecode(tool_getConfig("ac_errchar_whilelist")))
	println("")
	println("———黑名单字符设置———")
	println(tool_getReDecode(tool_getConfig("ac_errchar_blacklist")))
	println("")
	println("———格式化规则设置———")
	println("占位")
	println("")
	println("———闪轴检测设置———")
	println("闪轴界限：",tool_getConfig("ac_flash_interval"),"ms")
	println("短轴界限：",tool_getConfig("ac_flash_short"),"ms")
	println("联动界限：",tool_getConfig("ac_flash_linkage"),"ms")
	println("已加载规则：",fstr)
end

-- 标记
function macro_mark_ingore(subs, selected_lines)
	local cache_lines = {}
	local allignore = true
	for _, i in ipairs(selected_lines) do
		local line = subs[i]
		if not line.comment and line.effect == '' then
			line.i = i
			line.ignore = string.find(line.actor, NO_CHECK_TYPE) ~= nil
			if not line.ignore then
				allignore = false
			end
			table.insert(cache_lines,line)
		end
	end
	for i = 1,#cache_lines do
		local line = cache_lines[i]
		if not allignore then
			if not line.ignore then
				line.actor = line.actor..NO_CHECK_TYPE
			end
		else
			if line.ignore then
				line.actor = string.gsub(line.actor,NO_CHECK_TYPE,"")
			end
		end
		subs[line.i] = line
	end
	return selected_lines
end
function macro_deallmark_ingore(subs, selected_lines)
	local cache_lines = {}
	for i = 1,#subs do
		local line = subs[i]
		if not line.comment and line.effect == '' then
			if string.find(line.actor, NO_CHECK_TYPE) ~= nil then
				line.actor = string.gsub(line.actor,NO_CHECK_TYPE,"")
				subs[i] = line
			end
		end
	end
	return selected_lines
end

-- 菜单结构
varmenu = {
	menus.menu("执行格式化","对当前文件执行格式化",macro_format_apply)
	,menus.menu("修复闪轴","修复显而易见可以修复的闪轴",macro_flash_fix_apply)
	,menus.checkbox("复查模式",recheck_option)
	,menus.next(
		"复查模式",
		{
			menus.menu("复查模式说明","开启复查模式不会检查空行，关闭复查模式后将检查空行",
							function ()
								alert("当前状态："..(recheck_option["开关"] and "开" or "关").."\n开启复查模式不会检查空行\n关闭复查模式后将检查空行") 
							end)
		}
	)
	,menus.checkbox("自动检查选项",autocheck_options)
	,menus.checkbox("自动检查设置",autocheck_settings)
	,menus.next(
		"标记菜单",
		{
			menus.menu("标记忽略","标记或取消标记选中行的检查忽略",macro_mark_ingore)
			,menus.menu("全部取消忽略","取消所有被忽略行的设置",macro_deallmark_ingore)
		}
	)
	,menus.next(
		"闪轴检测设置",
		{
			menus.menu("闪轴(间隔)检测设置","设置间隔闪烁界限",macro_flash_interval_config)
			,menus.menu("闪轴(短轴)检测设置","设置短轴闪烁界限",macro_flash_short_config)
			,menus.menu("闪轴(联动)检测设置","设置联动轴多行闪烁界限",macro_flash_linkage_config)
		}
	)
	,menus.checkbox("乱码字符检测设置",errchar_options)
	,menus.next(
		"乱码字符检测设置",
		{
			menus.menu("严格模式说明","开启严格模式会使用白名单模式，否则是黑名单模式",
					function() 
						alert("当前状态："..(errchar_options["严格模式"] and "开" or "关").."\n开启严格模式会使用白名单模式\n关闭严格模式会使用黑名单模式") 
					end)
			,menus.menu("白名单字符(允许压制)设置","设置白名单字符",macro_errchar_whilelist_config)
			,menus.menu("黑名单字符设置","设置黑名单字符",macro_errchar_blacklist_config)
		}
	)
	,menus.next(
		"格式化设置",
		{
			menus.menu("编辑规则","编辑格式化规则",macro_format_config)
			,menus.menu("正则表达式测试","正则表达式测试",macro_format_retest)
			,menus.menu("打开存储目录","打开格式化文件的存储目录",function() lfs.mkdir(FORMAT_PATH) os_openpath(FORMAT_PATH) end)
			,menus.menu("格式化使用说明","格式化使用说明",macro_format_des)
		}
	)
	,menus.menu("显示当前配置","查看当前配置",macro_display_settings)
	,menus.menu("显示文件统计","查看统计",macro_ass_counts)
	,menus.about()
}
-- 应用菜单设置
aeg.regMacro(script_name,script_description,run_auto_check)
tools.automenu(script_name.."设置",varmenu)