@echo off

:: 调用方式  "D:\Projects\pandoc_docx_template\scripts\ym_md2docx.bat" "D:\test\input.md" "D:\test\output.docx"
:: Typora命令示例：
:: "D:\Projects\pandoc_docx_template\scripts\ym_md2docx.bat" "${currentPath}" "${outputPath}"

if "%~1"=="" (
    echo 请传入第一个参数：Markdown 文件路径
    exit /b 1
)

if "%~2"=="" (
    echo 请传入第二个参数：输出 docx 路径
    exit /b 1
)

set "currentPath=%~1"
set "outputPath=%~2"

:: bat脚本所在目录
set "scriptDir=%~dp0"

:: 在原 md 同目录生成临时修复版 md
:: 注意：放在同目录是为了避免图片相对路径失效
set "fixedMd=%~dpn1.__pandoc_fixed__.md"

:: python预处理修复 $...$ 内侧首尾空格
python "%scriptDir%..\pyscripts\fix-inline-math-space.py" "%currentPath%" "%fixedMd%"

pandoc "%fixedMd%" -f markdown+implicit_figures+pipe_tables+tex_math_dollars -s -t docx ^
    --reference-doc "%scriptDir%..\实验报告转模板.docx" -o "%outputPath%" ^
    --lua-filter="%scriptDir%..\lua\markdown-to-docx.lua"

:: 删除临时 md
if exist "%fixedMd%" del "%fixedMd%"

:: python后处理修复三线表
python "%scriptDir%..\pyscripts\fix-three-line-tables.py" "%outputPath%"