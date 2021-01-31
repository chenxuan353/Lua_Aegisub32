--[[
本脚本使用最基础的AEG函数装载
注：必须安装AEG辅助函数库方可正常运行
大致流程
1、测试函数库是否装载
2、如果使用自动装载，在未装载时测试权限
3、没有权限则提示使用管理员权限打开，若有权限则进行下一步
4、通过文件加载器加载指定文件到指定位置
注：如果不使用自动装载将提供打开文件夹的功能
]]
-- 脚本名
script_name = "AEG自动化辅助装载器"
-- 脚本描述
script_description = "用于辅助AEG插件、库、dll等文件的装载"
-- 作者
script_author = "晨轩°"

-- CX插件扩展值
-- 脚本签名(同一脚本签名请保持不变，签名不能含特殊字符，防止配置冲突)
script_signature = "com.chenxuan.辅助装载"
-- 版本号
script_version = "1.0.0dev"
-- 关于
script_about = [[
用于辅助AEG插件、库、dll等文件的装载
]]
-- 更新日志
script_ChangeLog = [[
没有日志~
]]

lfs = require("lfs")

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


-- 环境错误检测
local cx_help_libname = "CX_AEG插件辅助函数库"
local cx_help = nil
if (not pcall(
		function(libname)
			cx_help = require(cx_help_libname)
		end
		,cx_help_libname
	)) or cx_help == nil 
then
	local function errLoadLibDealFunc(subs)
		local function print(msg)
			aegisub.debug.out(0, msg)
		end
		if cx_help ~= nil then
			cx_help.alert("辅助库已安装\n请重新载入脚本或重启Aegisub使改动生效")
			return
		end
		filename = select_file("选择CX_AEG插件辅助函数库文件","lua(*.lua)|*.lua")
		if filename == nil or filename == "" then
			print("未选择合法文件")
			return
		end
		print("已确认库文件路径："..filename.."\n")
		print("正在检测脚本合法性...\n")
		-- 备份原始档案，覆盖环境执行测试
		local cachepath = package.path
		local cache_aeg = aegisub
		local cache_aegmin = aeg
		local supertable = {}
		--[[
		setmetatable(supertable,{
			__index = function(mytable, key)
				return mytable
			end
			,__newindex = function(mytable, key, value)
				return
			end
			,__call = function(mytable, newtable)
				return mytable
			end
		})
		]]
		if pcall(
			function(filename)
				-- 测试加载文件
				local fi = string.find(string.reverse(filename),"\\")
				package.path = package.path..";"..string.sub(filename,0,-fi).."/?.lua"
				local modname = string.sub(string.sub(filename,-fi + 1),0,-5)
				local testload = require(modname)
				assert(testload.aeg.exit == aegisub.cancel,"非法的辅助库文件")
			end, filename)
		then
			_G.aegisub = cache_aeg
			_G.aeg = cache_aegmin
			package.path = cachepath
			print(">>>脚本测试通过<<<\n")
		else
			_G.aegisub = cache_aeg
			_G.aeg = cache_aegmin
			package.path = cachepath
			print("!!!脚本测试不通过，无法执行安装!!!\n")
			return
		end
		libpath = aegisub.decode_path('?data\\').."automation\\include\\"
		print("安装路径："..libpath.."\n")
		print("尝试安装...\n")
		if pcall(copyFile,filename,libpath..cx_help_libname..".lua")
		then
			print(">>>安装成功！<<<\n")
		else
			print("!!!脚本安装失败，可能权限不足，请尝试管理员权限打开Aegisub!!!\n")
			return
		end
		if (not pcall(
				function(libname)
					cx_help = require(cx_help_libname)
				end
				,cx_help_libname
			)) or cx_help == nil 
		then
			print("!!!未知原因错误，无法载入库文件!!!")
			return
		end
		print("函数辅助库文件加载成功！请重新加载脚本或者重启Aegisub以应用修改\n")
		cx_help.alert("安装完成，欢迎使用！")
	end
	aegisub.register_macro("自动装载 - 未初始化","装载器未初始化完成",errLoadLibDealFunc)
	
	
	-- 未成功加载库的返回
	return
end



-- 创建合适的函数环境
cx_help.table.merge(_G,cx_help)
setting.setLevel(0)
function file_exists(path)
	local file = io.open(path, "rb")
	if file then file:close() end
	return file ~= nil
end
function loadlib()
	filename = select_file("选择库文件","lua(*.lua)|*.lua")
	if filename == nil or filename == "" then
		return
	end
	local fi = string.find(string.reverse(filename),"\\")
	
	if not confirm("你确定要安装 "..string.sub(string.sub(filename,-fi + 1),0,-5).." 吗？") then
		return
	end
	print("已确认库文件路径："..filename.."\n")
	print("正在测试脚本合法性...\n")
	-- 备份原始档案，覆盖环境执行测试
	local cachepath = package.path
	local cache_aeg = aegisub
	local cache_aegmin = aeg
	local supertable = {}
	--[[
	setmetatable(supertable,{
		__index = function(mytable, key)
			return mytable
		end
		,__newindex = function(mytable, key, value)
			return
		end
		,__call = function(mytable, newtable)
			return mytable
		end
	})
	]]
	_G.aegisub = supertable
	_G.aeg = supertable
	cx_help.aeg = supertable
	if pcall(
		function(filename)
			-- 测试加载文件
			local fi = string.find(string.reverse(filename),"\\")
			package.path = package.path..";"..string.sub(filename,0,-fi).."/?.lua"
			local modname = string.sub(string.sub(filename,-fi + 1),0,-5)
			local testload = require(modname)
		end, filename)
	then
		_G.aegisub = cache_aeg
		_G.aeg = cache_aegmin
		cx_help.aeg = cache_aegmin
		package.path = cachepath
		print(">>>脚本测试通过<<<\n")
	else
		_G.aegisub = cache_aeg
		_G.aeg = cache_aegmin
		cx_help.aeg = cache_aegmin
		package.path = cachepath
		print("!!!脚本测试不通过，无法执行安装!!!\n")
		return
	end
	
	libpath = aeg.path.global_lib
	print("安装路径："..libpath.."\n")
	print("尝试安装...\n")
	
	local targetPath = libpath..string.sub(filename,-fi + 1)
	if file_exists(targetPath) then
		if not confirm("文件已存在，是否覆盖？") then
			print("已取消安装...\n")
			return
		end
	end
	if pcall(copyFile,filename,targetPath)
	then
		print(">>>安装成功！<<<\n")
	else
		print("!!!脚本安装失败，可能权限不足，请尝试管理员权限打开Aegisub!!!\n")
		return
	end
	print("请重新加载脚本或者重启Aegisub以应用修改\n")
end

function os_openpath(path)
	os.execute("explorer "..path)
end

-- 无错误导入(参数 库名)，出错返回nil
function noerrRequire(libname)
	local res = nil
	pcall(
		function (reqname)
			-- 测试加载文件
			res = require(reqname)
		end, libname)
	return res
end

-- 载入测试
local Yutils = noerrRequire("Yutils")

-- 环境检测菜单
envTestMenu = {
	menus.menu("辅助函数库",nil,function() end,nil,function () return true end)
	,menus.menu("Yutils",nil,function() end,nil,function () return Yutils ~= nil end)
	
}

function loadscript()
	filename = select_file("选择脚本文件","lua(*.lua)|*.lua")
	if filename == nil or filename == "" then
		return
	end
	local fi = string.find(string.reverse(filename),"\\")
	if not confirm("你确定要安装 "..string.sub(string.sub(filename,-fi + 1),0,-5).." 吗？") then
		return
	end
	print("已确认脚本文件路径："..filename.."\n")
	
	libpath = aeg.path.global_script
	print("安装路径："..libpath.."\n")
	print("尝试安装...\n")
	
	local targetPath = libpath..string.sub(filename,-fi + 1)
	if file_exists(targetPath) then
		if not confirm("文件已存在，是否覆盖？") then
			print("已取消安装...\n")
			return
		end
	end
	if pcall(copyFile,filename,targetPath)
	then
		print(">>>安装成功！<<<\n")
	else
		print("!!!脚本安装失败，可能权限不足，请尝试管理员权限打开Aegisub!!!\n")
		return
	end
end

function removelib()
	-- 遍历脚本目录
	local scriptpath = aeg.path.global_lib
	local llist = {}
	for path in lfs.dir(scriptpath) do
		if string.sub(path,-4) == ".lua" then
			local unit = string.sub(path,0,-5)
			table.insert(llist,unit)
		end
	end
	config = {
		{class="label",label ="库列表",x=0,y=0,width = 5,height = 1}
		,{class = "dropdown",value = "",items = llist,name = "dr",hint="选择需要卸载的插件",x=0,y=1,width = 5,height = 1}
	}
	-- 显示对话框
	btn, btnresult = aegisub.dialog.display(config)
	removename = btnresult.dr
	if btn == false or removename == "" then
		return
	end
	if not confirm("你确定要删除 "..removename.." 吗？") then
		return
	end
	filepath = aeg.path.global_lib..removename..".lua"
	--DD("删除路径：",filepath)
	--DD("文件存在性检测：",file_exists(filepath))
	res,err = os.remove(filepath)
	if res == nil then
		println("删除失败，可能权限不足，请尝试管理员权限打开Aegisub")
		println("错误原文：",err)
		return
	end
	alert("删除成功")
end
function removescript()
	-- 遍历脚本目录
	local scriptpath = aeg.path.global_script
	local slist = {}
	for path in lfs.dir(scriptpath) do
		if string.sub(path,-4) == ".lua" then
			local unit = string.sub(path,0,-5)
			table.insert(slist,unit)
		end
	end
	config = {
		{class="label",label ="自动化脚本列表",x=0,y=0,width = 5,height = 1}
		,{class = "dropdown",value = "",items = slist,name = "dr",hint="选择需要卸载的插件",x=0,y=1,width = 5,height = 1}
	}
	-- 显示对话框
	btn, btnresult = aegisub.dialog.display(config)
	removename = btnresult.dr
	if btn == false or removename == "" then
		return
	end
	if not confirm("你确定要删除 "..removename.." 吗？") then
		return
	end
	filepath = aeg.path.global_script..removename..".lua"
	--DD("删除路径：",filepath)
	--DD("文件存在性检测：",file_exists(filepath))
	res,err = os.remove(filepath)
	if res == nil then
		println("删除失败，可能权限不足，请尝试管理员权限打开Aegisub")
		println("错误原文：",err)
		return
	end
	alert("删除成功")
end


-- 菜单结构
varmenu = {
	menus.next("当前已安装环境"
		,envTestMenu
	)
	,menus.next("打开AEG目录"
		,{
			menus.menu("根目录",nil,function() os_openpath(aeg.path.data) end,nil,nil)
			,menus.menu("脚本目录",nil,function() os_openpath(aeg.path.global_script) end,nil,nil)
			,menus.menu("库目录",nil,function() os_openpath(aeg.path.global_lib) end,nil,nil)
			,menus.menu("滤镜目录(DLL)",nil,function() os_openpath(aeg.path.data.."csri\\") end,nil,nil)
			,menus.menu("自动保存目录",nil,function() os_openpath(aeg.path.autosave) end,nil,nil)
			,menus.menu("自动备份目录",nil,function() os_openpath(aeg.path.autoback) end,nil,nil)
			,menus.menu("辅助函数库配置文件目录",nil,function() os_openpath(aeg.path.config) end,nil,nil)
		}
	)
	,menus.menu("加载库",nil,loadlib,nil,nil)
	,menus.menu("卸载库",nil,removelib,nil,nil)
	,menus.menu("安装自动化脚本(全局)",nil,loadscript,nil,nil)
	,menus.menu("卸载自动化脚本(全局)",nil,removescript,nil,nil)
	,menus.about()
}

-- 应用菜单设置
tools.automenu("自动装载",varmenu)
















