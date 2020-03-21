local tr = aegisub.gettext

script_name = tr"复查小助手"
script_description = tr"检查字幕里可能存在的常见问题，并自动修复或提示，部分功能依赖Yutils"
script_author = "晨轩°"
script_version = "1.3.2 Alpha"

-- 载入re库 正则表达
local re = require 'aegisub.re' 

include("utils.lua")

local config = {
	-- 自定义白名单字符(添加进[[括号内]]，例如 while_errchar = [[#$@]])
	while_errchar = [[]]
}


-- 辅助支持表
local default_config = {
	debug = {
		level = 4
	}
}
cx_Aeg_Lua = {
	debug = {
		-- 调试输出定义
		-- 设置调试输出等级
		level = default_config.debug.level
		-- 修改调试输出等级(0~5 设置大于5的等级时不会输出任何信息,设置值小于0时会被置0)
		,changelevel = function (level)
			if type(level) ~= 'number' then error('错误的调试等级设置！',2) end
			if level < 0 then level = 0 end
			cx_Aeg_Lua.debug.level = level
		end
		-- 普通输出(带换行、不带换行)
		,println = function (msg)
			if cx_Aeg_Lua.debug.level > 5 then return end
			if msg ~= nil then 
				aegisub.debug.out(cx_Aeg_Lua.debug.level, tostring(msg).."\n") 
			else
				aegisub.debug.out(cx_Aeg_Lua.debug.level, "\n")
			end
		end
		,print = function (msg)
			if cx_Aeg_Lua.debug.level > 5 then return end
			if msg == nil then return end
			aegisub.debug.out(cx_Aeg_Lua.debug.level, tostring(msg))
		end

		-- 输出一个变量的字符串表示
		,var_export = function (value)
			aegisub.debug.out(cx_Aeg_Lua.debug.level, '('..type(value)..')'..tostring(value)..'\n')
		end
		-- 直接输出一个表达式结构信息
		,var_dump = function (value)
			-- print覆盖
			local function print(msg)
				cx_Aeg_Lua.debug.println(msg)
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
				print()
			end
			-- 运行函数
			print_r(value)
			-- 打印结果
			
		end

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
				buttons = {'OK!'}
				button_ids = {ok = 'OK!'}
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

	}
}


debug = cx_Aeg_Lua.debug
display = cx_Aeg_Lua.display



-- 来自karaskel的函数，从subs表收集样式和元数据(有大改)
function karaskel_collect_head(subs)
	local meta = {
		-- X和Y脚本分辨率
		res_x = 0, res_y = 0,
		-- 视频/脚本分辨率不匹配的宽高比校正比值
		video_x_correct_factor = 1.0
	}
	local styles = { n = 0 }
	local first_style_line = nil -- 文件里的第一行样式位置

	-- 第一遍：收集所有现有样式并获取分辨率信息
	for i = 1, #subs do
		if aegisub.progress.is_cancelled() then error("User cancelled") end
		local l = subs[i]
		aegisub.progress.set((i/#subs)*4)
		if l.class == "style" then
			if not first_style_line then first_style_line = i end
			-- 将样式存储到样式表中
			styles.n = styles.n + 1
			styles[styles.n] = l
			styles[l.name] = l
			l.margin_v = l.margin_t -- 方便
		elseif l.class == "info" then
			local k = l.key:lower()
			meta[k] = l.value
		end
	end
	
	-- 修正解析度数据(分辨率数据？)
	if meta.playresx then
		meta.res_x = math.floor(meta.playresx)
	end
	if meta.playresy then
		meta.res_y = math.floor(meta.playresy)
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
	return meta, styles
end

-- 来自karaskel的函数，计算行尺寸信息
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


-- 计算行尺寸信息，参数(元信息表,行对应样式,行对象)
function line_math_pos(meta,style,line)
	line.styleref = style
	
	-- 计算行的尺寸信息
	line.width, line.height, line.descent, line.ext_lead = aegisub.text_extents(style, line.text)
	line.width = line.width * meta.video_x_correct_factor
	
	-- 计算行的布局信息
	karaskel_preproc_line_pos(meta,line)
	
end



-- 行错误检测，收集并选择可能错误的所有行信息,参数(字幕对象，样式表，元信息表),返回值新选择行,错误计数
-- 旗下函数通用返回值 bool-是否存在问题，line-行，msg-错误信息
function subs_check_line(subs,styles,meta,select_check)
	new_selected = {}
	-- 默认检测
	select_check_def = {
		size = true,-- 尺寸异常
		error_char = true, -- 乱码字符
		style = true -- 样式不存在
	}
	if not select_check then
		select_check = select_check_def
	end
	-- 行尺寸检测设置
	line_size_check = true
	-- 定义筛选后用于返回后续处理的行表(允许判断的有效行下标)
	local dialogues = {} -- 对话行的表(start_line对话行开始下标)
	local styles_less = {} -- 样式不存在记录
	-- 获取视频信息
	video_xres, video_yres, video_ar, video_artype = aegisub.video_size()
	if not(video_xres and video_yres) then
		line_size_check = false
		debug.println('行尺寸检测：检测到未打开视频，此功能已禁用')
	else
		debug.println('行错误检测：视频分辨率信息 '..video_xres..'x'..video_yres)
	end

	-- 计数表
	cout = {
		check_line_total = 0, -- 检测行的总数
		dialogue_effect_total = 0, -- 对话行中特效不为空的行
		dialogue_actor_total = 0, -- 对话行中说话人不为空的行
		dialogue_comment_total = 0, -- 对话行中的注释行总数
		check_total = 0, -- 检测的总行数
		ignore_total = 0,-- 忽略行总数
		err_total = 0, -- 错误行总数
		err_size = 0, -- 错误行中的尺寸异常行计数
		err_char = 0, -- 错误行中的可疑字符行计数
		err_style = 0, -- 错误行中的使用不存在样式的行计数
		err_styles_str = '' -- 错误样式的文字信息
	}
	-- 存储异常样式的表
	err_styles = {}
	-- 存储异常样式文字版
	err_styles_str = ''
	-- 对话行行数存储
	line_n = 0
	debug.println('行错误检测：开始检测行')
	-- debug.var_dump(meta)
	--debug.var_dump(styles)
	
	-- 编译正则表达式
	expr = re.compile([[(\{[\s\S]+?\}){1}]],re.NOSUB)
	
	for i = 1,#subs do
		if aegisub.progress.is_cancelled() then 
			debug.println('\n复查助手:'..'用户取消操作\n\n')
			aegisub.cancel()
		end
		if subs[i].class == 'dialogue' then
			aegisub.progress.set((i/#subs)*80 + 10)
			line_n = line_n + 1
			-- 检测到对话行
			line = subs[i]
			-- 只判断特效与说话人都未设置且没有被注释的行
			if line.comment then
				cout.dialogue_comment_total = cout.dialogue_comment_total + 1
			end
			if line.effect ~= '' then
				cout.dialogue_effect_total = cout.dialogue_effect_total + 1
			end
			if line.actor ~= '' then
				cout.dialogue_actor_total = cout.dialogue_actor_total + 1
			end
			
			if not line.comment and line.effect == '' and line.actor == '' then
				-- 判断该行是否存在ASS标签，存在ASS标签则忽略此行
				result = expr:match(line.text)
				if not result then
					-- 筛选后的行：非注释、不存在ASS标签且特效与说话人为空
					
					-- 插入行解析数据(排除不解析的行)
					table.insert(dialogues,{pos = i,start_time = line.start_time,end_time = line.end_time,style = line.style})
					--[[
						属性：
						pos -- 行下标
						start_time -- 该行开始时间
						end_time -- 该行结束时间
						style -- 该行样式
					]]
					
					-- 异常标记，检测完成后若有错误则为true
					typebool = false
					
					-- 检查是否含有可疑字符(可能导致压制错误)
					bool,line,msg = line_check_char(line)
					if bool then 
						if select_check.error_char then
							typebool = true
							debug.println('乱码字符检测：第'..line_n..'行，'..msg)
						end
						cout.err_char = cout.err_char + 1
					end
					
				
					style = styles[line.style]
					if style then
						if line_size_check then
							-- 只有对应样式存在且允许执行时执行此函数
							bool,line,msg = line_check_width(meta,style,line)
							if bool then 
								if select_check.size then
									typebool = true
									debug.println('行尺寸检测：第'..line_n..'行，'..msg)
								end
								cout.err_size = cout.err_size + 1
							end
						end
					else
						-- 样式不存在
						if select_check.style then
							-- 允许检查
							if not err_styles[line.style] then
								-- 此前没有检测出这个错误样式
								typebool = true
								-- 添加到检查表
								err_styles[line.style] = true
								if err_styles_str == '' then
									err_styles_str = line.style
								else
									err_styles_str = err_styles_str..' , '..line.style
								end
								
							end
							msg = '样式 '..line.style..' 不存在'
							debug.println('行样式检测：第'..line_n..'行，'..msg)
						end
						cout.err_style = cout.err_style + 1
					end
					
					if typebool then
						-- 将异常行置入新选择表
						subs[i] = line
						table.insert(new_selected,i)
					end
				else
					cout.ignore_total = cout.ignore_total + 1
				end
			else
				cout.ignore_total = cout.ignore_total + 1
			end
		end
	end
	cout.check_line_total = line_n
	cout.check_total = #subs
	cout.err_total = #new_selected
	
	-- 添加错误样式记录文字版
	cout.err_styles_str = err_styles_str
	return new_selected,cout
end

-- 标准检测函数
function line_check_default(line)
	
	return false,line,''
end

-- 行尺寸检测 检测行是否超出屏幕显示范围
function line_check_width(meta,style,line)
	-- 拷贝当前行到临时变量
	temp_line = table.copy(line)
	-- 计算整行尺寸
	line_math_pos(meta,style,temp_line)
	
	-- 检测到越界时修改为true
	fix_type = false
	msg = ''
	--[[
	line.left 行的左边缘X坐标，假设其给定对齐，有效边距并且没有碰撞检测 
	line.center 行中心X坐标，假设其给定对齐，有效边距并且没有碰撞检测 
	line.right 行的右边X坐标，假设其给定对齐，有效边距并且没有碰撞检测 
	line.top 行的顶边Y坐标，假设其给定对齐，有效边距并且没有碰撞检测 
	line.middle 行垂直中心 Y 坐标，假定其给定对齐，有效边距和无碰撞检测 line.vcenter是此的别名 
	line.bottom 行的下边Y坐标，假设其给定对齐，有效边距并且没有碰撞检测
	meta.playresy and meta.playresx
	]]
	--debug.var_dump(meta)
	--debug.var_dump(temp_line)
	
	if temp_line.left < 0 or temp_line.left > meta.res_x then
		fix_type = true
		msg = msg..' 左越界'
	end
	if temp_line.right > meta.res_x then
		fix_type = true
		msg = msg..' 右越界'
	end
	if temp_line.top < 0 or temp_line.top > meta.res_y then
		fix_type = true
		msg = msg..' 上越界'
	end
	if temp_line.bottom > meta.res_y then
		fix_type = true
		msg = msg..' 下越界'
	end
	if fix_type then
		return true,line,msg
	end
	return false,line,''
end

-- 可能会引起压制错误的字符
--[[
㊚
₂
㊤
₃
㊛
㊧
㊥
₄
㊨
㊙
㊦
▦
▧
㎥
▤
▥
⁴
▨
▩
・
♬
☞
◑
₁
◐
☜
▷
◁
♢
♤
♧
♡
▶
◀
㏘
±
≠
≈
≡
＜
＞
≤
≥
∧
∨
≮
≯
∑
∏
∈
∩
∪
⌒
∽
≌
⊙
√
⊥
∥∠
∫
∮
∝
∞
·
∶
∵
∴
∷
‰
℅
￥
＄
°
℃
℉
′
″
￠
〒
¤
○
￡
㏒
㏑
㏕
㎎
㎏
㎜
㎝
㎞
㏄
㎡
◇
◆
■
□
☆
○
△
▽
★
●
▲
▼
♠
♣
♥
♀
♂
√
✔
✘
×
♪
㈱
↔
↕
卐
卍
↖
↑
↗
→
↘
↓
↙
←
㊣

± ≠ ≈ ≡ ＜ ＞ ≤ ≥ ∧ ∨ ≮ ≯ ∑ ∏ ∈ ∩ ∪ ⌒ ∽ ≌ ⊙ √ ⊥ ∥∠ ∫ ∮ ∝ ∞ · ∶ ∵ ∴ ∷ ‰ ℅ ￥ ＄ ° ℃ ℉ ′ ″ ￠ 〒 ¤ ○ ￡ ㏒ ㏑ ㏕ ㎎ ㎏ ㎜ ㎝ ㎞ ㏄ ㎡ ◇ ◆ ■ □ ☆ ○ △ ▽ ★ ● ▲ ▼ ♠ ♣ ♥ ♀ ♂ √ ✔ ✘ × ♪ ㈱ ↔ ↕ 卐 卍 ↖ ↑ ↗ → ↘ ↓ ↙ ← ㊣
㊚₂㊤₃㊛㊧㊥₄㊨㊙㊦▦▧㎥▤▥⁴▨▩・♬☞◑₁◐☜▷◁♢♤♧♡▶◀㏘
]]

-- 比较严格的检测模式
local check_char = [[\x{2E80}-\x{9FFF}\sA-Za-z0-9`~!@#$%^&*()_\-\^…+=<>?:"{}|,.\/;'\\[\]·~！～＠﹪＃￥％＾＄＆*＊（）－＿＼\—＋＝⋯｛｝｜•《》？：“”【】、；‘’＇，。、]]
-- 额外的字符白名单(已经进行过压制测试)
local check_whilelist = [[﹝﹞•¿·︸︷︶︵︿﹀︺︹︽︾﹂﹁﹃﹄︼︻〖〗】【`ˋ¦①②③④⑤⑥⑦⑧⑨⑩㈠㈡㈢㈣㈤㈥㈦㈧㈨㈩ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ± ≠ ≈ ≡ ＜ ＞ ≤ ≥ ∧ ∨ ≮ ≯ ∑ ∏ ∈ ∩ ∪ ⌒ ∽ ≌ ⊙ √ ⊥ ∥∠ ∫ ∮ ∝ ∞ · ∶ ∵ ∴ ∷ ‰ ℅ ￥ ＄ ° ℃ ℉ ′ ″ ￠ 〒 ¤ ○ ￡ ㏒ ㏑ ㏕ ㎎ ㎏ ㎜ ㎝ ㎞ ㏄ ㎡ ◇ ◆ ■ □ ☆ ○ △ ▽ ★ ● ▲ ▼ ♠ ♣ ♥ ♀ ♂ √ ✔ ✘ × ♪ ㈱ ↔ ↕ 卐 卍 ↖ ↑ ↗ → ↘ ↓ ↙ ← ㊣]]

-- 检测并标记任何查找到的可能导致压制错误的行
function line_check_char(line)
	-- 忽略存在ASS标签的行之后
	-- 检查是否存在可能引起压制错误的字符
	result = re.match(line.text, "[^"..check_char..check_whilelist..config.while_errchar.."]+",re.NOSUB)

	if result then
		-- 发现了存在可能引起压制错误的行
		-- debug.println('解析：')
		-- debug.println(line.text)
		-- debug.println(check_char)
		-- debug.var_dump(result)
		msg = '检测到可疑字符 '..result[1].str..' 在第 '..result[1].first..'个字符'
		-- debug.var_dump(result)
		return true,line,msg
	end

	-- 没有问题
	return false,line,''
end


-- 60FPS修复
function fix_60fps(subs)
	debug.println('60FPS修复:'..'开始修复')
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
	debug.println('60FPS修复:'..'修复完成')
end

-- 使用指定样式渲染文本
function text_to_shape(text,style)
	if style.class ~= 'style' then return end
	text = tostring(text)
	FONT_HANDLE = decode.create_font(style.fontname, style.bold, style.italic, style.underline, style.strikeout, style.fontsize)
	shape = FONT_HANDLE.text_to_shape(line.text)
	return shape
end


-- 样式检测
-- 字幕对象解析,解析并检测样式以及检查是否存在未安装字体(字体检测需要Yutils支持)
-- 返回值 bool-是否异常,styles-样式表,meta-元信息表,null_styles_str-未安装字体列表(文本型)
function subs_check_style(subs)
	debug.println('样式检测：收集样式及元信息...')
	
	-- 未安装字体列表(文本型)
	null_styles_str = ''

	meta,styles = karaskel_collect_head(subs)
	aegisub.progress.set(8)
	err_num = 0
	debug.println('样式检测：脚本分辨率信息 '..meta.res_x..'x'..meta.res_y)
	debug.println('样式检测：收集到 '..#styles..' 个样式')
	
	if Yutils then
		debug.println('样式检测：开始检测未安装字体')
		-- 获取系统字体列表
		fonts = Yutils.decode.list_fonts(false)
		result_type = false
		
		-- 建立样式的字体表
		styles_front = {}
		for name,style in pairs(styles) do
			if name ~= 'n' then
				-- 插入表
				styles_front[style.fontname] = {}
				styles_front[style.fontname].name = name
			end
		end
		aegisub.progress.set(9)
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
				debug.println('样式检测：样式 '..style_info.name..' 的 '..frontname..' 字体未安装')
				if null_styles_str == '' then
					null_styles_str = frontname..'('..style_info.name..')'
				else
					null_styles_str = null_styles_str..' , '..frontname..'('..style_info.name..')'
				end
				err_num = err_num + 1
			end
		end
		
	else
		debug.println('样式检测：Yutils载入失败，字体检测无法运行')
	end
	aegisub.progress.set(10)
	debug.println('样式检测：检测完毕')
	return result_type,styles,meta,err_num,null_styles_str
end

-- 闪轴与叠轴检测的前置
-- 字幕对象解析,解析并排序,返回排序后的数组(subs_sort_arr)
-- 返回值 subs_sort_arr-排序后的数组,line_start-对话行起始编号
function parse_sort(subs,basic_progress,add_progress)
	subs_sort_arr = {}
	line_start = 0
	-- 编译正则表达式
	expr = re.compile([[(\{[\s\S]+?\}){1}]],re.NOSUB)
	expr1 = re.compile([[[^\s]{1}]],re.NOSUB)
	
	if not basic_progress then basic_progress = 0 end 
	if not add_progress then add_progress = 30 end 
	
	-- 解析忽略非对话行、空行(允许检测空行)、注释行、带特效标签的行、特效不为空的行
	for i = 1,#subs do
		aegisub.progress.set( i/#subs * add_progress + basic_progress)
		line = subs[i]
		if line.class == 'dialogue' then
			if line_start == 0 then line_start = i - 1 end
			if line.text ~= '' then
				result = expr:match(line.text)
				if not result and not line.comment and line.effect == '' then
					table.insert (subs_sort_arr, { 
						pos =  i , 
						line_id = i - line_start,
						start_time = line.start_time , 
						end_time = line.end_time ,
						style = line.style
					})
				end
			end
		end
	end
	
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
	table.sort(subs_sort_arr,sort_comp)
	
	return subs_sort_arr
end

-- 闪轴检测，参数 subs_sort_arr(parse_sort函数返回值),subs(存在时检测并修复闪轴)
-- 返回值 新选择行
function check_interval200(subs_sort_arr,subs)
	--[[
	{ 
		pos =  i , 
		start_time = line.start_time , 
		end_time = line.end_time ,
		style = line.style
	}
	]]
	
	-- 缓存每个样式的前一行数据
	style_chace = {}
	-- 选择行
	new_selected = {}
	-- 选择限制行
	limit_add = {}
	for i,tl in ipairs(subs_sort_arr) do
		if style_chace[tl.style] then
			interva = tl.start_time - style_chace[tl.style].end_time
			if interva < 200 and interva > 0 then
				-- ＜200ms判断为闪轴
				-- 添加检测到的闪轴到新选择行
				-- 添加历史行(规避重复)
				if not limit_add[style_chace[tl.style].pos] then
					table.insert(new_selected,style_chace[tl.style].pos)
				end
				
				-- 添加当前行
				table.insert(new_selected,tl.pos)
				-- 标识当前行为选择行
				limit_add[style_chace[tl.style].pos] = true

				if subs then
					-- 如果字幕对象存在，就应该整活了
					-- 每行起始时间不变，上一行结束时间向后调至紧贴下一行起始时间
					pre_line = subs[style_chace[tl.style].pos]
					line = subs[tl.pos]
					pre_line.end_time = line.start_time
					subs[style_chace[tl.style].pos] = pre_line
				end
				
			end
		end
		style_chace[tl.style] = tl
	end
	
	return new_selected
end

-- 叠轴、灵异轴检测，参数 subs_sort_arr(parse_sort函数返回值)
-- 返回值 新选择行
function check_overlap(subs_sort_arr,new_selected,basic_progress,add_progress)
	-- 无法自动修复，这种怪操作要挨锤的
	-- 缓存每个样式的前一行数据
	style_chace = {}
	-- 选择行
	if not new_selected then new_selected = {} end
	if not basic_progress then basic_progress = 30 end 
	if not add_progress then add_progress = 70 end 
	for i,tl in ipairs(subs_sort_arr) do
		aegisub.progress.set( i/#subs_sort_arr * add_progress + basic_progress)
		if style_chace[tl.style] then
			-- 同一样式 本行的开始时间小于上一行的结束时间 (单人这种轴太怪了，多人同一个样式也挺怪的)
			if tl.start_time < style_chace[tl.style].end_time then
				debug.println("叠轴检测：".."第"..tl.line_id.."行发现叠轴")
				table.insert(new_selected,tl.pos)
			end
			-- 一行的开始时间大于结束时间的畸形种
			if tl.start_time > tl.end_time then
				aegisub.debug.out(0, "叠轴检测：".."第"..tl.line_id.."行发现灵异轴") 
				table.insert(new_selected,tl.pos)
			end
		end
		style_chace[tl.style] = tl
	end
	return new_selected
end

-- 检测开始函数，正常规范三参数+检测限制参数
function check_start(subs, selected_lines, active_line, select_check)
	--复查助手

	select_check_def = {
		fix_fps = true,
		size = true,-- 尺寸异常检测
		error_char = true, -- 乱码字符检测
		style = true, -- 样式不存在检测
		overlap = true -- 叠轴检测
	}
	if not select_check then
		select_check = select_check_def
	end
	
	aegisub.progress.task('复 查 助 手')
	aegisub.progress.set(0)
	--[[
	if #subs > 10000 then
		debug.println('复查助手:检测到字幕行行数超过一万..')
		if not display.confirm('检测到行数超过一万行\n是否继续？\n继续运行，运行时间可能较长',1) then
			aegisub.progress.task0('复查助手运行结束')
			debug.println('自动复查:选择停止')
			aegisub.cancel()
		end
		debug.println('复查助手:继续运行...')
	end
	]]
	
	msg = [[小助手提醒您：
1.智能60FPS修复(视频已打开)(自动)
2.识别可能导致压制乱码的字符
3.识别单行字幕过长(视频已打开)
4.识别不存在的样式
5.同样式非注释行重叠
注：文件名也可能导致压制乱码，请自行检查
注：注释、说话人或特效不为空的行将被忽略
确定后开始自动复查！]]
	debug.println(msg..'\n')
	if not display.confirm(msg,1) then
		aegisub.progress.task('复查助手运行结束')
		debug.println('复查助手:选择停止')
		aegisub.cancel()
	end
	
	debug.println('复查助手:检查开始\n')
	aegisub.progress.set(1)
	-- 智能60FPS修复
	aegisub.progress.task('智能60FPS修复')
	debug.println('智能60FPS修复...')
	if select_check.fix_60fps ~= false then
		-- 判断前10s的帧数(视频需要至少10S长...)
		frame = aegisub.frame_from_ms(10000)
		if frame and frame >= 590 and frame <= 610 then
			debug.println('智能60FPS修复:'..'判断为60FPS')
			-- 这种情况就可以判定为60FPS了
			fix_60fps(subs)
		else
			debug.println('智能60FPS修复:'..'视频不为60FPS或视频未打开，跳过修复')
		end
	else
		debug.println('智能60FPS修复:'..'跳过修复')
	end

	aegisub.progress.set(5)
	--debug.println('智能60FPS修复执行完毕...')
	debug.println()
	
	
	-- 样式检测
	aegisub.progress.task('样式字体检测...')
	style_check,styles,meta,style_check_err_num,style_check_str = subs_check_style(subs)
	debug.println()
	
	aegisub.progress.set(10)
	-- 行错误检测
	aegisub.progress.task('行错误检测')
	debug.println('行错误检测...')
	new_selected,check_line_cout = subs_check_line(subs,styles,meta,select_check)
	--debug.println('行错误检测执行完毕...')
	
	aegisub.progress.set(90)
	aegisub.progress.task('叠轴检测')
	overlap_line_n = 0
	if select_check.overlap then
		-- 解析
		subs_sort_arr = parse_sort(subs,90,3)
		aegisub.progress.set(93)
		-- 检测行(更新选择)
		chace_ns = #new_selected
		new_selected = check_overlap(subs_sort_arr,new_selected,93,7)
		
		-- 叠轴行数
		overlap_line_n = #new_selected - chace_ns 
	end


	aegisub.progress.set(100)
	debug.println()
	aegisub.progress.task('复查助手运行结束')
	debug.println('====复查助手·统计====')
	if style_check or #new_selected ~= 0 or style_check_err_num ~= 0  then
		debug.println('？：这ASS怪怪的')
		debug.println('实际检测行:'..check_line_cout.check_line_total-check_line_cout.ignore_total)
		if Yutils then
			debug.println('字体未安装：'..style_check_err_num)
			if style_check_err_num ~= 0 then
				debug.println('未安装字体(所属样式)：'..style_check_str)
			end
		else
			debug.println('未安装字体检测：警告，未安装Yutils，检测无法运行。')
		end
		if select_check.overlap then
			if overlap_line_n ~= 0 then
				debug.println('！！！警告，当前叠轴行数不为0，建议仔细检查！！！')
			end
			debug.println('叠轴行数：'..overlap_line_n)
		end
		debug.println('异常对话行总数(不计叠轴)：'..check_line_cout.err_total)
		if check_line_cout.err_total ~= 0 then
			if select_check.size then
				debug.println('尺寸过大的行：'..check_line_cout.err_size)
			end
			if select_check.error_char then
				debug.println('存在可疑字符的行：'..check_line_cout.err_char)
			end
			if select_check.style then
				debug.println('使用不存在样式的行：'..check_line_cout.err_style)
				if check_line_cout.err_style ~= 0 then
					debug.println('不存在的样式：'..cout.err_styles_str)
				end
			end	
		end
		debug.println('所有检测到的异常行已经标记\n关闭窗口后显示标记结果')
	else
		debug.println('所有检测执行完毕')
		debug.println('总识别行:'..#subs)
		debug.println('总检测行:'..check_line_cout.check_line_total-check_line_cout.ignore_total)
		if not Yutils then
			debug.println('未安装字体检测：警告，未安装Yutils，检测无法运行。')
		end
		debug.println('特效不为空的行:'..check_line_cout.dialogue_effect_total)
		debug.println('忽略检测行总数:'..check_line_cout.ignore_total)
		debug.println('说话人不为空的行:'..check_line_cout.dialogue_actor_total)
		debug.println('这个ASS看起来没什么不对(')
	end
	
	
	if #new_selected == 0 then
		return 
	else
		return new_selected
	end
end



-- 菜单的选择启动函数

function macro_main(subs, selected_lines, active_line)
	-- 修改全局提示等级
	debug.changelevel(3)
	-- 默认全都检查
	return check_start(subs, selected_lines, active_line)
end

function macro_select_sizeover(subs, selected_lines, active_line)
	-- 你这行，太长了吧？
	-- 修改全局提示等级
	debug.changelevel(4)
	select_check = {
		size = true,-- 尺寸异常检测
		error_char = false, -- 乱码字符检测
		style = false, -- 样式不存在检测
		overlap = false -- 叠轴检测
	}
	-- 检查限制
	return check_start(subs, selected_lines, active_line, select_check)
end

function macro_select_errchar(subs, selected_lines, active_line)
	-- zai？为什么用特殊字符，还是这种特殊字符？
	-- 修改全局提示等级
	debug.changelevel(3)
	debug.println('乱码检测允许的特殊字符(常见特殊字符本机测试无害)：'..check_whilelist.."\n")
	select_check = {
		size = false,-- 尺寸异常检测
		error_char = true, -- 乱码字符检测
		style = false, -- 样式不存在检测
		overlap = false -- 叠轴检测
	}
	-- 检查限制
	return check_start(subs, selected_lines, active_line, select_check)
end

function macro_select_nullstyle(subs, selected_lines, active_line)
	-- 这样式咋空了
	-- 修改全局提示等级
	debug.changelevel(3)
	select_check = {
		size = false,-- 尺寸异常检测
		error_char = false, -- 乱码字符检测
		style = true, -- 样式不存在检测
		overlap = false -- 叠轴检测
	}
	-- 检查限制
	return check_start(subs, selected_lines, active_line, select_check)
end

function macro_select_basic(subs, selected_lines, active_line)
	-- 最基础的检查
	-- 修改全局提示等级
	debug.changelevel(3)
	select_check = {
		size = false,-- 尺寸异常检测
		error_char = false, -- 乱码字符检测
		style = false, -- 样式不存在检测
		overlap = false -- 叠轴检测
	}
	-- 检查限制
	return check_start(subs, selected_lines, active_line, select_check)
end

function macro_interval200(subs, selected_lines, active_line)
	-- 检查行间隔是否<200ms
	-- 修改全局提示等级
	debug.changelevel(4)
	-- 解析
	subs_sort_arr = parse_sort(subs)
	-- 判断行
	new_selected = check_interval200(subs_sort_arr)
	if #new_selected ~= 0 then
		return new_selected
	end
	display.confirm('未发现间隔小于200ms的行',0)
end

function macro_interval200_fix(subs, selected_lines, active_line)
	-- 检查行间隔是否<200ms
	-- 修改全局提示等级
	debug.changelevel(4)
	msg = '是否确认进行修复？'
	debug.println(msg..'\n')
	if not display.confirm(msg,1) then
		aegisub.progress.task('复查助手运行结束')
		debug.println('复查助手:选择停止')
		aegisub.cancel()
	end
	
	
	-- 解析
	subs_sort_arr = parse_sort(subs)
	-- 判断行
	new_selected = check_interval200(subs_sort_arr,subs)
	
	if #new_selected ~= 0 then
		return new_selected
	end
	display.confirm('未发现间隔小于200ms的行',0)
end

function macro_select_overlap(subs, selected_lines, active_line)
	aegisub.progress.task('复 查 助 手')
	-- 兄啊，同一个人说话怎么叠一起的？
	-- 修改全局提示等级
	debug.changelevel(3)
	msg = [[小助手提醒您：
1.智能60FPS修复(视频已打开)(自动)
2.识别可能导致压制乱码的字符
3.识别单行字幕过长(视频已打开)
4.识别不存在的样式
5.同样式非注释行重叠
注：文件名也可能导致压制乱码，请自行检查
注：注释、说话人或特效不为空的行将被忽略]]
	debug.println(msg..'\n')
	aegisub.progress.set(0)
	-- 解析
	subs_sort_arr = parse_sort(subs)
	aegisub.progress.set(30)
	-- 检测行
	new_selected = check_overlap(subs_sort_arr)
	aegisub.progress.set(100)
	debug.println()
	debug.println()
	debug.println('====复查助手·统计====')
	if #new_selected ~= 0 then
		debug.println('如无意外，此轴可锤')
		debug.println('叠轴计数：'..#new_selected)
		return new_selected
	end
	debug.println('看起来没有叠轴的存在呢')
	display.confirm('未发现可能存在的叠轴',0)
end

function macro_fix60fps(subs, selected_lines, active_line)
	debug.changelevel(4)
	fix_60fps(subs)
	display.confirm('我跟你说，它 好 了'.."\n"..'*此功能重复使用无影响',0)
end

local str_trim_expr_pre = re.compile([[^\s+]],re.NOSUB)
function macro_remove_headblank(subs)
	new_selected = {}
	for i=1,#subs do
		if subs[i].class == 'dialogue' then
			-- 解析忽略非对话行、空行(允许检测空行)、注释行、带特效标签的行、特效不为空的行
			expr = re.compile([[(\{[\s\S]+?\}){1}]],re.NOSUB)
			expr1 = re.compile([[[^\s]{1}]],re.NOSUB)
			line = subs[i]
			if line.class == 'dialogue' then
				if line.text ~= '' then
					result = expr:match(line.text)
					if not result and not line.comment and line.effect == '' then
						line.text, rep_count = str_trim_expr_pre:sub(line.text,'')
						if line.text ~= nil and line.text ~= subs[i].text then
							subs[i] = line
							table.insert(new_selected,i)
						end
					end
				end
			end
		end
	end
	if #new_selected ~= 0 then
		return new_selected
	end
	return out_str, rep_count
end

function macro_select_overtimes(subs)
	new_selected = {}
	for i=1,#subs do
		if subs[i].class == 'dialogue' then
			-- 解析忽略非对话行、空行(允许检测空行)、注释行、带特效标签的行、特效不为空的行
			expr = re.compile([[(\{[\s\S]+?\}){1}]],re.NOSUB)
			expr1 = re.compile([[[^\s]{1}]],re.NOSUB)
			line = subs[i]
			if line.class == 'dialogue' then
				if line.text ~= '' then
					result = expr:match(line.text)
					if not result and not line.comment and line.effect == '' then
						if subs[i].end_time - subs[i].start_time > 5000 then
							table.insert(new_selected,i)
						end
					end
				end
			end
		end
	end
	if #new_selected ~= 0 then
		return new_selected
	end
end

function macro_about()
	-- 修改全局提示等级
	debug.changelevel(1)
	version_log = [[
1.2.0 Alpha 2019-12-20
·更新了特殊符号检测算法，可以检测常用字符以外的符号。
·检测所有除了中日韩统一表意文字（CJK Unified Ideographs）之外的特殊字符。

1.3.0 Alpha
·修复了空轴无法检测闪轴的漏洞
·更新了压制特殊符号检测算法，采用白名单制，仅白名单字符可通过。
·注：白名单字符可通过自行编辑lua文件进行定义。
·增加了关于里更新日志的显示

1.3.1 Alpha
·增加两个小功能，移除每行行首空格，标记超过5S的轴

1.3.2 Alpha
·修复有一个功能没做的BUG

↑更新日志↑
]]
	msg = version_log.."\n\n"..'乱码检测允许的特殊字符：'..check_whilelist.."\n\n"..'复查小助手 '..script_version.."\n"..
[[
本助手的功能有
1.智能60FPS修复(视频已打开)(自动)
2.识别可能导致压制乱码的字符
3.识别单行字幕过长(视频已打开)
4.识别不存在的样式
5.同样式非注释行重叠以及包含
6.闪轴检测及修复(行间隔<200ms)
注：60FPS修复经过测试多次使用对ASS无负面影响
注：闪轴检测为独立功能，仅在菜单内提供，不自动使用，并且提供自动修复选项。
注：文件名也可能导致压制乱码，请自行检查
注：注释、说话人或特效不为空的行将被忽略
注：本助手的提示等级为level 3 如果不能正常显示信息或者其他异常请检查您的设置
注：本插件所做修改可由AEG的撤销功能撤回
作者：晨轩°(QQ3309003591)
本关于的最后修改时间：2020年1月20日
感谢您的使用！
]]
	debug.println(msg)
end




-- 注册AEG菜单

aegisub.register_macro(script_name, script_description, macro_main, macro_can_use)

aegisub.register_macro(script_name.."-菜单".."/基本检查", "查查更健康", macro_select_basic, macro_can_use)

aegisub.register_macro(script_name.."-菜单".."/独立检测/选择尺寸过大的行", "太长是不好的", macro_select_sizeover, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/独立检测/选择含可疑字符行", "可能引起压制错误的行", macro_select_errchar, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/独立检测/检测不存在的样式", "兄啊，你这有点不对劲啊", macro_select_nullstyle, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/独立检测/检测叠轴", "兄啊，同一个人说话怎么叠一起的？", macro_select_overlap, macro_can_use)

aegisub.register_macro(script_name.."-菜单".."/小工具/移除行首空格", "轴的空间还蛮大的", macro_remove_headblank, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/小工具/标记超过5s的轴", "轴的时间还蛮长的", macro_select_overtimes, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/检测字幕闪现(行间隔<200ms)", "这ass费眼睛", macro_interval200, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/修复字幕闪现(行间隔<200ms)", "它不会费眼睛了", macro_interval200_fix, macro_can_use)
aegisub.register_macro(script_name.."-菜单".."/60fps修复", "这个60FPS的视频看起来中暑了，不如我们...", macro_fix60fps, macro_can_use)





aegisub.register_macro(script_name.."-菜单".."/关于", "一些说明", macro_about, macro_can_use)