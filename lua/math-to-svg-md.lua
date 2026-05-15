-- math-to-svg-md.lua
-- 用途：
--   将 Markdown 中的 LaTeX 公式转换为本地 SVG 图片，
--   并在导出的 Markdown 中把公式替换为图片引用。
--
-- Typora 自定义命令示例：
--   pandoc "${currentPath}" -f markdown+tex_math_dollars+tex_math_single_backslash+latex_macros --lua-filter="D:/Projects/pandoc_docx_template/lua/math-to-svg-md.lua" -t gfm --wrap=none -o "${outputPath}"

local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function normalize_path(path)
  return tostring(path):gsub("\\", "/")
end

local function dirname(path)
  path = normalize_path(path)
  local dir = path:match("^(.*)/[^/]*$")
  if dir == nil or dir == "" then
    return "."
  end
  return dir
end

local function basename_no_ext(path)
  path = normalize_path(path)
  local name = path:match("([^/]+)$") or path
  name = name:gsub("%.[^.]*$", "")
  if name == "" then
    return "output"
  end
  return name
end

local function ensure_dir(path)
  path = normalize_path(path)

  if is_windows() then
    os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '"')
  else
    os.execute('mkdir -p "' .. path .. '"')
  end
end

local function file_exists(path)
  local f = io.open(path, "r")
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

  -- 去掉公式前后的空白、空行
  -- 这是修复 Missing $ inserted 的关键
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")

  return s
end

local function latex_escape_for_attr(s)
  s = tostring(s or "")
  s = s:gsub("\n", " ")
  s = s:gsub('"', "'")
  return s
end

-- Pandoc 输出文件路径。
-- Typora 使用 -o "${outputPath}" 时，这里通常能拿到最终输出路径。
local output_file = PANDOC_STATE.output_file or "output.md"
output_file = normalize_path(output_file)

local output_dir = dirname(output_file)
local output_name = basename_no_ext(output_file)

-- 例如：
--   多目标算法svg.md
--   多目标算法svg-math-svg/
local outdir_rel = output_name .. "-math-svg"
local outdir_abs = normalize_path(output_dir .. "/" .. outdir_rel)

ensure_dir(outdir_abs)

-- 这里可以按需添加宏包。
-- 如果你的公式里用了 \mathscr，就保留 mathrsfs。
-- 如果用了 \cancel，就保留 cancel。
-- 如果没有，也不影响。
local latex_preamble = [[
\documentclass[preview,border=2pt]{standalone}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{mathtools}
\usepackage{bm}
\usepackage{mathrsfs}
\usepackage{cancel}
\begin{document}
]]

local latex_end = [[
\end{document}
]]

function Math(el)
  local math_text = clean_math_text(el.text)

  if math_text == "" then
    return pandoc.Str("")
  end

  local key = pandoc.utils.sha1(el.mathtype .. ":" .. math_text)

  local texfile = normalize_path(outdir_abs .. "/" .. key .. ".tex")
  local dvifile = normalize_path(outdir_abs .. "/" .. key .. ".dvi")
  local svgfile = normalize_path(outdir_abs .. "/" .. key .. ".svg")
  local svg_href = normalize_path(outdir_rel .. "/" .. key .. ".svg")

  if not file_exists(svgfile) then
    local math_body

    if el.mathtype == "InlineMath" then
      math_body = "\\(" .. math_text .. "\\)"
    else
      -- 不要写成 "\\[\n" .. math_text .. "\n\\]"
      -- 因为 math_text 如果残留空行，LaTeX 数学环境里会报 Missing $ inserted。
      math_body = "\\[" .. math_text .. "\\]"
    end

    local tex = latex_preamble .. "\n" .. math_body .. "\n" .. latex_end

    write_file(texfile, tex)

    local ok_latex, latex_result = pcall(function()
      return pandoc.pipe("latex", {
        "-interaction=nonstopmode",
        "-halt-on-error",
        "-output-directory=" .. outdir_abs,
        texfile
      }, "")
    end)

    if not ok_latex then
      error(
        "\nLaTeX 公式编译失败。\n" ..
        "临时文件: " .. texfile .. "\n" ..
        "公式内容:\n" .. math_text .. "\n\n" ..
        "LaTeX 错误信息:\n" .. tostring(latex_result)
      )
    end

    local ok_svg, svg_result = pcall(function()
      return pandoc.pipe("dvisvgm", {
        "--no-fonts",
        "--exact-bbox",
        dvifile,
        "-o",
        svgfile
      }, "")
    end)

    if not ok_svg then
      error(
        "\ndvisvgm 转 SVG 失败。\n" ..
        "DVI 文件: " .. dvifile .. "\n" ..
        "目标 SVG: " .. svgfile .. "\n" ..
        "公式内容:\n" .. math_text .. "\n\n" ..
        "dvisvgm 错误信息:\n" .. tostring(svg_result)
      )
    end
  end

  local img = pandoc.Image({ pandoc.Str("formula") }, svg_href)

  -- 部分 Markdown writer 会丢弃属性，这是正常的。
  -- 保留它的好处是：如果目标格式支持属性，可以在输出中留下原始 LaTeX。
  img.attributes["data-latex"] = latex_escape_for_attr(math_text)

  return img
end