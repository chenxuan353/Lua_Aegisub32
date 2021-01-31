-- 辅助支持表
local cx_help = require"CX_AEG插件辅助函数库"
-- 创建合适的函数环境
cx_help.table.merge(_G,cx_help)

-- 脚本名
script_name = "函数库示例"
-- 脚本描述
script_description = "用于示例函数库功能"
-- 作者
script_author = "晨轩°"

-- CX插件扩展值
-- 脚本签名(同一脚本签名请保持不变，签名不能含特殊字符，防止配置冲突)
script_signature = "com.chenxuan.核心测试"
-- 版本号
script_version = "1.0.0dev"
-- 关于
script_about = [[
这个脚本是AEG插件辅助函数库的例程
]]
-- 更新日志
script_ChangeLog = [[
没有日志~
]]


-- 设置默认输出等级(不设置则默认为3)
setting.setLevel(1)

--[[
	辅助函数库示例函数
]]

-- 快捷菜单设置例程
-- 设置的值会随着用户的操作而变化(绑定表会同步这个变化，文件也会)
checkbind = {
	["多选A"] = true -- 多选菜单的默认值，加载后会优先读取文件中的缓存
	,["多选B"] = false
	,["多选C"] = true
}
-- tools.checkboxMenu("AEG插件辅助函数库示例","多选测试",checkbind)
radiobind = {
	now = "第一个选择" -- 当前选择的键，会优先读取文件中的缓存
	,["第一个选择"] = "选择的隐藏值，可用于标识选择"
	,["第二个选择"] = 2
	,["第三个选择"]= 3
}
-- tools.radioMenu("AEG插件辅助函数库示例","单选测试",radiobind)


-- 快速定义菜单结构
des = "测试菜单生成"
processing = function () alert("你点击了菜单") end
validation = nil
is_active = nil

-- 菜单结构
varmenu = {
	menus.next(
		"多级菜单设置"
		,{
			-- 更多级菜单
			menus.next("再来一级"
				,{
					menus.menu("A",nil,processing,validation,is_active)
					,menus.menu("B",nil,processing,validation,is_active)
					,menus.menu("C",nil,processing)
				}
			)
			,menus.menu("普通菜单",des,processing,validation,is_active)
			,menus.checkbox("多选",checkbind)
			,menus.radio("单选",radiobind)
			,menus.about()
		}
		-- 本体菜单
		,tools.menus.menu("",des,processing,validation,is_active)
	)
}
-- 应用菜单设置
tools.automenu("AEG插件辅助函数库示例",varmenu)

-- 全局环境覆盖
function testDefault(subtitles, selected_lines, active_line)
	print("基础函数示例\n")
	-- 基本函数
	println("带LN的函数自带换行")
	println("以下是万能输出函数：")
	vprintln("字幕对象：",subtitles)
	DD("当前选择行列表：",selected_lines)
	DD("当前激活行：",active_line)
	println("表合并：",table.merge({a = "233"},{b = "666"}))
	
	-- 弹出窗口示例
	println("仿照JavaScript设计的窗口弹出")
	alert("这里是提醒框")
	b = confirm("那么，你要选择哪里呢？")
	if b then b = "确认" else b = "取消" end
	
	val = prompt("你选择了 "..b.." 请随意输入~")
	if val == nil then val = "nil -- 没有任何输入" end
	alert("你输入了："..val)
	-- input与prompt是同一个函数
	-- inputInt 仅允许输入整数
	val = inputInt("你选择了 "..b.." 请随意输入~")
	if val == nil then val = "nil -- 没有任何输入" end
	alert("你输入了："..tostring(val))
	-- inputFloat 仅允许输入小数
	val = inputFloat("你选择了 "..b.." 请随意输入~")
	if val == nil then val = "nil -- 没有任何输入" end
	alert("你输入了："..tostring(val))
	
	
	exit() -- 结束脚本执行
	print("理论上这里不会被执行")
end
aeg.regMacro("AEG插件辅助函数库示例/基础函数示例","用于示例的脚本",testDefault)

-- AEG简化及辅助函数
function testAeg(subtitles, selected_lines, active_line)
	print("AEG辅助示例\n")
	-- 等待AEG响应，同时判断是否取消执行，用户取消执行将结束脚本，参数为结束运行钩子函数
	aeg.waitAeg() -- 调用aegisub.progress.is_cancelled判断
	-- 简化的输出函数
	
	aeg.levelout(0,"最高等级输出\n")
	
	aeg.standout("默认等级输出\n")
	
	--[[
		-- 源码示例
		aeg.regMacro = aegisub.register_macro
		aeg.regFilter = aegisub.register_filter
		aeg.setTitle = aegisub.progress.title
		aeg.setProgress = aegisub.progress.set
		aeg.setTask = aegisub.progress.task
		aeg.cancelled = aegisub.progress.is_cancelled
	]]
	-- path
	println("path键：")
	DD("配置路径：",aeg.path.config)
	DD("应用数据目录(AEG安装目录)：",aeg.path.data)
	DD("用户数据目录(配置与自动备份)：",aeg.path.user)
	DD("临时文件目录：",aeg.path.temp)
	DD("本地用户设置路径：",aeg.path.cache) -- 也可以使用aeg.path['local']
	DD("字幕路径：",aeg.path.script)
	DD("视频路径：",aeg.path.video)
	DD("音频路径：",aeg.path.audio)
	-- 设置还原点
	line = subtitles[#subtitles]
	line.text = "可在 菜单->编辑 里观测到还原点名称"
	subtitles.append(line)
	aeg.setUndo("还原描述")
end
aeg.regMacro("AEG插件辅助函数库示例/AEG简化与辅助示例","用于示例的脚本",testAeg)

-- 工具集示例
function testTools(subtitles, selected_lines, active_line)
	print("工具集示例\n")
	--[[
		读写配置基于 aeg.path.config 路径
		需要 配置script_signature(脚本签名) 或者 主动提供签名 才能使用
		配置读写的键和值请使用纯文本，不支持文本以外的类型
	]]
	
	-- 读配置
	ini = tools.readConfig()
	DD("测试读取：",ini)
	-- 写配置
	wini = {}
	wini.nice = "ohhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh"
	wini.test = input("测试写入配置，随便写些什么吧")
	
	DD("写入内容：",wini)
	tools.saveConfig(wini)
	ini = tools.readConfig()
	DD("读取结果：",ini)
	
	-- 读写指定配置
	DD("读指定配置：","test","=",tools.getConfig("test"))
	tools.setConfig("test","覆盖~")
	DD("写指定配置：","test","=","覆盖~")
	DD("读指定配置：","test","=",tools.getConfig("test"))
	
	
	-- 序列化与反序列化(可以将table转为纯文本)
	ser = tools.serialize(ini)
	DD("序列化示例：",ser)
	res = tools.unserialize(ser)
	DD("反序列化示例：",res)
end
aeg.regMacro("AEG插件辅助函数库示例/工具集示例","用于示例的脚本",testTools)


-- 关闭配置写入
aeg.regMacro("AEG插件辅助函数库示例/关闭配置写入","用于示例的脚本"
	,function() 
		setting.setCloseConfigWrite(not setting.getCloseConfigWrite()) 
	end
	,nil
	,function() 
		return setting.getCloseConfigWrite() 
	end
)
-- 清空配置
aeg.regMacro("AEG插件辅助函数库示例/清空配置示例","用于示例的脚本"
	,function() tools.clearConfig() end
)


-- 字幕辅助
function testSubsTools(subs, selected_lines, active_line)
	print("字幕辅助示例\n")
	--[[
		字幕对象代理还原了字幕对象的操作，并重定向各类操作的起止位置
		注意事项：
			迭代需要使用专用迭代器
	]]
	-- 获取字幕对象代理
	proxysubs = subsTool.presubs(subs)
	println("总行数：",proxysubs.n)
	println("信息行数：",proxysubs.i_n)
	println("样式行数：",proxysubs.sn)
	println("对话行数：",proxysubs.dn)
	DD("信息收集表：")
	for i,line in proxysubs.InfosIter do
		DD({i = i,line = line})
	end
	DD("样式收集表：")
	for i,line in proxysubs.StylesIter do
		DD({i = i,line = line})
	end
	DD("对话行迭代：")
	for i,line in proxysubs.DialogueIter do
		println(line.raw)
	end
	
	-- 设置行
	line = proxysubs[1]
	line.text = "呜呜呜"
	proxysubs[1] = line
	-- 插入行
	for i = 1,5 do
		line.text = "插入行 - "..tostring(i)
		proxysubs.insert(1 ,line)
	end
	line.text = "插入完成~"
	proxysubs.append(line)
	-- 删除行
	--[[5,X4,X3,2,X1]]
	proxysubs.deleterange(2,3) -- 删除 4,3
	proxysubs.delete(3) -- 删除 1
	
end
aeg.regMacro("AEG插件辅助函数库示例/字幕辅助示例","用于示例的脚本",testSubsTools)

-- 字幕信息
function testSubsTools_disonly(subs, selected_lines, active_line)
	print("字幕辅助示例\n")
	--[[
		字幕对象代理还原了字幕对象的操作，并重定向各类操作的起止位置
		注意事项：
			迭代需要使用专用迭代器
	]]
	-- 获取字幕对象代理
	proxysubs = subsTool.presubs(subs)
	println("总行数：",proxysubs.n)
	println("信息行数：",proxysubs.i_n)
	println("样式行数：",proxysubs.sn)
	println("对话行数：",proxysubs.dn)
	DD("信息收集表：")
	for i,line in proxysubs.InfosIter do
		DD({i = i,line = line})
	end
	DD("样式收集表：")
	for i,line in proxysubs.StylesIter do
		DD({i = i,line = line})
	end
	DD("对话行迭代：")
	for i,line in proxysubs.DialogueIter do
		println(line.raw)
	end
end
aeg.regMacro("AEG插件辅助函数库示例/字幕信息收集","用于示例的脚本",testSubsTools_disonly)


tools.applymenu("","AEG插件辅助函数库示例",menus.about())-- 创建关于菜单
