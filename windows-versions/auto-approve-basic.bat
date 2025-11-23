@echo off
REM Claude Code 基础安全审批脚本 - Windows版本
REM 功能：自动审批安全的只读操作，对写操作和命令进行安全检查

setlocal enabledelayedexpansion

REM 读取标准输入的JSON数据
set "input="
for /f "delims=" %%i in ('more') do set "input=!input!%%i"

REM 需要安装 jq 工具，或者使用 PowerShell 解析 JSON
REM 这里使用 PowerShell 进行 JSON 解析

for /f "delims=" %%i in ('powershell -Command "
$input = '%input:'=''%'
$json = $input | ConvertFrom-Json
$tool_name = $json.tool_name
$tool_input = $json.tool_input | ConvertTo-Json -Compress
Write-Output \"$tool_name\"
"') do set "tool_name=%%i"

REM 自动批准安全的只读操作
echo %tool_name% | findstr /i "ls pwd echo cat grep find which head tail wc" >nul
if %errorlevel% equ 0 (
    echo {"decision": "approve"}
    exit /b 0
)

REM Write 操作 - 基于文件路径判断
if "%tool_name%"=="Write" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $file_path = $json.tool_input.file_path
    Write-Output \"$file_path\"
    "') do set "file_path=%%i"

    REM 自动批准临时文件
    echo %file_path% | findstr /i "^C:\\temp\\ \.tmp$ /temp/ \.tmp$" >nul
    if %errorlevel% equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )

    REM 自动批准日志文件
    echo %file_path% | findstr /i "\.log$ /log/ /logs/" >nul
    if %errorlevel% equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )

    REM 自动批准构建输出
    echo %file_path% | findstr /i "/build/ /dist/ /target/ /output/" >nul
    if %errorlevel% equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM Bash 命令 - 基于命令内容判断
if "%tool_name%"=="Bash" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $command = $json.tool_input.command
    Write-Output \"$command\"
    "') do set "command=%%i"

    REM 拒绝危险命令
    echo %command% | findstr /i "rm -rf chmod 777 curl.*sh wget.*sh \u003e /dev/null dd if=" >nul
    if %errorlevel% equ 0 (
        echo {"decision": "deny"}
        exit /b 0
    )

    REM 批准安全命令
    echo %command% | findstr /i "^ls ^pwd ^echo ^date ^whoami ^which ^npm install ^pip install ^yarn install" >nul
    if %errorlevel% equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM Edit 操作 - 相对谨慎
if "%tool_name%"=="Edit" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $file_path = $json.tool_input.file_path
    Write-Output \"$file_path\"
    "') do set "file_path=%%i"

    REM 只允许编辑特定类型的文件
    echo %file_path% | findstr /i "\.txt$ \.md$ \.json$ \.yaml$ \.yml$ \.conf$ \.config$" >nul
    if %errorlevel% equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM 默认继续（弹出确认对话框）
echo {"continue": true}
exit /b 0