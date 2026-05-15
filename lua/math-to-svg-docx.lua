-- markdown转word中，将公式全部生成为svg图片，便于复制到ppt中

local outdir = "math-svg"

local function is_windows()
  return package.config:sub(1, 1) == "\\"
end

local function ensure_dir(path)
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

ensure_dir(outdir)

function Math(el)
  local key = pandoc.utils.sha1(el.mathtype .. ":" .. el.text)

  local texfile = outdir .. "/" .. key .. ".tex"
  local dvifile = outdir .. "/" .. key .. ".dvi"
  local svgfile = outdir .. "/" .. key .. ".svg"

  if not file_exists(svgfile) then
    local body

    if el.mathtype == "InlineMath" then
      body = "$" .. el.text .. "$"
    else
      body = "\\[\n" .. el.text .. "\n\\]"
    end

    local tex = [[
\documentclass[preview,border=2pt]{standalone}
\usepackage{amsmath,amssymb,bm,mathtools}
\begin{document}
]] .. body .. [[
\end{document}
]]

    write_file(texfile, tex)

    pandoc.pipe("latex", {
      "-interaction=nonstopmode",
      "-halt-on-error",
      "-output-directory=" .. outdir,
      texfile
    }, "")

    pandoc.pipe("dvisvgm", {
      "--no-fonts",
      "--exact-bbox",
      dvifile,
      "-o",
      svgfile
    }, "")
  end

  local img = pandoc.Image("", svgfile)

  -- 可选：给 Word 里的图片加一点语义说明
  img.attributes["title"] = el.text

  return img
end