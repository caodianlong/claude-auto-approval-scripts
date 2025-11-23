@echo off
REM Claude Code 智能上下文感知审批脚本 - Windows版本
setlocal enabledelayedexpansion

REM 读取输入
set "input="
for /f "delims=" %%i in ('more') do set "input=!input!%%i"

REM 解析JSON数据
for /f "delims=" %%i in ('powershell -Command "
$input = '%input:'=''%'
$json = $input | ConvertFrom-Json
$tool_name = $json.tool_name
$project_root = $json.context.project_root
Write-Output \"$tool_name|$project_root\"
"') do (
    for /f "tokens=1,2 delims=|" %%a in ("%%i") do (
        set "tool_name=%%a"
        set "project_root=%%b"
    )
)

REM Write 操作智能审批
if "%tool_name%"=="Write" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $file_path = $json.tool_input.file_path
    Write-Output \"$file_path\"
    "') do set "file_path=%%i"

    REM 自动批准临时文件
    echo %file_path% | findstr /i "^C:\\temp\\ \.tmp$ \\temp\\ \.cache$" >nul
    if !errorlevel! equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )

    REM 自动批准日志文件
    echo %file_path% | findstr /i "\.log$ \logs\ \log\ \debug\ \.cache$" >nul
    if !errorlevel! equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )

    REM 自动批准构建输出
    echo %file_path% | findstr /i "\build\ \dist\ \target\ \output\ \out\ \bin\obj\" >nul
    if !errorlevel! equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )

    REM 基于扩展名的判断
    for /f "delims=" %%i in ('powershell -Command "
    $file_path = '%file_path%'
    $extension = [System.IO.Path]::GetExtension($file_path).ToLower()
    Write-Output \"$extension\"
    "') do set "file_ext=%%i"

    if "%file_ext%"==".tmp" (
        echo {"decision": "approve"}
        exit /b 0
    )
    if "%file_ext%"==".log" (
        echo {"decision": "approve"}
        exit /b 0
    )
    if "%file_ext%"==".cache" (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM Bash 命令智能审批
if "%tool_name%"=="Bash" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $command = $json.tool_input.command
    Write-Output \"$command\"
    "') do set "command=%%i"

    REM 拒绝危险命令
    echo %command% | findstr /i "rm -rf chmod 777 curl.*sh wget.*sh dd if= mkfs fdisk" >nul
    if !errorlevel! equ 0 (
        echo {"decision": "deny"}
        exit /b 0
    )

    REM 基于项目类型的审批
    if exist "%project_root%\package.json" (
        echo %command% | findstr /i "^npm install ^npm list ^npm audit ^yarn install ^yarn list ^yarn audit" >nul
        if !errorlevel! equ 0 (
            echo {"decision": "approve"}
            exit /b 0
        )
    )

    if exist "%project_root%\requirements.txt" (
        echo %command% | findstr /i "^pip install ^pip list ^pip show ^pip freeze" >nul
        if !errorlevel! equ 0 (
            echo {"decision": "approve"}
            exit /b 0
        )
    )

    REM 批准安全系统命令
    echo %command% | findstr /i "^ls ^pwd ^echo ^date ^whoami ^which ^cd ^ls " >nul
    if !errorlevel! equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM Edit 操作
if "%tool_name%"=="Edit" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $file_path = $json.tool_input.file_path
    Write-Output \"$file_path\"
    "') do set "file_path=%%i"

    REM 只允许编辑安全的配置文件
    echo %file_path% | findstr /i "\.md$ \.txt$ \.json$ \.yaml$ \.yml$ \.conf$ \.config$ \.ini$ \.xml$ \.toml$" >nul
    if !errorlevel! equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM Delete 操作
if "%tool_name%"=="Delete" (
    for /f "delims=" %%i in ('powershell -Command "
    $input = '%input:'=''%'
    $json = $input | ConvertFrom-Json
    $file_path = $json.tool_input.file_path
    Write-Output \"$file_path\"
    "') do set "file_path=%%i"

    REM 只允许删除临时文件
    echo %file_path% | findstr /i "^C:\\temp\\ \.tmp$ \.log$ \cache\\ \temp\\" >nul
    if !errorlevel! equ 0 (
        echo {"decision": "approve"}
        exit /b 0
    )
)

REM 默认需要确认
echo {"continue": true}
exit /b 0