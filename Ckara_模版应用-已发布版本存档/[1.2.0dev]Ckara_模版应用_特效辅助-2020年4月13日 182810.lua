-- 载入环境

-- 载入官方的tr函数，用于显示官方翻译(如果存在)
-- 一般是个没用的东西
-- local tr = aegisub.gettext

-- Yutils做特效常用的东西
local Yutils = require("Yutils")
-- re正则表达式库
local re = require 'aegisub.re' 
-- 剪贴板操作
local clipboard = require 'aegisub.clipboard'
-- 辅助支持模块
local util = require 'aegisub.util'
local unicode = require 'aegisub.unicode'

-- 辅助支持表
--[[
	cx_Aeg_Lua模块
	
	简介：AEG_lua插件开发辅助模块，使用了re库
	
	==子表==
	debug表:
		changelevel(level) -- 修改调试输出等级(默认为5)
		println(msg) -- 普通输出(换行)
		print(msg) -- 普通输出(不换行)
		var_export(value) -- 打印一个值
		var_dump(value) -- 打印任意值，包括其结构(可以打印表)
	display表：
		confirm(msg,type_num,default) -- 显示一个提示框，参数(提示信息,类型标识,默认值)
			注：后两个参数可选
			类型标识(返回类型)：
			0-提示框(nil)，提示需要每行尽可能短(不超过9个字)
			1-确认取消框(bool)
			2-单行文本输入框(string or nil)
			3-单行整数输入框(number or nil)
			4-单行小数输入框(number or nil)
			注意：整数与小数输入有误时不会限制或报错，可能得到奇怪的结果。
		
]]
-- re正则表达式库
-- local re = require 'aegisub.re' 

-- 调试输出等级
local debug_print_level = 4
-- 输出函数
local function debug_print(msg,level)
	if level == nil then level = debug_print_level end
	if msg == nil then 
		aegisub.debug.out(level, 'nil') 
	else
		aegisub.debug.out(level, tostring(msg))
	end
end
local function debug_println(msg,level)
	if level == nil then level = debug_print_level end
	if msg == nil then 
		aegisub.debug.out(level, 'nil'..'\n') 
	else
		aegisub.debug.out(level, tostring(msg)..'\n')
	end
end

cx_Aeg_Lua = {
	-- re正则表达式
	re = re
	,debug = {
		-- 调试输出定义
		-- 修改调试输出等级(0~5),大于5时置为5,小于0时设为0
		level = function (level)
			if type(level) ~= 'number' then error('错误的调试等级设置！'..tostring(level or 'nil'),2) end
			if level < 0 then level = 0 end
			if level > 5 then level = 5 end
			if level then debug_print_level = level end
			return debug_print_level
		end
		-- 普通输出(带换行、不带换行)
		,print = debug_print
		,println = debug_println
		-- 输出一个变量的字符串表示
		,var_export = function (value,level)
			if level == nil then level = debug_print_level end
			aegisub.debug.out(level, '('..type(value)..')'..tostring(value)..'\n')
		end
		-- 直接输出一个表达式结构信息
		,var_dump = function (value,level)
			if level == nil then level = debug_print_level end
			-- print覆盖
			local function print(msg)
				if msg == nil then 
					aegisub.debug.out(level, 'nil'..'\n') 
				else
					aegisub.debug.out(level, tostring(msg)..'\n')
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
		end
		-- 合并原始debug表
		,setupvalue = debug.setupvalue
		,getregistry = debug.getregistry
		,traceback = debug.traceback
		,setlocal = debug.setlocal
		,getupvalue = debug.getupvalue
		,gethook = debug.gethook
		,sethook = debug.sethook
		,getlocal = debug.getlocal
		,upvaluejoin = debug.upvaluejoin
		,getinfo = debug.getinfo
		,getfenv = debug.getfenv
		,setmetatable = debug.setmetatable
		,upvalueid = debug.upvalueid
		,getuservalue = debug.getuservalue
		,debug = debug.debug
		,getmetatable = debug.getmetatable
		,setfenv = debug.setfenv
		,setuservalue = debug.setuservalue
	}
	,display = {
		-- 显示一个简单的提示窗口，参数(提示信息[,类型标识[,默认值]])
		--[[ 类型标识(返回类型)：
				0-提示框(nil)，提示需要每行尽可能短(不超过9个字)
				1-确认取消框(bool)
				2-单行文本输入框(string or nil)
				3-单行整数输入框(number or nil)
				4-单行小数输入框(number or nil)
			注意：整数与小数输入有误时不会限制或报错，可能得到奇怪的结果。
		]]
		confirm = function (msg,type_num,default)
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
			end
			-- debug.var_export(result)
			return result
		end
		-- 打开文件选择窗口(标题，过滤器，默认目录，所选文件必须存在，默认文件名，允许多选)
		,select_file = function (title, wildcards, default_dir, must_exist, default_file, allow_multiple)
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
			debug.println(default_dir)
			file_name = aegisub.dialog.open(title, default_file, default_dir, wildcards, allow_multiple, must_exist)
			if file_name then select_file_last_select_path = file_name end
			return file_name
		end
	}
	,string = {
	-- 只进行一次的正则表达式编译
	str_trim_expr_pre = re.compile([[^\s+]],re.NOSUB,re.NO_MOD_M)
	,str_trim_expr_end = re.compile([[\s+$]],re.NOSUB,re.NO_MOD_M)
	-- 去除首尾空格
	,trim = function(str)
		out_str, rep_count = cx_Aeg_Lua.string.str_trim_expr_pre:sub(str,'')
		out_str, rep_count1 = cx_Aeg_Lua.string.str_trim_expr_end:sub(out_str,'')
		if not rep_count then rep_count = 0 end
		if not rep_count1 then rep_count1 = 0 end
		rep_count = rep_count + rep_count1
		return out_str, rep_count
	end
	}
	,subs = {
		-- 使用subs字幕对象 收集样式信息表 并返回样式表与首个dialogue行的下标
		getStyles = function (subs)
			styles = {cout_n=0}
			first_dialogue = nil
			for i = 1,#subs do
				line = subs[i]
				if line.class == 'style' then
					styles.cout_n = styles.cout_n + 1
					styles[line.name] = line
				end
				if line.class == 'dialogue' then
					first_dialogue = i
					break
				end
			end
			return styles,first_dialogue
		end
		-- 获取首个dialogue行的下标
		,getFirstDialogue = function (subs)
			for i = 1,#subs do
				if subs[i].class == 'dialogue' then
					return i
				end
			end
		end
	}
}

debug = cx_Aeg_Lua.debug
display = cx_Aeg_Lua.display
help = cx_Aeg_Lua

-- 默认输出等级
debug.level(1)

-- 脚本名
script_name = "Ckara_模版应用"
-- 脚本描述
script_description = "开发版，特效辅助，辅助特效制作"
-- 作者
script_author = "晨轩°"
-- 版本号
script_version = "1.2.0dev"
-- 关于
script_about = [[
这个可能会做成一个微型框架的形式了
一个插件开发框架(笑)
包含的功能有
各类帮助特效制作的功能
]]
-- 更新日志
script_ChangeLog = [[
·1.0.0dev
它来了它来了，它带着它的功能来了
默认使用"Ck_fx"作为自动化标识，"fx"作为模版应用标识，"Ckara"作为Ckara模版应用的模版前缀
自动生成的辅助行会在说话人处添加标识信息
已实现功能：多边框(批量应用、清除)，模版载入，渐变标签(创建、编辑)，once代码编辑器
在开发功能：自定义函数执行(应用到行/样式，提供函数注册功能)-待议，批量应用标签(带内联变量、样式、所选行)
·1.1.0dev
修复了渐变标签颜色生成位置与显示不符的bug
修复了编辑器的换行问题,并支持重新恢复换行符号
·1.2.0dev
修复代码编辑器的显示溢出
增加了模版编辑器(推荐设置快捷键)
]]

-- 关于的显示函数
function about()
	msg = ''
	msg = msg..script_name..'，感谢您的使用！'.."\n"
	msg = msg..script_name..'，感谢您的使用！'.."\n"
	msg = msg..script_name..'，感谢您的使用！'.."\n".."\n"
	msg = msg..'----更新日志结束----'.."\n"
	msg = msg..script_ChangeLog .. "\n"
	msg = msg..'-↑↑-更新日志-↑↑-'.."\n"
	msg = msg..'----'..script_name..'----'.."\n"
	msg = msg..'作者:'..script_author.."\n"
	msg = msg..'版本:'..script_version.."\n"
	msg = msg..'描述:'..script_description.."\n"
	msg = msg..'!!!关于!!!'.."\n"..script_about.."\n"
	aegisub.debug.out(0, msg.."\n")
end

-- 配置菜单
local config = {
	-- 默认输出等级
	out_level = 1,
	-- 自动化标识，每次重新执行应用时会移除与此处标识相同且说话人为空或指定类型说话人的行
	fx_type = "Ck_fx",
	-- Ckara模版标识
	template_type = "Ckara",
	apply_template_type = "fx",
	--- once代码编辑器actor标识
	Ck_eidt = 'Ck_eidt',
	-- 配置文件存储路径
	filepath = aegisub.decode_path('?user\\'),
	-- 配置文件的文件名
	filename = 'Ckara',
	last_open = nil,
}
debug.level(config.out_level)
if config.filepath == '?user\\' then config.filepath = '' end

-- 生成ASSline-字幕行(style,text,start_time,end_time)
function toASSLine(style_,text_,comment_,effect_,actor_,start_time_,end_time_)
	if style_ == nil then style_ = 'Default' end
	if text_ == nil then text_ = '' end
	if actor_ == nil then actor_ = '' end
	if effect_ == nil then effect_ = config.fx_type end
	if start_time_ == nil then start_time_ = 0 end
	if end_time_ == nil then end_time_ = 0 end
	if comment_ == nil then comment_ = false end
	return 	{
			class = "dialogue",
			raw = "",
			section = "[Events]",
			comment = comment_,
			layer = 0,
			start_time = start_time_,
			end_time = end_time_,
			style = style_,
			actor = actor_,
			margin_t = 0,
			margin_b = 0,
			margin_l = 0,
			margin_r = 0,
			margin_v = nil,
			effect = effect_,
			text = text_,
			extra = {}
	}
end
-- 转换Yutils解析的行为ASS兼容行，参数(Yutils的解析行)，返回转换后的行
function conversion_YtoA_line(Yutils_line)
	ASS_line = Yutils_line
	ASS_line.class = "dialogue"
	ASS_line.raw = ""
	ASS_line.section = "[Events]"
	ASS_line.margin_t = ASS_line.margin_v
	ASS_line.margin_b = ASS_line.margin_v
	ASS_line.margin_v = nil
	ASS_line.extra = {}
	return ASS_line
end

-- 文件系统
local file_system = {
	-- 配置文件读写(格式代码来自https://blog.csdn.net/qq_27005821/article/details/85218707)
	-- 有机会就自己重写一遍(估计会咕咕咕)
	--[[
	配置数据结构
		{
			section = {
				键 = 值,
			}
		}
	
	]]
	-- 默认路径是AEG安装路径
	saveConfAll = function(file_path,data)
		assert(type(file_path) == 'string', '文件路径必须是一个字符串！');
		assert(type(data) == 'table', '写入数据必须是一个table！');
		file,msg = io.open(file_path,'w')
		if file == nil then 
			aegisub.debug.out(1, "文件\"%s\"打开失败！\n错误信息：%s\n",file_path,msg)
			aegisub.cancel()
		end
		local contents = '';
		for section, param in pairs(data) do
			contents = contents .. ('[%s]\n'):format(section);
			for key, value in pairs(param) do
				contents = contents .. ('%s=%s\n'):format(key, tostring(value));
			end
			contents = contents .. '\n';
		end
		file:write(contents);
		file:close();
	end
	,loadConfAll = function(file_path)
		assert(type(file_path) == 'string', '文件路径必须是一个字符串！');
		file,msg = io.open(file_path,'r')
		if file == nil then 
			aegisub.debug.out(1, "文件\"%s\"打开失败！\n错误信息：%s\n",file_path,msg)
			aegisub.cancel()
		end
		local data = {}
		local section = nil
		for line in file:lines() do
			local tempSection = line:match('^%[([^%[%]]+)%]$');
			if(tempSection)then
				section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
				data[section] = data[section] or {};
			end
			local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
			if(param and value ~= nil)then
				if(tonumber(value))then
					value = tonumber(value);
				elseif(value == 'true')then
					value = true;
				elseif(value == 'false')then
					value = false;
				end
				if(tonumber(param))then
					param = tonumber(param);
				end
				data[section][param] = value;
			end
		end
		file:close();
		return data;
	end
	-- 读单条(配置路径，读取部分，键)
	,readConf = function (IniPath,Section,Key)
		local data=file_system.loadConfAll(IniPath)
		return data[Section][Key]
	end
	-- 写单条(配置路径，写入部分，键，值)
	,writeConf = function (IniPath,Section,Key,Value)
		local data=file_system.loadConfAll(IniPath)
		data[Section][Key]=Value
		file_system.loadConfAll(IniPath, data)
	end
	-- 读入ASS(文件路径,进度回调函数(value-进度百分比)),返回加载了字幕的Yutils解析器
	,open_ASS_file = function (file_name,progress_func)
		if progress_func == nil then progress_func = function(value) return value end end
		local function set_progress(value)
			aegisub.progress.set(tonumber(progress_func(0)))
		end
		set_progress(0)
		file,msg = io.open(file_name,'r')
		if file == nil then 
			aegisub.debug.out(2, "文件\"%s\"打开失败！\n信息：%s\n",file_name,msg)
			aegisub.cancel()
		end
		io.input(file)
		-- 读取字幕元信息
		text = io.read()
		cout = 1
		-- 存储字幕头部信息
		head = ""
		-- 创建空解析器
		PARSER = Yutils.ass.create_parser()
		set_progress(5)
		while text ~= nil do
			if aegisub.progress.is_cancelled() then aegisub.cancel() end
			cout = cout + 1
			if cout > 1000 then
				aegisub.debug.out(1, "错误，读取超过一千行未结束字幕元信息读取\n")
				aegisub.debug.out(1, "此文件可能不是ASS格式的字幕文件！\n")
				io.close(file)
				aegisub.cancel()
			end
			-- 添加解析
			PARSER.parse_line(text)
			-- 获取正确解析的字幕行信息
			dialogs = PARSER.dialogs()
			-- 查看是否有读取到字幕
			if dialogs.n ~= 0 then
				-- 已读取到至少一行的字幕信息
				-- 重建解析器并跳出元信息读取循环
				PARSER = Yutils.ass.create_parser(head)
				break
			end
			head = head..text.."\n"
			text = io.read()
		end
		set_progress(15)
		debug.println('读取:'..'元信息解析完毕，解析行数:'..cout)
		-- 判断是否真的读取成功
		if text == nil then 
			aegisub.debug.out(2, "此字幕文件没有任何行")
			io.close(file)
			aegisub.cancel()
		end
		
		--aegisub.progress.task('载入样式')
		--debug.println('读取:'..'载入样式')
		--Yutils_styles_deal(subs,PARSER.styles())
		

		-- 读取字幕行
		aegisub.progress.task('读取字幕行')
		debug.println('读取:'..'读取字幕行')
		set_progress(49)
		-- 载入的行
		subs = {}
		cout = 0
		while text ~= nil do
			if aegisub.progress.is_cancelled() then aegisub.cancel() end
			cout = cout + 1
			-- 解析行
			seccess_type = PARSER.parse_line(text)
			set_progress(cout/200 + 49)
			-- debug.println('读取:'..'解析行→'..text)
			
			if not seccess_type and text ~= '' then
				aegisub.debug.out(2, "解析到%d行时出现错误，此行无法解析！\n",cout)
				aegisub.debug.out(2, "解析失败行:%s\n",text)
				-- io.close(file)
				-- aegisub.cancel()
			end
			if cout > 5000 then
				aegisub.debug.out(2, "字幕行数超过一千行，插件无法读取！\n",cout)
				aegisub.cancel()
			end
			if cout % 100 == 0 then
				-- 获取正确解析的字幕行信息
				dialogs = PARSER.dialogs()
				-- 查看是否有读取到特效部分，如果读取到则跳出
				if dialogs[dialogs.n].effect == 'fx' or dialogs[dialogs.n].effect == config.fx_type then
					break
				end
				
			end
			text = io.read()
		end
		set_progress(99)
		-- 关闭文件
		io.close(file)
		debug.println('读取:'..'解析结束，共解析 '..cout..' 行')
		set_progress(100)
		return PARSER
	end
	--获取文件名(代码来自：https://blog.csdn.net/zoutian007/article/details/7654347)
	,getFileName = function (filename)
		return string.match(filename, ".+\\([^\\]*%.%w+)$")
	end
	-- 获取路径(代码来自：https://blog.csdn.net/zoutian007/article/details/7654347)
	,getFilePath = function (filename)
		return string.match(filename, "(.+)\\[^\\]*%.%w+$")
	end
	--获取扩展名(代码来自：https://www.cnblogs.com/kgdxpr/p/4218811.html)
	,getExtension = function (str)
		return str:match(".+%.(%w+)$")
	end
}

-- 载入模版
-- 判断是否是特效行或已经应用的歌词行(发现代表模版截断，之后被认为不存在模版)
function lineIsAutoFx(line)
	if line.effect == 'fx' or 
		line.effect == config.apply_template_type or 
		line.effect == 'karaoke' 
	then
		return true
	end
	return false
end
-- 处理Yutils解析器解析出的行
function Yutils_line_deal(dialogs,progress_func)
	if progress_func == nil then progress_func = function(value) return value end end
	local function set_progress(value)
		aegisub.progress.set(tonumber(progress_func(value)))
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
	end
	set_progress(0)
	-- 模版行
	local temp_subs = {styles = {}}
	-- 检测到连续25行的特效为空 或 特效出现'karaoke'、'fx'标识时剩余行将被忽略
	cout_pass = 0
	expr = re.compile("template");
	exprC = re.compile(config.template_type);
	expr1 = re.compile("歌词",re.NOSUB)
	expr2 = re.compile("中文",re.NOSUB)
	expr3 = re.compile("日文",re.NOSUB)
	expr4 = re.compile("CN",re.NOSUB)
	expr5 = re.compile("JP",re.NOSUB)
	for i = 1,#dialogs do
		set_progress(i/#dialogs*100)
		line = dialogs[i]
		if cout_pass > 25 or lineIsAutoFx(line) then break end
		if not (line.effect == config.fx_type and line.actor == "" and line.comment) then 
			table.insert(temp_subs,conversion_YtoA_line(line))
			if not temp_subs.styles[line.style] then 
				temp_subs.styles[line.style] = {cout = 0,has_template = false,type = ""}
				if expr1:gmatch(line.style)() then temp_subs.styles[line.style].type = "歌词" end
				if expr2:gmatch(line.style)() then temp_subs.styles[line.style].type = "中文" end
				if expr3:gmatch(line.style)() then temp_subs.styles[line.style].type = "日文" end
				if expr4:gmatch(line.style)() then temp_subs.styles[line.style].type = "中文" end
				if expr5:gmatch(line.style)() then temp_subs.styles[line.style].type = "日文" end
			end
			temp_subs.styles[line.style].cout = temp_subs.styles[line.style].cout + 1
			if line.effect == '' then
				cout_pass = cout_pass + 1
			else
				if not temp_subs.styles[line.style].has_template and (expr:gmatch(line.effect)() or exprC:gmatch(line.effect)()) then 
					temp_subs.styles[line.style].has_template = true 
				end
				cout_pass = 0
			end
		end
	end
	set_progress(100)
	debug.println('处理:'..'处理完毕，共识别出模版相关的 '..#temp_subs..' 行')
	return temp_subs
end

--[[
待载入模版的样式名称将作为关键词与当前模版的所有样式进行匹配
匹配成功的样式将互相绑定，配对成功的样式不会参与后续匹配
匹配规则：按照正则表达式规则匹配 或 两匹配样式都拥有关键词 "歌词"、"中文"、"日文"、"CN"、"JP" 的其中之一

·例如:"DD斩首" 与 "DD",其中"DD"是"DD斩首"的关键词之一
注："Default"样式默认不参与匹配

配对成功的待载入模版样式将被全部替换为配对的另一样式

例如：
	当前字幕样式存在 吹雪-中文 , FBKwaring , 
	待载入模版内的样式存在 XX中文 , waring , 中文waring
	则待载入模版的所有"XX中文"样式将被替换为 吹雪-中文
	  待载入模版的所有"waring"样式将被替换为 FBKwaring
	  待载入模版的所有"中文waring"样式不变
]]

-- 添加字幕行至指定行之前
function subs_add_line_deal(subs,add_subs,pos,progress_func)
	if progress_func == nil then progress_func = function(value) return value end end
	local function set_progress(value)
		aegisub.progress.set(tonumber(progress_func(value)))
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
	end
	styles = {}
	exprF = re.compile("furigana",re.NOSUB)
	expr1 = re.compile("歌词",re.NOSUB)
	expr2 = re.compile("中文",re.NOSUB)
	expr3 = re.compile("日文",re.NOSUB)
	expr4 = re.compile("CN",re.NOSUB)
	expr5 = re.compile("JP",re.NOSUB)
	-- 匹配预处理
	set_progress(0)
	subs_num = #subs
	for i = 1,#subs do
		set_progress(i/subs_num*10)
		line = subs[i]
		if line.class == 'style' then
			line.use = false
			if line.name == 'Default' or exprF:gmatch(line.name)() then line.use = true end
			line.type = ""
			if expr1:gmatch(line.name)() then line.type = "歌词" end
			if expr2:gmatch(line.name)() then line.type = "中文" end
			if expr3:gmatch(line.name)() then line.type = "日文" end
			if expr4:gmatch(line.name)() then line.type = "中文" end
			if expr5:gmatch(line.name)() then line.type = "日文" end
			styles[line.name] = line
		end
		if line.class == 'dialogue' then
			break
		end
	end
	set_progress(10)
	-- 绑定
	for addkey,addvalue in pairs(add_subs.styles) do
		for key,value in pairs(styles) do
			if not value.use and ((re.gmatch(key,addkey)() ~= nil) or (value.type ~= "" and value.type == addvalue.type)) then
				value.use = true
				addvalue.bindstyle = key
				break
			end
		end
	end
	set_progress(11)
	--debug.var_dump(styles)
	--debug.var_dump(add_subs.styles)
	-- 添加
	for i = 1,#add_subs do
		set_progress(i/#add_subs*89+11)
		line = add_subs[i]
		-- 添加前处理(替换匹配值)
		if add_subs.styles[line.style].bindstyle then
			line.style = add_subs.styles[line.style].bindstyle
		end
		if line.effect == '' and not line.comment then
			-- 非注释行处理
			line.effect = 'Ck_fx'
			line.actor = 'comment_fix'
			line.comment = true
		end
		subs.insert(pos + i - 1,line)
	end
	set_progress(100)
end
-- 检查模版结束标识 返回(对话行开始下标，模版结束行下标)
function check_template_end(subs)
	check_pass = 0
	dialog_start_num = nil
	for i=1,#subs do
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
		if subs[i].class == 'dialogue' then
			line = subs[i]
			if not dialog_start_num then dialog_start_num = i end
			if check_pass > 5000 or line.effect == 'fx' or line.effect == 'karaoke' then 
				debug.println('错误！没有找到特效结束标识行。\n特效结束标识行已生成在第一行，请移动到适当的位置！')
				subs.insert(dialog_start_num,toASSLine(nil,'template end',true))
				return dialog_start_num,nil
			else
				if line.effect == config.fx_type and line.text == 'template end' and line.comment == true then
					return dialog_start_num,i
				end
				check_pass = check_pass + 1 
			end
		end
	end
	debug.println('错误！没有找到特效结束标识行。\n特效结束标识行已生成在第一行，请移动到适当的位置！')
	subs[-1] = toASSLine(nil,'template end',true)
end

-- 特效辅助
fx_help = {
	-- 双边框
	Dbord = {
		-- 环境变量
		Dbord_type = 'Dbord'
		,last_def_item,last_apply_bord,last_select_color
	}
	-- 渐变标签
	,vc = {
		-- 环境变量
		res = {}
	}
	,Ck_edit = {
		start
	}
	-- 模版编辑器
	,Ck_edit_tl = {
	}
}

-- 多边框
-- 处理样式表，返回items及默认选择值(def_item)
function fx_help.Dbord:styles_dealToItems(styles)
	items = {}
	def_item = nil
	exprF = re.compile("furigana")
	for key,value in pairs(styles) do
		if key ~= 'cout_n' and not exprF:gmatch(key)() then
			if not def_item then def_item = key end
			table.insert(items,key)
		end
	end
	return items,def_item
end
-- 显示样式设置菜单
function fx_help.Dbord:display_setting(styles, active_line_obj, use_style)
	-- 下拉框选项
	--debug.var_dump(self)
	items,def_item = self:styles_dealToItems(styles)
	if last_def_item then def_item = last_def_item end
	-- 默认边框宽度
	def_bord = 2
	if styles[active_line_obj.style] then
		if not self.last_select_color then self.last_select_color = styles[active_line_obj.style].color3 end
		def_bord = styles[active_line_obj.style].borderstyle
	end
	if self.last_apply_bord then
		def_bord = self.last_apply_bord
	end
	-- 对话框选项
	if use_style then
		dialog={
			{class="label", label="应用到", x=0, y=0},
			{class="dropdown", x=1, y=0,name="select_style",hint="选择要应用到的样式",items=items,value=def_item},
			{class="label", label="边框宽度", x=0, y=1},
			{class="intedit",name="bordsize",value = def_bord, hint="输入边框宽度", x=1, y=1},
			{class="label", label="边框颜色", x=0, y=2},
			{class="coloralpha",name="select_color", hint="选择边框颜色",value=self.last_select_color, x=1, y=2},
		}
	else
		dialog={
			{class="label", label="边框宽度", x=0, y=0},
			{class="intedit",name="bordsize",value = def_bord, hint="输入边框宽度", x=1, y=0},
			{class="label", label="边框颜色", x=0, y=1},
			{class="coloralpha",name="select_color", hint="选择边框颜色",value=self.last_select_color, x=1, y=1},
		}
	end
	buttons=nil
	button_ids=nil
	button, result_table = aegisub.dialog.display(dialog, buttons, button_ids)
	if button ~= false then
		if use_style then
			self.last_def_item = result_table.select_style
		end
		self.last_apply_bord = result_table.bordsize
		self.last_select_color = result_table.select_color
		color = util.ass_color(util.extract_color(self.last_select_color))
		alpha = util.alpha_from_style(self.last_select_color)
		--debug.var_dump({result_table,color,alpha})
		return self.last_def_item,self.last_apply_bord,color,alpha
	else
		aegisub.cancel()
	end
end
-- 应用双边框到指定行(字幕对象，样式表，操作行下标，颜色，透明度)
function fx_help.Dbord:applySingleLine(line_num,subs,styles,bordstyle,color,alpha)
	line = subs[line_num]
	--debug.var_dump({line_num=line_num,text=line.text,line=line})
	style = styles[line.style]
	if style then
		bordstyle = bordstyle + style.borderstyle
	else
		bordstyle = bordstyle + 2
	end
	prefix_text = '{\\4a&HFF&\\bord'..bordstyle..'\\3c'..color..'\\3a'..alpha..'}'
	if line.layer == 254 then line.layer = 0 end
	line.layer = line.layer + 1
	subs[line_num] = line
	line.actor = self.Dbord_type
	line.effect = config.fx_type
	line.text = prefix_text..line.text
	line.layer = line.layer - 1
	subs.insert(line_num+1,line)
end
-- 清除所有双边框应用
function fx_help.Dbord:clearDbord(subs)
	if progress_func == nil then progress_func = function(value) return value end end
	local function set_progress(value)
		aegisub.progress.set(tonumber(progress_func(value)))
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
	end
	set_progress(0)
	start = help.subs.getFirstDialogue(subs)
	del_num = 0
	endnum = #subs
	i = start
	while i <= (endnum - del_num) do
		set_progress((i/(endnum - del_num))*100)
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
		line = subs[i]
		if line.actor == self.Dbord_type and line.effect == config.fx_type then
			debug.println('删除:'..(i - start + 1)..'行')
			subs.delete(i)
			i = i - 1
			del_num = del_num + 1
		end
		i = i + 1
	end
	set_progress(100)
	return del_num
end
-- 双边框应用函数
function fx_help.Dbord:apply(subs, selected_lines, active_line,use_style)
	if progress_func == nil then progress_func = function(value) return value end end
	local function set_progress(value)
		aegisub.progress.set(tonumber(progress_func(value)))
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
	end
	set_progress(0)
	if not selected_lines or #selected_lines == 0 then
		display.confirm('错误，没有选择任何行',0)
		aegisub.cancel()
	end
	styles = help.subs.getStyles(subs)
	if styles.cout_n == 0 then 
		display.confirm('错误，样式表为空',0)
		aegisub.cancel()
	end
	set_progress(1)
	-- 打开设置菜单
	stylename,bord,color,alpha = self:display_setting(styles,subs[active_line],use_style)
	set_progress(5)
	if use_style then
		cout_apply_num = 0
		endnum = #subs
		i = 1
		while i <= (endnum + cout_apply_num) do
			set_progress(i/(endnum + cout_apply_num)*95+5)
			line = subs[i]
			if line.style == stylename and line.effect == '' and line.text ~= '' and not line.comment then
				self:applySingleLine(i,subs,styles,bord,color,alpha)
				i = i + 1
				cout_apply_num = cout_apply_num + 1
			end
			i = i + 1
		end
	else
		for i = 1,#selected_lines do
			set_progress(i/#selected_lines*95+5)
			self:applySingleLine(selected_lines[i] + i - 1,subs,styles,bord,color,alpha)
		end
	end
	set_progress(100)
end

-- 编辑器
-- 打开编辑器(字幕对象,默认文本,字幕行起始,编辑行)
replace_enter_back_nc = re.compile('--\\[\\[\\\\N\\]\\]',re.NOSUB)-- 标识不完整
replace_enter_back = re.compile([[ --\[\[\\N\]\] ]],re.NOSUB)-- 有标识无换行
replace_enter = re.compile(' --\\[\\[\\\\N\\]\\]\n ',re.NOSUB) -- 有标识有换行
is_enter = re.compile(' \n ',re.NOSUB) -- 识别换行(需要前后有空格)
is_enter_1 = re.compile('\n',re.NOSUB) -- 前后无空格
function fx_help.Ck_edit:display_edit(subs,def_text,start,edit_num)
	-- 对话框选项
	-- 恢复换行符
	def_text = replace_enter_back:sub(def_text," \n ") -- 有换行标识但没有换行的替换为换行
	def_text = replace_enter:sub(def_text,"\n") -- 有换行标识且携带换行的替换为换行
	def_text = replace_enter_back_nc:sub(def_text,"") -- 替换标识不完整的标识(前后缺少空格)为空
	dialog={
		{class="label", label="Ckara代码编辑器", x=0, y=0},
		{class="label", label="注：注释行请使用”--[[注释内容]]“注释，否则保存之后需要重新运行编辑器进行修正。", x=0, y=1},
		{class="textbox",name="text", value = def_text, width=50,height=20, x=0, y=2},
	}
	buttons=nil
	button_ids=nil
	button, result_table = aegisub.dialog.display(dialog, buttons, button_ids)
	if button ~= false then
		--debug.var_dump(result_table)
		text = result_table.text
		if edit_num == nil then
			subs.insert(start,toASSLine('Default',text,true,'code once',config.Ck_eidt))
		else
			line = subs[edit_num]
			if line.actor ~= '' and line.actor ~= config.Ck_eidt then
				text = ' --[['..line.actor..']]\n'..text
			end
			text = is_enter:sub(text,'\n')
			text = is_enter_1:sub(text,' --[[\\\\N]] ')
			line.actor = config.Ck_eidt
			line.text = text
			subs[edit_num] = line
		end
	else
		aegisub.cancel()
	end
end
-- 收集指定行的text数据(字幕对象,识别特效),并移除第一行以外的行,返回 字幕对象，收集的文本数据，字幕起始下标，编辑位置
function fx_help.Ck_edit:collection_once(subs,effect,progress_func)
	if progress_func == nil then progress_func = function(value) return value end end
	local function set_progress(value)
		aegisub.progress.set(tonumber(progress_func(value)))
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
	end
	set_progress(0)
	def_text = ''
	edit_num = nil
	start = help.subs.getFirstDialogue(subs)
	cout_pass = 0
	i = start
	subs_n = #subs
	while i < subs_n do
		set_progress(i*100/subs_n)
		line = subs[i]
		if line.class == 'dialogue' then
			-- 停止解析条件检测
			if cout_pass > 50 or lineIsAutoFx(line) then break; end
			-- 解析
			if line.effect == effect then
				if edit_num == nil then 
					edit_num = i 
				else
					subs.delete(i)
					i = i - 1
					subs_n = subs_n - 1
				end
				if line.actor ~= '' and line.actor ~= config.Ck_eidt then 
					line.text = ' --[['..line.actor..']] --[[\\N]]\n '..line.text
				else
					line.text = ' --[[分行标识]]'..' --[[\\N]]\n '..line.text
				end
				if def_text == '' then
					def_text = line.text
				else
					def_text = def_text..' --[[\\N]]\n '..line.text
				end
			else
				if line.effect ~= '' then
					cout_pass = cout_pass + 1
				else
					cout_pass = 0
				end
			end
		end
		i = i + 1
	end
	set_progress(100)
	return def_text,start,edit_num
end
-- 收集选择行的text数据(字幕对象,选择行),移除选择范围第一行以外的行,返回 收集的文本数据，编辑位置
function fx_help.Ck_edit:line_merge(subs,selected_lines,progress_func)
	if progress_func == nil then progress_func = function(value) return value end end
	local function set_progress(value)
		aegisub.progress.set(tonumber(progress_func(value)))
		if aegisub.progress.is_cancelled() then aegisub.cancel() end
	end
	set_progress(0)
	def_text = subs[selected_lines[1]].text
	table.sort(selected_lines)
	for i = 2,#selected_lines do
		def_text = def_text..' --[[\\N]]\n '..subs[selected_lines[i] - i + 2].text
		subs.delete(selected_lines[i] - i + 2)
	end
	set_progress(100)
	edit_num = selected_lines[1]
	return def_text,edit_num
end

-- 模版编辑器(仅支持单行)
-- 格式化模版行
function fx_help.Ck_edit_tl:templateToStand(text)
	-- 多倍文本
	local function doubletext(text,num)
		local new_text = ''
		for i = 1,num do new_text = new_text..text end
		return new_text
	end
	new_text = ''
	-- 是否在!!内
	incode = false
	-- ()括号层次计数(用于缩进)
	cout_l = 0
	-- 缩进值(默认无缩进)
	addtext = ''
	for c in unicode.chars(text) do
		local pretext = ''
		local endtext = ''
		if c == '!' then 
			if not incode then pretext = '\n'..doubletext(addtext,cout_l) end
			incode = not incode 
		elseif not incode then
			-- 不在代码区域内时进行计算
			-- 计算层次并验证层次是否可用
			if c == '(' then cout_l = cout_l + 1 end
			if c == ')' then cout_l = cout_l - 1 end
			if cout_l < 0 then 
				debug.var_dump('错误：括号数量不对等',1)
				cout_l = 0
			end
			-- 赋值
			if c == '\\' or c == ')' then 
				pretext = '\n'..doubletext(addtext,cout_l)
			end
		end
		new_text = new_text..pretext..c..endtext
	end
	--debug.var_dump(new_text,1)
	return new_text
end
-- 需要使用代码编辑器的以下识别
-- is_enter_1 = re.compile('\n',re.NOSUB) -- 前后无空格
function fx_help.Ck_edit_tl:display_edit(subs,edit_num)
	-- 对话框选项
	-- 格式化
	line = subs[edit_num]
	def_text = self:templateToStand(line.text)
	dialog={
		{class="label", label="Ckara模版编辑器", x=0, y=0},
		{class="label", label="注：使用格式化规则进行自动格式化，考虑到可能的问题没有进行缩进。", x=0, y=1},
		{class="textbox",name="text", value = def_text, width=50,height=20, x=0, y=2},
	}
	buttons=nil
	button_ids=nil
	button, result_table = aegisub.dialog.display(dialog, buttons, button_ids)
	if button ~= false then
		--debug.var_dump(result_table)
		text = result_table.text
		if edit_num == nil then
			subs.append(toASSLine('Default',text,true,'code once',config.Ck_eidt))
		else
			text = is_enter_1:sub(text,'')
			if line.actor == '' then line.actor = config.Ck_eidt end
			line.text = text
			subs[edit_num] = line
		end
	else
		aegisub.cancel()
	end
end
-- 杂项

-- 渐变标签
-- 打开设置界面
function fx_help.vc:display_setting()
	local function conversion_color(coloralpha)
		return util.ass_color(util.extract_color(coloralpha)),util.alpha_from_style(coloralpha)
	end
	-- 对话框选项
	dialog={
		{class="label", label="选择四个角的颜色",width=2, x=0, y=0},
		{class="coloralpha",name="colorLU", width=1, value=self.res.colorLU, x=0, y=1},
		{class="coloralpha",name="colorLD", width=1, value=self.res.colorLD, x=0, y=2},
		{class="coloralpha",name="colorRU", width=1, value=self.res.colorRU, x=1, y=1},
		{class="coloralpha",name="colorRD", width=1, value=self.res.colorRD, x=1, y=2},
	}
	buttons=nil
	button_ids=nil
	button, result_table = aegisub.dialog.display(dialog, buttons, button_ids)
	if button ~= false then
		self.res = result_table
		color1,alpha1 = conversion_color(result_table.colorLU)
		color2,alpha2 = conversion_color(result_table.colorLD)
		color3,alpha3 = conversion_color(result_table.colorRU)
		color4,alpha4 = conversion_color(result_table.colorRD)
		return {
				{c=color1,a=alpha1},
				{c=color2,a=alpha2},
				{c=color3,a=alpha3},
				{c=color4,a=alpha4}
			}
	else
		aegisub.cancel()
	end
end
-- 创建
function fx_help.vc:create(subs, selected_lines, active_line)
	res = self:display_setting()
	line = subs[active_line]
	pre_text = '{\\1vc('..res[1].c..','..res[3].c..','..res[2].c..','..res[4].c..')'
	pre_text = pre_text..'\\1va('..res[1].a..','..res[3].a..','..res[2].a..','..res[4].a..')}'
	line.text = pre_text..line.text
	subs[active_line] = line
end



-- re.match(str, "")
--注册规范
--[[
	{	
		-- 前置菜单
		prefix_menu = ''
		,menu = '测试'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			display.confirm('开发中...',0)
		end
		-- 可用性函数
		--,can_use = nil
	}
]]
-- 注册表
local macro = {
	-- 菜单后缀(菜单中的“/”符号可以用来构造子菜单)
	menu_suffix = "-菜单/"
	-- 默认描述
	,default_description = script_description
	-- 默认可用性函数
	,default_canuse = function(subs, selected_lines, active_line)
		return true
	end
	-- 注册菜单
	,{	
		menu = '载入模版'
		,description = '载入新模版替换原来的模版'
		--启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			-- 查找行开始标识及模版结束标识
			dialog_start_num,template_line_num = check_template_end(subs)
			if not template_line_num then return end
			
			-- 选择文件
			cf_title = '选择待载入的模版'
			cf_wildcards = 'ASS文件(.ass)|*.ass|所有文件(*)|*'
			file_name = display.select_file(cf_title,cf_wildcards)
			if not file_name then
				-- 如果未选择文件
				debug.println("取消操作...")
				aegisub.progress.task('选择取消')
				aegisub.cancel()
			end
			
			-- 读文件 获取Yutils解析器
			PARSER = file_system.open_ASS_file(file_name,function(value) return value/2 end)
			dialogs = PARSER.dialogs()
			PARSER = nil -- 释放解析器
			
			-- 处理行
			dialogs = Yutils_line_deal(dialogs,function(value) return value*0.2 +50 end)
			
			-- 删除旧模版行
			subs.deleterange(dialog_start_num,template_line_num)
			
			-- 置入新行
			subs.insert(dialog_start_num,toASSLine(nil,'载入模版文件：'..file_system.getFileName(file_name),true))
			subs.insert(dialog_start_num + 1,toASSLine(nil,'',true))
			subs_add_line_deal(subs,dialogs,dialog_start_num + 2)
			subs.insert(dialog_start_num + #dialogs + 2,toASSLine(nil,'',true))
			subs.insert(dialog_start_num + #dialogs + 3,toASSLine(nil,'template end',true))
			return {dialog_start_num}
		end
		--,can_use = nil
	}
	-- 多边框/
	,{	
		prefix_menu = '多边框/'
		,menu = '当前选择行'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			fx_help.Dbord:apply(subs, selected_lines, active_line,false)
		end
		--可用性函数
		--,can_use = nil
	}
	,{	
		prefix_menu = '多边框/'
		,menu = '指定样式'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			fx_help.Dbord:apply(subs, selected_lines, active_line,true)
		end
		--可用性函数
		--,can_use = nil
	}
	,{	
		prefix_menu = '多边框/'
		,menu = '清除所有'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			del_num = fx_help.Dbord:clearDbord(subs)
			display.confirm('清除完成，共清除'..del_num..'行')
		end
		--可用性函数
		--,can_use = nil
	}
	-- 模版编辑器
	,{	
		-- 前置菜单
		prefix_menu = ''
		,menu = '模版编辑器'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			line = subs[active_line]
			if not active_line or line.class ~= 'dialogue' then 
				display.confirm('错误，没有选择任何行！',0)
				aegisub.cancel()
			end
			fx_help.Ck_edit_tl:display_edit(subs,active_line)
			return {active_line}
		end
		-- 可用性函数
		--,can_use = nil
	}
	-- 编辑器/
	,{	
		-- 前置菜单
		prefix_menu = ''
		,menu = 'code编辑器-所选行'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			if not selected_lines or #selected_lines == 0 then 
				display.confirm('错误，没有选择任何行！',0)
				aegisub.cancel()
			end
			def_text,edit_num = fx_help.Ck_edit:line_merge(subs,selected_lines)
			fx_help.Ck_edit:display_edit(subs,def_text,edit_num,edit_num)
			return {edit_num}
		end
		-- 可用性函数
		--,can_use = nil
	}
	,{	
		-- 前置菜单
		prefix_menu = '编辑器/'
		,menu = '激活行'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			line = subs[active_line]
			fx_help.Ck_edit:display_edit(subs,line.text,active_line,active_line)
			return {active_line}
		end
		-- 可用性函数
		--,can_use = nil
	}
	,{	
		-- 前置菜单
		prefix_menu = '编辑器/'
		,menu = '所选行'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			if not selected_lines or #selected_lines == 0 then 
				display.confirm('错误，没有选择任何行！',0)
				aegisub.cancel()
			end
			def_text,edit_num = fx_help.Ck_edit:line_merge(subs,selected_lines)
			fx_help.Ck_edit:display_edit(subs,def_text,edit_num,edit_num)
			return {edit_num}
		end
		-- 可用性函数
		--,can_use = nil
	}
	,{	
		-- 前置菜单
		prefix_menu = '编辑器/'
		,menu = '指定模版特效'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			text = display.confirm('请输入特效名',2,'code once')
			if text == nil then aegisub.cancel() end
			def_text,start,edit_num = fx_help.Ck_edit:collection_once(subs,text)
			fx_help.Ck_edit:display_edit(subs,def_text,start,edit_num)
			return {edit_num}
		end
		-- 可用性函数
		--,can_use = nil
	}
	
	-- 杂项/
	-- 渐变标签
	,{	
		-- 前置菜单
		prefix_menu = '杂项/'
		,menu = '创建渐变标签'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			fx_help.vc:create(subs, selected_lines, active_line)
		end
		-- 可用性函数
		--,can_use = nil
	}
	-- 轻量模版
	,{	
		menu = '轻量模版-应用至所选行'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			display.confirm('开发中...',0)
		end
		-- 可用性函数
		--,can_use = nil
	}
	,{	
		menu = '轻量模版-应用至指定样式'
		--,description = nil
		-- 启动函数(尽可能少的代码)
		,main = function(subs, selected_lines, active_line)
			display.confirm('开发中...',0)
		end
		-- 可用性函数
		--,can_use = nil
	}
	-- 测试及关于

	,{	
		menu = '关于'
		--,description = nil
		,main = about
		--,can_use = nil
	}
}


-- 注册
for key,value in ipairs(macro) do
	if value.prefix_menu == nil then value.prefix_menu = '' end
	if macro.default_canuse ~= nil and value.can_use == nil then value.can_use = macro.default_canuse end
	if macro.default_description ~= nil and value.description == nil then value.description = macro.default_description end
	aegisub.register_macro(script_name..macro.menu_suffix..value.prefix_menu..value.menu, value.description, value.main, value.can_use)
end