-- math-to-svg-md.lua
-- Markdown LaTeX math -> SVG image links
--
-- 工作方式：
--   1. Pandoc 识别 Markdown 中的 $...$ / $$...$$ 公式；
--   2. Lua filter 把每个公式用 xelatex 编译成 .xdv；
--   3. dvisvgm 把 .xdv 转成 .svg；
--   4. Markdown 中公式替换为 ![formula](math-svg/xxx.svg)；
--   5. SVG 先生成到英文临时目录，由 bat 文件复制到最终 math-svg 目录。
--
-- 注意：
--   本 Lua 只负责生成 SVG 到 build_root，不负责复制到最终目录。
--   复制和删除临时目录交给 run-typora-mathsvg.bat 做。

-- 必须是纯英文路径，避免 TeX 工具链在 Windows 下处理中文路径出错
local build_root = "D:/Projects/pandoc_docx_template/.math-svg-build"

-- Markdown 输出中引用的 SVG 相对目录
-- 最终 bat 会把 SVG 复制到导出 Markdown 同级的 math-svg/
local final_svg_dir_rel = "math-svg"

local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function normalize_path(path)
  return tostring(path or ""):gsub("\\", "/")
end

local function windows_path(path)
  return tostring(path or ""):gsub("/", "\\")
end

local function ensure_dir(path)
  path = normalize_path(path)

  if path == "" then
    return
  end

  if is_windows() then
    local p = windows_path(path)
    os.execute('cmd /C if not exist "' .. p .. '" mkdir "' .. p .. '"')
  else
    os.execute('mkdir -p "' .. path .. '"')
  end
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local function write_file(path, text)
  local f = assert(io.open(path, "w"))
  f:write(text)
  f:close()
end

local function clean_math_text(s)
  s = tostring(s or "")

  -- 统一换行符
  s = s:gsub("\r\n", "\n")
  s = s:gsub("\r", "\n")

  -- 去掉公式前后的空白和空行
  -- 防止 LaTeX 在 \[...\] 内遇到空段落时报 Missing $ inserted
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")

  return s
end

build_root = normalize_path(build_root)
ensure_dir(build_root)

-- 使用 xelatex + xeCJK，支持公式里的中文：
--   \text{风光互补}
--   \text{纯风}
--   \text{纯光}
--
-- 字体优先 Microsoft YaHei；没有则回退 SimSun。
local latex_preamble = [[
\documentclass[preview,border=2pt]{standalone}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{mathtools}
\usepackage{bm}
\usepackage{mathrsfs}
\usepackage{cancel}
\usepackage{fontspec}
\usepackage{xeCJK}
\IfFontExistsTF{Microsoft YaHei}
  {\setCJKmainfont{Microsoft YaHei}}
  {\setCJKmainfont{SimSun}}
\begin{document}
]]

local latex_end = [[
\end{document}
]]

function Math(el)
  ensure_dir(build_root)

  local math_text = clean_math_text(el.text)

  if math_text == "" then
    return pandoc.Str("")
  end

  local key = pandoc.utils.sha1(el.mathtype .. ":" .. math_text)

  local build_tex = normalize_path(build_root .. "/" .. key .. ".tex")
  local build_xdv = normalize_path(build_root .. "/" .. key .. ".xdv")
  local build_svg = normalize_path(build_root .. "/" .. key .. ".svg")

  -- Markdown 中最终写入的图片路径。
  -- bat 会把 build_root/*.svg 复制到输出 md 同级的 math-svg/
  local final_svg_href = normalize_path(final_svg_dir_rel .. "/" .. key .. ".svg")

  if not file_exists(build_svg) then
    local math_body

    if el.mathtype == "InlineMath" then
      math_body = "\\(" .. math_text .. "\\)"
    else
      -- 不在公式前后额外插入空行，避免 Missing $ inserted
      math_body = "\\[" .. math_text .. "\\]"
    end

    local tex = latex_preamble .. "\n" .. math_body .. "\n" .. latex_end

    write_file(build_tex, tex)

    -- 用 xelatex 生成 .xdv，而不是用 latex 生成 .dvi。
    -- xelatex 可以处理中文。
    local ok_latex, latex_result = pcall(function()
      return pandoc.pipe("xelatex", {
        "-interaction=nonstopmode",
        "-halt-on-error",
        "-no-pdf",
        "-output-directory=" .. build_root,
        build_tex
      }, "")
    end)

    if not ok_latex then
      error(
        "\nXeLaTeX 公式编译失败。\n" ..
        "临时目录: " .. build_root .. "\n" ..
        "临时文件: " .. build_tex .. "\n" ..
        "公式内容:\n" .. math_text .. "\n\n" ..
        "XeLaTeX 错误信息:\n" .. tostring(latex_result)
      )
    end

    -- dvisvgm 可以直接把 xelatex 生成的 .xdv 转成 SVG
    local ok_svg, svg_result = pcall(function()
      return pandoc.pipe("dvisvgm", {
        "--no-fonts",
        "--exact-bbox",
        build_xdv,
        "-o",
        build_svg
      }, "")
    end)

    if not ok_svg then
      error(
        "\ndvisvgm 转 SVG 失败。\n" ..
        "XDV 文件: " .. build_xdv .. "\n" ..
        "目标 SVG: " .. build_svg .. "\n" ..
        "公式内容:\n" .. math_text .. "\n\n" ..
        "dvisvgm 错误信息:\n" .. tostring(svg_result)
      )
    end
  end

  return pandoc.Image({ pandoc.Str("formula") }, final_svg_href)
end