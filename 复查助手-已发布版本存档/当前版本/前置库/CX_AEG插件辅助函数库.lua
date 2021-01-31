--[[
	AEG插件辅助函数库
	版权所属：晨轩°(QQ3309003591)
	接口文档
]]
-- 模块基础信息、接口及常量定义
-- 版本号
lib_version = "1.0.1dev"
-- 更新日志
lib_ChangeLog = [[
1.0.1dev
支持了多选菜单的双向绑定
]]

local lfs = require "lfs"
local re = require 'aegisub.re'
local LEVEL = {
	FATAL = 0
	,ERROR = 1
	,WARNING = 2
	,INFO = 3 -- AEG默认等级
	,DEBUG = 4
	,TRACK = 5
}
local print_level = LEVEL.INFO -- 默认输出等级，用于输出文本
local close_configwrite = false -- 关闭配置文件写入(通过本函数库执行的写入都将被禁止)
-- 设置接口
function setLevel(level)
	if type(level) ~= "number" and ( level >= 1 and level <= 5 ) then
		error("设置的等级必须为整数，且在1~5之间。")
	end
	print_level = math.modf(level)
end
function getLevel()
	return print_level
end
function setCloseConfigWrite(b)
	close_configwrite = (b == true)
end
function getCloseConfigWrite()
	return close_configwrite
end

-- 设置表
local setting = {
	LEVEL = LEVEL
	,setLevel = setLevel -- 设置默认输出等级
	,getLevel = getLevel
	,setCloseConfigWrite = setCloseConfigWrite -- 设置关闭配置写入
	,getCloseConfigWrite = getCloseConfigWrite
}
-- AEG兼容定义(用于使插件在AEG中拥有与IDE相同的响应)
-- 等级输出
function levelout(level,vaule)
	aegisub.debug.out(level, vaule)
end
-- 标准输出
function standout(vaule)
	aegisub.debug.out(print_level, vaule)
end
-- 打印所有能打印的类型
function valueToStr(value)
	if value == nil then
		return "nil"
	end
	if type(value) ~= "table" then
		return tostring(value)
	end
	res = ""
	-- print覆盖
	local function print(val)
		if val == nil then
			res = res .. 'nil'..'\n'
		else
			res = res .. tostring(val)..'\n'
		end
	end
	-- 好用的table输出函数
	local function print_r(t)  
		local print_r_cache={}
		local function sub_print_r(t,indent)
			if (print_r_cache[tostring(t)]) then
				print(indent.."*"..tostring(t))
			else
				print_r_cache[tostring(t)]=true
				if (type(t)=="table") then
					for pos,val in pairs(t) do
						pos = tostring(pos)
						if (type(val)=="table") then
							print(indent.."["..pos.."] => "..tostring(t).." {")
							sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
							print(indent..string.rep(" ",string.len(pos)+6).."}")
						elseif (type(val)=="string") then
							print(indent.."["..pos..'] => "'..val..'"')
						else
							print(indent.."["..pos.."] => "..tostring(val))
						end
					end
				else
					print(indent..tostring(t))
				end
			end
		end
		if (type(t)=="table") then
			print(tostring(t).." {")
			sub_print_r(t,"  ")
			print("}")
		else
			sub_print_r(t,"  ")
		end
	end
	-- 运行函数
	print_r(value)
	-- 打印结果
	return string.sub(res,0,-2)
end

-- 短输出
function print(...)
	local arg = {...}
	maxi = 1
    for i,v in pairs(arg) do
		if i > maxi then maxi = i end
    end
	printResult = ""
    for i = 1,maxi do
        printResult = printResult .. valueToStr(arg[i])
    end
	standout(printResult)
end
function println(...)
	local arg = {...}
	maxi = 1
    for i,v in pairs(arg) do
		if i > maxi then maxi = i end
    end
	arg[maxi + 1] = "\n"
	print(unpack(arg))
end
-- 完整输出
function var_print(...)
	local arg = {...}
	maxi = 1
    for i,v in pairs(arg) do
		if i > maxi then maxi = i end
    end
	printResult = ""
    for i = 1,maxi do
        printResult = printResult .. valueToStr(arg[i])
    end
	standout(printResult)
end
function var_println(...)
	local arg = {...}
	maxi = 1
    for i,v in pairs(arg) do
		if i > maxi then maxi = i end
    end
	arg[maxi + 1] = "\n"
	var_print(unpack(arg))
end

--[[ 其它工具集 ]]
-- 创建偏函数
function functool_partial(func,...)
	local arg = {...}
	local getMerge = function(arg2)
		res = {}
		for _,v in pairs(arg) do
			table.insert(res,v)
		end
		for _,v in pairs(arg2) do
			table.insert(res,v)
		end
		return res
	end	
	return function(...)
		local arg2 = {...}
		return func(unpack(getMerge(arg2)))
	end
end


--[[
	扩展环境
]]
-- 合并表
function table.merge(source,addtable)
	for k,v in pairs(addtable) do  
		source[k] = v
	end
	return source
end
-- 去除首尾空格
local str_trim_expr_pre = re.compile([[^\s+]],re.NOSUB,re.NO_MOD_M)
local str_trim_expr_end = re.compile([[\s+$]],re.NOSUB,re.NO_MOD_M)
function string.trim(str)
	out_str, rep_count = str_trim_expr_pre:sub(str,'')
	out_str, rep_count1 = str_trim_expr_end:sub(out_str,'')
	if not rep_count then rep_count = 0 end
	if not rep_count1 then rep_count1 = 0 end
	rep_count = rep_count + rep_count1
	return out_str
end


--[[
	缩写集
]]


-- 缩写aegisub表
local aeg = aegisub
local aegmin = {}
local aegPath = {}
aeg.regMacro = aegisub.register_macro
aeg.regFilter = aegisub.register_filter
aeg.levelout = levelout
aeg.standout = standout
aeg.exit = aegisub.cancel
aeg.path = aegPath

setmetatable(aeg, {
  __index = function(t, key)
	if aegisub.progress ~= nil then
		aegmin.setTitle = aegisub.progress.title
		aegmin.setProgress = aegisub.progress.set
		aegmin.setTask = aegisub.progress.task
		aegmin.cancelled = aegisub.progress.is_cancelled
		-- 设置还原点
		aegmin.setUndo = aegisub.set_undo_point
		-- 等待AEG响应，同时判断是否取消执行，用户取消执行将结束脚本，参数为结束运行钩子函数
		aegmin.waitAeg = function (func)
			if aegisub.progress.is_cancelled() then
				if type(func) == "function" then
					func()
				end
			end
		end
	end
	return aegmin[key]
  end
})
-- 获取路径说明，无法获取时返回nil
setmetatable(aegPath, {
  __index = function(t, key)
	if key == "data" then
		-- 存储应用数据的位置。在Windows下是指Aegisub安装目录(.exe的位置)。在Mac OS X下被包含在应用包里。在其他类POSIX系统下的目录为 $prefix/share/aegisub/.
		return aegisub.decode_path('?data\\')
		
	elseif key == "user" then
		-- 存储用户数据的位置，例如配置文件，自动备份文件和其他附加的东西。在Windows下，这个路径是 %APPDATA%\Aegisub\； 在Mac OS X下，这个路径是 $HOME/Library/ApplicationSupport/Aegisub/； 在其他类OSIX系统下，这个路径是 $HOME/.aegisub/； 在便携版Aegisub中这个目录是 ?data。
		return aegisub.decode_path('?user\\')
		
	elseif key == "temp" then
		-- 系统临时文件目录。音频缓存和临时字幕文件都存储在这个位置。
		return aegisub.decode_path('?temp')
		
	elseif key == "local" or key == "cache" then
		-- 本地用户设置路径。存储运行缓存文件的位置，例如FFMS2索引和字体配置缓存。Windows下为 %LOCALAPPDATA%\Aegisub 其他系统是 ?user。
		return aegisub.decode_path('?local\\')

	elseif key == "script" then
		-- 只有当你打开一个已经保存在本地的字幕文件时才有作用，为该字幕文件的保存的位置。 
		text = aegisub.decode_path('?script\\')
		if text == '?script\\' then text = nil end
		return text
		
	elseif key == "video" then
		-- 只有读取本地视频后才有作用，为当前读取视频文件的路径，注意读取空白视频时是无法使用该路径的。 
		text = aegisub.decode_path('?video\\')
		if text == '?video\\' then text = nil end
		return text
		
	elseif key == "audio" then
		-- 只有读取本地音频后才有作用，为当前读取音频文件的路径，注意读取空白音频时是无法使用该路径的。
		text = aegisub.decode_path('?audio\\')
		if text == '?audio\\' then text = nil end
		return text
	-- 扩展路径
	elseif key == "config" then
		-- 配置文件路径
		text = aegisub.decode_path('?user\\').."script_config\\"
		lfs.mkdir(text)
		return text
		
	elseif key == "global_script" then
		-- 自动化脚本文件路径
		text = aegisub.decode_path('?data\\').."automation\\autoload\\"
		return text
		
	elseif key == "global_lib" then
		-- 库文件路径
		text = aegisub.decode_path('?data\\').."automation\\include\\"
		return text
		
	elseif key == "autosave" then
		-- 自动保存路径
		text = aegisub.decode_path('?user\\').."autosave\\"
		return text
		
	elseif key == "autoback" then
		-- 自动备份路径
		text = aegisub.decode_path('?user\\').."autoback\\"
		return text
		
	end
	return nil
  end
})

-- 函数定义
--[[
	显示集
]]

-- 显示一个简单的窗口，参数(提示信息[,类型标识[,默认值]])
--[[ 
	类型标识(返回类型)：
		0-提示框(nil)，提示需要每行尽可能短(不超过9个字)
		1-确认取消框(bool)
		2-单行文本输入框(string or nil)
		3-单行整数输入框(number or nil)
		4-单行小数输入框(number or nil)
	注意：整数与小数输入有误时不会限制或报错，可能得到奇怪的结果。
]]
function QuickWindow(msg,type_num,default)
	local config = {} -- 窗口配置
	local result = nil -- 返回结果
	local buttons  = nil
	local button_ids = nil
	if type(msg) ~= 'string' then
		error('display.confirm参数错误-1，提示信息必须存在且为文本类型！',2)
	end
	if type_num == nil then type_num = 0 end
	if type(type_num) ~= 'number' then
		-- db.var_export(type_num)
		error('display.confirm参数错误-2，类型标识必须是数值！',2)
	end
	
	if type_num == 0 then
		config = {
			{class="label", label=msg, x=0, y=0,width=8}
		}
		buttons = {aegisub.gettext'Yes'}
		button_ids = {ok = aegisub.gettext'Yes'}
	elseif type_num == 1 then
		config = {
			{class="label", label=msg, x=0, y=0,width=12}
		}
	elseif type_num == 2 then
		if default == nil then default = '' end
		config = {
			{class="label", label=msg, x=0, y=0,width=12},
			{class="edit", name='text',text=tostring(default), x=0, y=1,width=12}
		}
	elseif type_num == 3 then
		if default == nil then default = 0 end
		if type(type_num) ~= 'number' then
			error('display.confirm参数错误-3，此标识的默认值必须为数值！',2)
		end
		config = {
			{class="label", label=msg, x=0, y=0,width=12},
			{class="intedit", name='int',value=default, x=0, y=1,width=12}
		}
	elseif type_num == 4 then
		if default == nil then default = 0 end
		if type(type_num) ~= 'number' then
			error('display.confirm参数错误-3，此标识的默认值必须为数值！',2)
		end
		config = {
			{class="label", label=msg, x=0, y=0,width=12},
			{class="floatedit", name='float',value=default, x=0, y=1,width=12}
		}
	elseif type_num == 5 then
		if default == nil then default = '' end
		if type(type_num) ~= 'number' then
			error('display.confirm参数错误-3，此标识的默认值必须为数值！',2)
		end
		config = {
			{class="label", label=msg, x=0, y=0,width=12},
			{class="textbox", name='textbox',text=tostring(default), x=0, y=1,width=15,height=10}
		}
	else
		error('display.confirm参数错误，无效的类型标识！',2)
	end
	
	-- 显示对话框
	btn, btnresult = aegisub.dialog.display(config,buttons,button_ids)

	-- 处理并返回结果
	if type_num == 0 then
		result = nil
	elseif type_num == 1 then
		if btn ~= false then
			result = true
		else
			result = false
		end
	elseif type_num == 2 then
		if btn ~= false then
			result = btnresult.text
		end
	elseif type_num == 3 then
		if btn ~= false then
			result = btnresult.int
		end
	elseif type_num == 4 then
		if btn ~= false then
			result = btnresult.float
		end
	elseif type_num == 5 then
		if btn ~= false then
			result = btnresult.textbox
		end
	end
	-- debug.var_export(result)
	return result
end

-- JS拟态提示框
-- 警告框 参数 显示的消息 | 返回值 nil
function alert(msg)
	return QuickWindow(msg,0,"")
end
-- 确认框 参数 显示的消息 | 返回值 true/false
function confirm(msg)
	return QuickWindow(msg,1,"")
end
-- 文本输入框 参数 显示的消息，默认值 | 返回值 用户文本/nil
function prompt(msg,defval)
	return QuickWindow(msg,2,defval)
end
input = prompt

-- 文本域输入框 参数 显示的消息，默认值 | 返回值 用户文本/nil
function inputTextArea(msg,defval)
	return QuickWindow(msg,5,defval)
end

-- 整数输入框 参数 显示的消息，默认值 | 返回值 用户文本/nil
function inputInt(msg,defval)
	return QuickWindow(msg,3,defval)
end
-- 小数输入框 参数 显示的消息，默认值 | 返回值 用户文本/nil
function inputFloat(msg,defval)
	return QuickWindow(msg,4,defval)
end


-- 打开文件选择窗口(标题，过滤器，默认目录，所选文件必须存在，默认文件名，允许多选)
select_file_last_select_path = ""
function select_file(title, wildcards, default_dir, must_exist, default_file, allow_multiple)
	if title == nil then title = '选择文件' end
	if default_file == nil then default_file = '' end
	if default_dir == nil then
		default_dir = ''
		if select_file_last_select_path then
			default_dir = select_file_last_select_path
		else
			temp_path = aegisub.decode_path('?script\\file')
			if temp_path ~= '?script\\file' then
				default_dir = temp_path
			end
		end
	end
	if wildcards == nil then wildcards = '所有文件(*)|*' end
	if allow_multiple == nil then allow_multiple = false end
	if must_exist == nil then must_exist = true end
	file_name = aegisub.dialog.open(title, default_file, default_dir, wildcards, allow_multiple, must_exist)
	if file_name then select_file_last_select_path = file_name end
	return file_name
end

local display = {
	-- 显示一个简单的提示窗口，参数(提示信息[,类型标识[,默认值]])
	QuickWindow = QuickWindow
	,alert = alert -- 警告框 参数 显示的消息 | 返回值 nil
	,confirm = confirm -- 确认框 参数 显示的消息 | 返回值 true/false
	,inputTextArea = inputTextArea
	,prompt = prompt -- 文本输入框 参数 显示的消息，默认值 | 返回值 用户文本/nil
	,input = input 
	,inputInt = inputInt
	,inputFloat = inputFloat
	-- 打开文件选择窗口(标题，过滤器，默认目录，所选文件必须存在，默认文件名，允许多选) 返回 文件路径
	,select_file = select_file
}

--[[
	字幕行工具
]]
function subs_getFirstDialogue(subs)
	for i = 1,#subs do
		if subs[i].class == 'dialogue' then
			return i
		end
	end
end
function subs_getStyles(subs)
	styles = {cout_n=0} -- 字幕行
	infos = {cout_n=0} -- 信息行
	unknows = {cout_n=0} -- 未知行
	first_dialogue = nil
	for i = 1,#subs do
		line = subs[i]
		if line.class == 'style' then
			styles.cout_n = styles.cout_n + 1
			styles[line.name] = {
				index = i
				,line = line
			}
		elseif line.class == 'info' then
			infos.cout_n = infos.cout_n + 1
			infos[line.key:lower()] = {
				index = i
				,line = line
				,key = line.key
				,value = line.value
			}
		elseif line.class == 'unknown' then
			unknows.cout_n = unknows.cout_n + 1
			table.insert(unknown,{
				index = i
				,line = line
			})
		elseif line.class == 'dialogue' then
			first_dialogue = i
			break
		end
	end
	return styles,first_dialogue,infos,unknows
end
function subs_collect_head(subs)
	styles,first_dialogue,infos,unknows = subs_getStyles(subs)
	return {
		firstDialogue = first_dialogue
		,styles = styles
		,infos = infos
		,unknows = unknows
	}
end
function subs_pre_deal(subs)
	--[[
		代理原subs对象
		解决各种不爽的问题，尽可能降低因操作subs导致的AEG崩溃可能
	]]
	heads = subs_collect_head(subs)
	local function getIter(tab,start_i,end_i)
		local si = start_i
		local ni = si
		local ei = end_i
		return function ()
			ni = ni + 1
			if (ni - 1) <= ei then
				return ni - si,tab[ni - 1]
			end
		end
	end
	local function getCollectIter(tab)
		local tabiter = pairs(tab)
		local k = nil
		return function ()
			k,v = tabiter(tab,k)
			if k == "cout_n" then
				k,v = tabiter(tab,k)
			end
			if k ~= nil then
				return v.index,v.line
			end
		end
	end
	proxySubs = {
		subs = subs
		,heads = heads
		,otherData = {
			-- 暂未确定
		}
		-- 获取原始行标
		,getSourceIndex = function (i)
			return i + proxySubs.heads.firstDialogue - 1
		end
		-- 获取重定向行标
		,getIndex = function (i)
			return i - proxySubs.heads.firstDialogue - 1
		end
		-- 兼容定义
		,raw_insert = subs.insert -- 插入
		,raw_delete = subs.delete -- 删除
		,raw_deleterange = subs.deleterange -- 范围删除
		,raw_append = subs.append -- 追加
		-- 重定向定义
		,insert = function (i,...)
			if i < 0 then
				error("Out of bounds",2)
			end
			i = i + proxySubs.heads.firstDialogue - 1
			if i > #(proxySubs.subs) then
				error("Out of bounds",2)
			end
			return subs.insert(i,...)
		end
		,delete = function (...)
			local args = {...}
			for i = 1, #args do
				if args[i] < 0 then
					error("Out of bounds",2)
				end
				args[i] = args[i] + proxySubs.heads.firstDialogue - 1
				if args[i] > #(proxySubs.subs) then
					error("Out of bounds",2)
				end
			end
			return subs.delete(unpack(args))
		end
		,deleterange = function (first,last)
			if first < 0 or last < 0 then
				error("Error delete range",2)
			end
			first = first + proxySubs.heads.firstDialogue - 1
			last = last + proxySubs.heads.firstDialogue - 1
			if first > #(proxySubs.subs) or last > #(proxySubs.subs) then
				error("Out of bounds",2)
			end

			if first > last then
				return
			end
			return subs.deleterange(
				first
				,last
				)
		end
		
		,append = function (...)
			local args = {...}
			for _,v in pairs(args) do
				if type(v) ~= "table" or v.class ~= "dialogue" then
					error("插入了不合法的对话行",2)
				end
			end
			return subs.append(unpack(args))
		end
		
	}
	setmetatable(proxySubs,{
		__index = function (mytable, key)
			-- 元素数量数据
			if key == "n" then
				return #rawget(mytable,"subs")
			elseif key == "sn" then -- 字幕数
				return rawget(mytable,"heads").styles.cout_n
			elseif key == "in" or key == "i_n" then -- 信息行数量
				return rawget(mytable,"heads").infos.cout_n
			elseif key == "dn" then -- 对话行数量
				return #rawget(mytable,"subs") - rawget(mytable,"heads").firstDialogue + 1
			elseif key == "fd" then -- 对话行数量
				return rawget(mytable,"heads").firstDialogue

			-- 收集的表数据
			elseif key == "styles" then -- 样式行表
				return rawget(mytable,"heads").styles
			elseif key == "infos" then -- 信息行表
				return rawget(mytable,"heads").infos
			-- 迭代器
			elseif key == "InfosIter" or key == "infosIter" or key == "II" then -- 信息行表迭代器
				return getCollectIter(rawget(mytable,"heads").infos)
			elseif key == "StylesIter" or key == "stylesIter" or key == "SI" then -- 样式行表迭代器
				return getCollectIter(rawget(mytable,"heads").styles)
			elseif key == "DialogueIter" or key == "dialogueIter" or key == "DI" then -- 对话行表迭代器
				local tsubs = rawget(mytable,"subs")
				return getIter(tsubs,rawget(mytable,"heads").firstDialogue,#tsubs)
			end
			
			-- 对话行设置重定向
			if type(key) == "number" then
				if key <= 0 then
					error("Out of bounds",2)
				end
				key = key + rawget(mytable,"heads").firstDialogue - 1
				return rawget(mytable,"subs")[key]
			end
			return rawget(mytable,"subs")[key]
		end
		,__newindex = function (mytable, key, value)
			-- 设置新的值都导向subs
			-- 对话行设置重定向
			if type(key) == "number" then
				if key <= 0 then
					error("Out of bounds",2)
				end
				if type(value) ~= "table" or value.class ~= "dialogue" then
					error("使用了不合法的对话行",2)
				end
				key = key + rawget(mytable,"heads").firstDialogue - 1
			end
			rawget(mytable,"subs")[key] = value
			if type(key) == "number" and key < heads.firstDialogue then
				-- 如果设置的值小于第一行对话行位置则重新收集行信息
				rawset(mytable,"heads",subs_collect_head(rawget(mytable,"subs")))
			end
		end
	})
	return proxySubs
end
--[[
	字幕辅助表
]]
local subsTool = {
	-- 使用subs字幕对象 收集样式信息表 并返回样式表与首个dialogue行的下标
	getStyles = subs_getStyles 
	-- 获取首个dialogue行的下标
	,getFirstDialogue = subs_getFirstDialogue
	-- 字幕行预处理
	,presubs = subs_pre_deal
}



--[[
	其它工具集
]]
-- 序列化
function tool_serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{"
    for k, v in pairs(obj) do
        lua = lua .. "[" .. tool_serialize(k) .. "]=" .. tool_serialize(v) .. ","
    end
    local metatable = getmetatable(obj)
        if metatable ~= nil and type(metatable.__index) == "table" then
        for k, v in pairs(metatable.__index) do
            lua = lua .. "[" .. tool_serialize(k) .. "]=" .. tool_serialize(v) .. ","
        end
    end
        lua = lua .. "}"
    elseif t == "nil" then
        return nil
    else
        error("can not serialize a " .. t .. " type.")
    end
    return lua
end
-- 反序列化
function tool_unserialize(lua)
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not unserialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = loadstring(lua)
    if func == nil then
        return nil
    end
    return func()
end

-- 合并路径与文件名
function getFilePath(filename,path)
	if filename == nil or filename == "" then
		error("文件名不能为空或nil")
	end
	if path == nil then
		error("文件路径不能为nil")
	end
	local filepath = ""
	if string.sub(path, -2) == "\\" then
		filepath = "\\"
	end
	filepath = tostring(path) .. filepath .. tostring(filename)
	return filepath
end
-- 读取一个简单配置文件(xxx.ini)
function tool_readini(filename,path)
	if path == nil or path == "" then path = aeg.path.config end
	local filepath = getFilePath(filename,path)
	res = {}
	file = io.open(filepath, "r")
	if not io.type(file) then
		error("[读取]简单配置文件 "..filepath.." 无法打开！")
	end
	line = file:read()
	if line ~= "[default]" then 
		file:close()
		error("[读取]简单配置文件 "..filepath.." 内容不合法！")
	end
	line = file:read()
	while line do
		pos = string.find(line,"=")
		if pos == nil then 
			file:close()
			error("[读取]简单配置文件 "..filepath.." 内容不合法！")
		end
		key = string.sub(line,0,pos - 1)
		val = string.sub(line,pos + 1,-1)
		val = string.gsub(val,"\\n","\n")
		val = string.gsub(val,"\\\\","\\")
		res[key] = val
		
		line = file:read()
	end
	-- 关闭打开的文件
	file:close()
	return res
end
-- 写入一个简单配置文件(只支持字符串或数值为键，布尔、字符串或数值为值。)
function tool_writeini(tabval,filename,path)
	if path == nil or path == "" then path = aeg.path.config end
	local filepath = getFilePath(filename,path)
	if type(tabval) ~= "table" then
		error("[写入]写入配置文件时错误！写入类型异常！错误文件->"..filepath)
	end
	file = io.open(filepath, "w+")
	if not io.type(file) then
		file:close()
		error("[写入]简单配置文件 "..filepath.." 无法打开！")
	end
	file:write("[default]\n")
	for k,v in pairs(tabval) do
		v = tostring(v)
		v = string.gsub(v,"\\","\\\\")
		v = string.gsub(v,"\n","\\n")
		v = v.."\n"
		file:write(k.."="..v)
	end
	-- 关闭打开的文件
	file:close()
end

-- 读配置 参数为签名
function tool_readConfig(signature)
	if signature == nil then
		if _G.script_signature == nil then
			error("读写配置的签名不能为空！")
		else
			signature = _G.script_signature
		end
	end
	local res = {}
	local status = xpcall(
	function ()
		res = tool_readini(signature..".ini")
	end
	, 
	function (err)
		levelout(4,err)
		levelout(4,"\n")
	end
	)
	return res
end
-- 写配置 参数为要写入的内容，签名
function tool_saveConfig(conftab,signature)
	if signature == nil then
		if _G.script_signature == nil then
			error("读写配置的签名不能为空！")
		else
			signature = _G.script_signature
		end
	end
	if conftab == nil then
		error("保存的配置不能为空！")
	end
	if close_configwrite then
		levelout(4,"配置文件写入已关闭")
		return
	end
	local res = {}
	local status = xpcall(
	function ()
		res = tool_writeini(conftab,signature..".ini")
	end
	, 
	function (err)
		levelout(4,err)
		levelout(4,"\n")
	end
	)
end
-- 读指定配置 参数为 键名，签名
function tool_getConfig(key,signature)
	return tool_readConfig(signature)[key]
end
-- 写指定配置 参数为 键名，值，签名
function tool_setConfig(key,val,signature)
	res = tool_readConfig(signature)
	res[key] = val
	tool_saveConfig(res,signature)
end
-- 清空所有配置 参数为 签名
function tool_clearConfig(signature)
	tool_saveConfig({},signature)
end
-- 创建绑定配置的菜单(需要定义脚本签名才可使用) 参数：菜单前缀，菜单名，绑定的表-键只能为文本-值只能为bool
function tool_MultSelectMenu(prefix,name,bindtab,des)
	local res = tool_readConfig()
	if prefix ~= "" and string.sub(prefix,-1, -1) ~= "/" then
		prefix = prefix.."/"
	end
	if string.sub(name, -2) == "/" then
		name = string.sub(name, 0, -2)
	end
	if des == nil then
		des = ""
	end
	local getFk = function (name,k)
		return "verif_"..name.."_"..k
	end
	local menu = {
		rf = function(prefix,name,bindtab,key)
			bindtab[key] = not bindtab[key]
			tool_setConfig(getFk(name,key),bindtab[key])
		end
		,af = function(prefix,name,bindtab,key)
			return bindtab[key]
		end
	}
	
	local bind_metatable = {
		__index = function(mytable, key)
			if key == "set" then
				return functool_partial(menu.rf,prefix,name,mytable)
			elseif key == "get" then
				return functool_partial(menu.af,prefix,name,mytable)
			end
		end
	}
	setmetatable(bindtab,bind_metatable)
	for k,v in pairs(bindtab) do
		if type(k) ~= "string" then
			error("错误的绑定表",2)
		end
		if type(v) ~= "boolean" then
			error("错误的绑定表值，绑定的值只能为boolean类型",2)
		end
		if res[getFk(name,k)] == nil then
			res[getFk(name,k)] = v
		else
			bindtab[k] = (res[getFk(name,k)] == "true")
		end
		aeg.regMacro(
			prefix..name.."/"..k
			,name.."-"..des
			,functool_partial(menu.rf,prefix,name,bindtab,k)
			,nil
			,functool_partial(menu.af,prefix,name,bindtab,k)
			)
	end
	
end

-- 创建绑定配置的单选菜单(多选一) 参数：菜单前缀，菜单名，绑定的数组-只能为数组-键now标识当前选择
function tool_SingleSelectMenu(prefix,name,bindtab,des)
	local res = tool_readConfig()
	if prefix ~= "" and string.sub(prefix,-1, -1) ~= "/" then
		prefix = prefix.."/"
	end
	if string.sub(name, -2) == "/" then
		name = string.sub(name, 0, -2)
	end
	if des == nil then
		des = ""
	end
	local getFk = function (name,k)
		return "verif_"..name.."_"..k
	end
	local menu = {
		rf = function(prefix,name,bindtab,key)
			bindtab["now"] = key
			tool_setConfig(getFk(name,"now"),key)
		end
		,af = function(prefix,name,bindtab,key)
			return bindtab["now"] == key
		end
	}
	local bind_metatable = {
		__index = function(mytable, key)
			if key == "set" then
				return functool_partial(menu.rf,prefix,name,mytable)
			elseif key == "get" then
				return functool_partial(menu.af,prefix,name,mytable)
			end
		end
	}
	setmetatable(bindtab,bind_metatable)
	for k,v in pairs(bindtab) do
		if type(k) ~= "string" then
			error("错误的绑定表，单选菜单键只能为字符串或now",2)
		end
		if k == "now" and type(v) ~= "string" then
			error("错误的绑定表，now键对应的值只能为字符串",2)
		end
		if k == "now" then
			if res[getFk(name,k)] then
				bindtab["now"] = res[getFk(name,k)]
			end
			goto forend
		end
		aeg.regMacro(
			prefix..name.."/"..k
			,name.."-"..des
			,functool_partial(menu.rf,prefix,name,bindtab,k)
			,nil
			,functool_partial(menu.af,prefix,name,bindtab,k)
			)
		::forend::
	end
	
end

-- 创建菜单类
function tool_next(name,nexttable,defaultmenu)
	-- 创建下级菜单
	return {
		class = "next"
		,name = name
		,nexttable = nexttable
		,default = defaultmenu
	}
end

function tool_About()
	-- 关于的显示函数
	local function about()
		msg = ''
		msg = msg..tostring(_G.script_name)..'，感谢您的使用！'.."\n"
		msg = msg..tostring(_G.script_name)..'，感谢您的使用！'.."\n"
		msg = msg..tostring(_G.script_name)..'，感谢您的使用！'.."\n".."\n"
		msg = msg..'----更新日志结束----'.."\n"
		msg = msg..tostring(_G.script_ChangeLog) .. "\n"
		msg = msg..'-↑↑-更新日志-↑↑-'.."\n"
		msg = msg..'----'..tostring(_G.script_name)..'----'.."\n"
		msg = msg..'作者:'..tostring(_G.script_author).."\n"
		msg = msg..'版本:'..tostring(_G.script_version).."\n"
		msg = msg..'描述:'..tostring(_G.script_description).."\n"
		msg = msg..'\n>>>>关于<<<<'.."\n"..tostring(_G.script_about).."\n"
		aegisub.debug.out(0, msg.."\n")
	end
	return {
		class = "menu"
		,name = "关于"
		,des = "显示关于"
		,processing = about
		,validation = nil
		,is_active = nil
	}
end
function tool_Menu(name,des,processing,validation,is_active)
	if name == nil or type(name) ~= "string" then
		error("菜单的名称必须是个有效的文本",2)
	end
	if processing == nil then
		error("菜单的应用函数必须存在",2)
	end
	return {
		class = "menu"
		,name = name
		,des = des
		,processing = processing
		,validation = validation
		,is_active = is_active
	}
end
function tool_CheckBoxMenu(name,bind,des)
	if type(bind) ~= "table" then
		error("绑定的对象必须是表格",2)
	end
	return {
		class = "checkbox"
		,name = name
		,des = des
		,bind = bind
	}
end
function tool_RadioMenu(name,bind,des)
	if type(bind) ~= "table" or bind.now == nil then
		error("绑定的对象必须是表格，且必须拥有now键",2)
	end
	return {
		class = "radio"
		,name = name
		,des = des
		,bind = bind
	}
end

-- 应用菜单类
function tool_applyMenu(prefix,name,menu)
	if prefix ~= "" and string.sub(prefix,-1, -1) ~= "/" then
		prefix = prefix.."/"
	end
	if string.sub(name, -2) == "/" then
		name = string.sub(name, 0, -2)
	end
	if menu.des == nil then
		menu.des = name
	end
	if menu.class == "menu" then
		aeg.regMacro(
					prefix..name.."/"..menu.name
					,menu.des
					,menu.processing
					,menu.validation
					,menu.is_active
					)
	elseif menu.class == "checkbox" then
		tool_MultSelectMenu(prefix..name,menu.name,menu.bind,menu.des)
	elseif menu.class == "radio" then
		tool_SingleSelectMenu(prefix..name,menu.name,menu.bind,menu.des)
	else
		error("未知的菜单类型",2)
	end

end

-- 自动创建菜单
--[[
	使用符合规则的表格可自动创建
]]
function tool_AutoMenu(name,menutable)
	if type(menutable) ~= "table" then
		error("创建菜单时菜单必须为合法表",2)
	end
	local function getNext(prefix,name,t)
		if prefix ~= "" and string.sub(prefix,-1, -1) ~= "/" then
			prefix = prefix.."/"
		end
		if string.sub(name, -2) == "/" then
			name = string.sub(name, 0, -2)
		end
		for _,v in pairs(t) do
			if type(v) ~= "table" or v.class == nil then
				error("表结构不合法，菜单的值必须为表，且是合法菜单项",2)
			elseif v.class == "next" then
				if v.default then
					if v.default.class == "menu" then
						v.default.name = name
						tool_applyMenu(prefix,name,v.default)
					else
						error("表结构不合法，默认菜单的值必须为合法menu类")
					end
				end
				getNext(prefix..name,v.name,v.nexttable)
			else
				tool_applyMenu(prefix,name,v)
			end
		end
	end
	getNext("",name,menutable)
end

-- 工具表
local tools = {
	serialize = tool_serialize -- 序列化
	,unserialize = tool_unserialize -- 反序列化
	,valueToStr = valueToStr -- 将值转换为字符串
	,readIni = tool_readini -- 读取一个ini文件
	,writeIni = tool_writeini -- 写入一个ini文件
	,readConfig = tool_readConfig -- 读取插件配置
	,saveConfig = tool_saveConfig -- 更新插件配置
	,getConfig = tool_getConfig -- 读指定配置
	,setConfig = tool_setConfig -- 写指定配置
	,clearConfig = tool_clearConfig -- 清空配置
	,func_partial = functool_partial -- 创建偏函数
	,checkboxMenu = tool_MultSelectMenu -- 快速创建多选菜单(对勾菜单)
	,radioMenu = tool_SingleSelectMenu -- 快速创建单选菜单(多选一)
	,automenu = tool_AutoMenu
	,applymenu = tool_applyMenu
	,menus = {
		next = tool_next
		,menu = tool_Menu
		,checkbox = tool_CheckBoxMenu
		,radio = tool_RadioMenu
		,about = tool_About
	}
}

-- table表的copy函数(来自Yutils)
function table.copy(t, depth)
	-- Check argument
	if type(t) ~= "table" or depth ~= nil and not(type(depth) == "number" and depth >= 1) then
		error("table and optional depth expected", 2)
	end
	-- Copy & return
	local function copy_recursive(old_t)
		local new_t = {}
		for key, value in pairs(old_t) do
			new_t[key] = type(value) == "table" and copy_recursive(value) or value
		end
		return new_t
	end
	local function copy_recursive_n(old_t, depth)
		local new_t = {}
		for key, value in pairs(old_t) do
			new_t[key] = type(value) == "table" and depth >= 2 and copy_recursive_n(value, depth-1) or value
		end
		return new_t
	end
	return depth and copy_recursive_n(t, depth) or copy_recursive(t)
end


-- 暴露的接口
--[[
-- 此注释里的语句可将环境导入全局环境中
-- 导入
local cx_help = require"CX_AEG插件辅助函数库"
-- 合并函数环境
cx_help.table.merge(_G,cx_help)
]]
local CX_AEG_IMP = {
	-- 设置(设置默认输出等级)
	setting = setting
	-- AEG简写定义
	,aeg = aeg
	
	-- table扩展(支持表合并、表复制)
	,table = table
	,string = string
	
	-- 默认简化输出(支持多参数且支持nil输出)
	,print = print
	,println = println
	
	-- 完整输出(支持多参数，支持table输出)
	,vprint = var_print
	,vprintln = var_println
	,DD = var_println
	
	-- 其他环境扩展
	,randomseed = math.randomseed
	,random = math.random 
	
	-- 简单的弹出窗口(仿JavaScript设计)
	,alert = alert
	,confirm = confirm
	,inputTextArea = inputTextArea
	,prompt = prompt
	,input = input 
	,inputInt = inputInt
	,inputFloat = inputFloat
	
	
	-- 定义退出
	,exit = aegisub.cancel
	,tools = tools -- 工具集
	,display = display -- 界面辅助
	,subsTool = subsTool -- AEG字幕行工具
	,menus = tools.menus -- 菜单快捷定义
}
-- 置入随机数种子
math.randomseed(os.time())


-- 暴露的接口
return CX_AEG_IMP



