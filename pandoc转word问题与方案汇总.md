# 模板采用github开源模板

[Achuan-2/pandoc_docx_template: Markdown导出为docx时使用的模板，可控制导出docx的段落文字、标题编号等样式，适用于obsidian、typora、思源笔记等Markdown笔记软件丨Template for exporting Markdown to docx (Word) using pandoc](https://github.com/Achuan-2/pandoc_docx_template)



# 当前命令行参数

```cmd
pandoc "${currentPath}" -f markdown+implicit_figures+pipe_tables+tex_math_dollars -s -t docx --reference-doc "D:\Projects\pandoc_docx_template\实验报告转模板.docx" -o "${outputPath}" --lua-filter="D:\Projects\pandoc_docx_template\markdown-to-docx.lua" && python "D:\Projects\pandoc_docx_template\fix-three-line-tables.py" "${outputPath}"
```





# Typora导出后图片没有编号

**Typora 里的 `-f native` 基本就是罪魁祸首。**

命令行直接跑 Markdown 有图片标题，是因为 Pandoc 读的是 Markdown：

```cmd
pandoc -f markdown+implicit_figures input.md -o output.docx
```

Pandoc 会把这种图片：

```markdown
![图 1-1 软件业务定位图](./assets/xxx.png)
```

识别成 **Figure + caption**。

但 Typora 里的参数是：

```cmd
-f native -s -o ${outputPath} -t docx --reference-doc "D:\ZJU\模板_PPT_WORD_Latex\pandoc_docx_template-main\template_标题不编号-列表第二行顶格.docx"
```

`-f native` 的意思是：**告诉 Pandoc：输入不是 Markdown，而是 Pandoc 的 native AST 格式。**

这会绕开 Markdown 的 `implicit_figures` 规则。也就是说，`![标题](图片.png)` 这种 Markdown 图片是否变成 figure，不再由 Pandoc 的 Markdown 解析器决定，而取决于 Typora 传给 Pandoc 的中间内容。Typora 很可能把图片传成了普通 image，所以到 docx 里就没有 caption。

------

## 把 Typora 参数改成这样

优先试这个：

```cmd
-f markdown+implicit_figures -s -o ${outputPath} -t docx --reference-doc "D:\ZJU\模板_PPT_WORD_Latex\pandoc_docx_template-main\template_标题不编号-列表第二行顶格.docx"
```

也就是把：

```cmd
-f native
```

改成：

```cmd
-f markdown+implicit_figures
```

## 推荐做法：勾选“运行自定义命令”

在下面的 **自定义参数** 框里填完整命令，让 Pandoc 直接读取 `.md` 文件。

试这个：

```cmd
pandoc "${currentPath}" -f markdown+implicit_figures+pipe_tables+tex_math_dollars -s -t docx --reference-doc "D:\ZJU\模板_PPT_WORD_Latex\pandoc_docx_template-main\template_标题不编号-列表第二行顶格.docx" -o "${outputPath}"
```

然后勾选：

```
运行自定义命令
```

如果 `${currentPath}` 不生效，换成这个：

```cmd
pandoc "${inputPath}" -f markdown+implicit_figures+pipe_tables+tex_math_dollars -s -t docx --reference-doc "D:\ZJU\模板_PPT_WORD_Latex\pandoc_docx_template-main\template_标题不编号-列表第二行顶格.docx" -o "${outputPath}"
```





# 公式中的数字转换后变成斜体

### 方案 2：用 Lua filter 批量把公式中的数字包成 `\mathrm{}`

如果你的文档公式很多，可以让 Pandoc 在转换前自动处理。新建 `upright-numbers.lua`：

```lua
function Math(el)
  local text = el.text

  text = text:gsub("(%d+%.?%d*)", "\\mathrm{%1}")

  return pandoc.Math(el.mathtype, text)
end
```

然后转换：

```cmd
pandoc input.md -o output.docx --lua-filter=upright-numbers.lua
```

这样：

```
3.061
```

会被自动变成：

```latex
\mathrm{3.061}
```

注意：这个简单 filter 会处理所有数学环境里的数字。如果你的公式里有指数、变量下标等也带数字，比如 `x_1`、`10^{-3}`，也会被包起来。一般对 Word 显示没坏处，但如果你想只处理小数、百分数，可以把规则写得更精细。

### lua代码解释

这是一个 **Pandoc Lua filter**，意思是：在 Pandoc 把 Markdown 转成 Word 之前，自动扫描所有公式，把公式里的数字改写成 `\mathrm{数字}`，强制数字在 Word 公式里显示为直立体。

逐行解释：

```lua
function Math(el)
```

定义一个处理函数。Pandoc 在读到数学公式时，会自动调用这个函数。
`el` 就是当前这个公式对象。

```lua
local text = el.text
```

把公式源码取出来。比如你的公式：

```latex
\delta_U=\frac{3.061-3.000}{3.000}\times100\%=2.03\%
```

这里的 `text` 就是这整段公式内容。

```lua
text = text:gsub("(%d+%.?%d*)", "\\mathrm{%1}")
```

这是核心。它用正则查找数字，并替换成 `\mathrm{数字}`。

比如会把：

```latex
3.061
3.000
100
2.03
```

变成：

```latex
\mathrm{3.061}
\mathrm{3.000}
\mathrm{100}
\mathrm{2.03}
```

所以原公式会变成：

```latex
\delta_U=\frac{\mathrm{3.061}-\mathrm{3.000}}{\mathrm{3.000}}\times\mathrm{100}\%=\mathrm{2.03}\%
```

其中 `%1` 的意思是“匹配到的那个数字”。

```lua
return pandoc.Math(el.mathtype, text)
```

把修改后的公式交还给 Pandoc，让它继续转成 Word。

实际用法是：新建一个文件，比如叫：

```text
upright-numbers.lua
```

里面放这段代码，然后转换时这样用：

```bash
pandoc input.md -o output.docx --lua-filter=upright-numbers.lua
```

它的作用相当于自动帮你把 Markdown 公式从：

```latex
$$
\delta_U=\frac{3.061-3.000}{3.000}\times100\%=2.03\%
$$
```

变成：

```latex
$$
\delta_U=\frac{\mathrm{3.061}-\mathrm{3.000}}{\mathrm{3.000}}\times\mathrm{100}\%= \mathrm{2.03}\%
$$
```

但你原始 `.md` 文件不会被改，只是在 Pandoc 转换过程中临时改写。

有一个小注意：这段代码会处理**所有公式里的数字**，例如 `x_1` 里的 `1`、`10^{-3}` 里的 `10` 和 `3` 也会被包成 `\mathrm{}`。大多数情况下没问题，因为数字本来就该直立；但如果你有复杂公式，可以再把规则写得更精细。

# 表格样式不生效

解决方案：生成docx之后，加一个自动化python脚本处理，直接把所有的表格样式强制设置为三线表。同时加上缩进。

```cmd
python "D:\Projects\pandoc_docx_template\fix-three-line-tables.py" "${outputPath}"
```

注意项目根部现在有两个py脚本

`fix-three-line-tables.py`: 所有的表格样式改为三线表，表格边框修改为三线表的样子，加上1cm的强制缩进（python内部可改），<font color="red">不清除单元格边框</font>

`change-to-three-line-tables-all.py`: 表格样式改为三线表，表格边框修改为三线表的样子，加上1cm的强制缩进（python内部可改），<font color="red">清除单元格边框</font>





------

# Typora + Pandoc 批量将 Markdown 公式转换为 SVG 图片方案

## 1. 需求背景

Typora 中的 Markdown 文档通常使用 LaTeX 语法书写公式，例如：

```markdown
这是行内公式 $E=mc^2$。

这是块级公式：

$$
E_{grid,buy}=\sum_{t=1}^{T}P_{buy}(t)\Delta t
$$
```

如果直接用 Pandoc 导出为 Word 或 PPT，公式通常会被转换为 Office 原生公式，或者在 WPS/PPT 中出现兼容性问题。为了获得更稳定的显示效果，本方案将 Markdown 中的所有 LaTeX 公式批量转换为 SVG 矢量图片，并在新的 Markdown 中用图片引用替代原公式。

最终效果为：

```markdown
这是行内公式 ![formula](math-svg/xxxx.svg)。

这是块级公式：

![formula](math-svg/yyyy.svg)
```

生成的 SVG 是矢量图，缩放不模糊，适合后续继续导出到 Word、PPT 或 WPS。

------

## 2. 当前采用的总体方案

当前方案使用三部分工具协同完成：

```text
Typora 自定义导出命令
        ↓
run-typora-mathsvg.bat
        ↓
Pandoc + Lua filter
        ↓
XeLaTeX 编译公式为 XDV
        ↓
dvisvgm 转换为 SVG
        ↓
BAT 复制 SVG 到导出目录的 math-svg/
        ↓
生成新的 Markdown
```

其中各部分职责如下：

| 组件       | 作用                                             |
| ---------- | ------------------------------------------------ |
| Typora     | 提供图形界面导出入口                             |
| Pandoc     | 解析 Markdown，并通过 Lua filter 替换公式节点    |
| Lua filter | 将每个公式编译为 SVG，并把公式节点替换为图片节点 |
| XeLaTeX    | 编译 LaTeX 公式，支持中文公式内容                |
| dvisvgm    | 将 XeLaTeX 生成的 XDV 文件转换为 SVG             |
| BAT 脚本   | 调用 Pandoc、复制 SVG 到最终目录、清理临时文件   |

------

## 3. 核心原理

Pandoc 在读取 Markdown 时，会把文档解析成内部 AST。Markdown 中的数学公式会被识别为 `Math` 节点。

Lua filter 中定义了：

```lua
function Math(el)
  ...
end
```

Pandoc 遍历文档时，每遇到一个公式节点，就会调用这个函数。

处理过程如下：

1. 读取公式文本，例如：

   ```tex
   E_{grid,buy}=\sum_{t=1}^{T}P_{buy}(t)\Delta t
   ```

2. 对公式内容做 SHA1 哈希，生成稳定文件名：

   ```text
   62e55a3a2c501f2e526102ad4c11383cba06fc7a.svg
   ```

3. 将公式写入一个临时 `.tex` 文件：

   ```tex
   \documentclass[preview,border=2pt]{standalone}
   \usepackage{amsmath}
   \usepackage{amssymb}
   \usepackage{mathtools}
   \usepackage{bm}
   \usepackage{mathrsfs}
   \usepackage{cancel}
   \usepackage{fontspec}
   \usepackage{xeCJK}
   
   \begin{document}
   \[
   E_{grid,buy}=\sum_{t=1}^{T}P_{buy}(t)\Delta t
   \]
   \end{document}
   ```

4. 使用 XeLaTeX 编译为 `.xdv`：

   ```bash
   xelatex -no-pdf formula.tex
   ```

5. 使用 dvisvgm 转成 SVG：

   ```bash
   dvisvgm --no-fonts --exact-bbox formula.xdv -o formula.svg
   ```

6. Pandoc 将原公式节点替换为图片节点：

   ```markdown
   ![formula](math-svg/62e55a3a2c501f2e526102ad4c11383cba06fc7a.svg)
   ```

------

## 4. 为什么使用 XeLaTeX，而不是 latex

最开始使用的是传统 `latex`，也就是 pdfTeX。它可以处理普通英文公式，但遇到公式中的中文会报错，例如：

```tex
flag=
\begin{cases}
1, & \text{风光互补}\\
2, & \text{纯风}\\
3, & \text{纯光}
\end{cases}
```

pdfTeX 会报类似错误：

```text
Unicode character 风 not set up for use with LaTeX
```

因此当前方案改为：

```text
xelatex + xeCJK + dvisvgm
```

这样可以正常处理：

```tex
\text{风光互补}
\text{纯风}
\text{纯光}
```

------

## 5. 为什么要使用英文临时目录

TeX Live 在 Windows 下处理中文路径时可能失败。例如源文件路径是：

```text
D:\ZJU\科研\srtp\结题\建模.md
```

如果直接把临时 `.tex` 文件也放在中文目录下，TeX 工具链可能找不到文件。

因此当前方案将所有 TeX 编译中间文件统一放到纯英文路径：

```text
D:\Projects\pandoc_docx_template\.math-svg-build
```

该目录只用于临时编译，生成完成后由 BAT 脚本复制 SVG 到最终输出目录。

------

## 6. 文件结构

推荐目录结构如下：

```text
D:\Projects\pandoc_docx_template\
│
├─ lua\
│  └─ math-to-svg-md.lua
│
├─ run-typora-mathsvg.bat
│
└─ .math-svg-build\
   ├─ xxx.tex
   ├─ xxx.xdv
   ├─ xxx.svg
   └─ ...
```

导出后，目标 Markdown 所在目录会生成：

```text
D:\ZJU\科研\srtp\结题\
│
├─ 建模.md
├─ 建模svg.md
│
└─ math-svg\
   ├─ 62e55a3a2c501f2e526102ad4c11383cba06fc7a.svg
   ├─ 8e66be04af0fa8a34d5bb7775aa4fec9a6dc882c.svg
   └─ ...
```

如果同一个目录下转换多个 Markdown，默认会共用同一个：

```text
math-svg/
```

这通常没问题，因为 SVG 文件名由公式内容哈希生成，相同公式会复用，不同公式基本不会冲突。

------

## 7. 使用步骤

### 7.1 安装依赖

需要安装：

1. Pandoc
2. TeX Live 或 MiKTeX
3. dvisvgm
4. Typora

在命令行中检查：

```bash
pandoc --version
xelatex --version
dvisvgm --version
```

都能正常输出版本号后再继续。

------

### 7.2 准备 Lua filter

保存文件：

```text
D:\Projects\pandoc_docx_template\lua\math-to-svg-md.lua
```

该 Lua filter 负责：

1. 捕获 Markdown 里的公式；
2. 调用 XeLaTeX 编译公式；
3. 调用 dvisvgm 转成 SVG；
4. 把公式替换成 `math-svg/xxx.svg` 图片引用。

------

### 7.3 准备 BAT 脚本

保存文件：

```text
D:\Projects\pandoc_docx_template\run-typora-mathsvg.bat
```

该 BAT 脚本负责：

1. 清空旧的临时 build 目录；
2. 调用 Pandoc 和 Lua filter；
3. 如果 Pandoc 成功，则把临时目录中的 SVG 复制到导出 Markdown 同级的 `math-svg/`；
4. 删除临时 build 目录；
5. 如果 Pandoc 失败，则保留 build 目录用于排查错误。

------

### 7.4 在 Typora 中配置自定义导出命令

Typora 中进入：

```text
偏好设置 → 导出 → Markdown (Other Spec) → 运行自定义命令
```

自定义命令填写：

```bat
cmd /C ""D:\Projects\pandoc_docx_template\run-typora-mathsvg.bat" "${currentPath}" "${outputPath}""
```

其中：

| 变量             | 含义                             |
| ---------------- | -------------------------------- |
| `${currentPath}` | 当前正在编辑的 Markdown 文件路径 |
| `${outputPath}`  | Typora 导出时选择的目标文件路径  |

------

### 7.5 执行导出

在 Typora 中执行：

```text
文件 → 导出 → 自定义的 Markdown 转 SVG 配置
```

假设当前文件为：

```text
D:\ZJU\科研\srtp\结题\建模.md
```

导出为：

```text
D:\ZJU\科研\srtp\结题\建模svg.md
```

成功后会得到：

```text
D:\ZJU\科研\srtp\结题\建模svg.md
D:\ZJU\科研\srtp\结题\math-svg\
```

`建模svg.md` 中的公式会被替换为：

```markdown
![formula](math-svg/xxxx.svg)
```

------

## 8. 当前 BAT 脚本的工作逻辑

BAT 脚本大致逻辑如下：

```bat
@echo off

set "INPUT=%~1"
set "OUTPUT=%~2"

set "FILTER=D:\Projects\pandoc_docx_template\lua\math-to-svg-md.lua"
set "BUILD=D:\Projects\pandoc_docx_template\.math-svg-build"

set "OUTDIR=%~dp2"
set "SVGDIR=%OUTDIR%math-svg"

if exist "%BUILD%" rmdir /S /Q "%BUILD%"
mkdir "%BUILD%" 2>nul

pandoc "%INPUT%" ^
  -f markdown+tex_math_dollars+tex_math_single_backslash+latex_macros ^
  --lua-filter="%FILTER%" ^
  -t gfm ^
  --wrap=none ^
  -o "%OUTPUT%"

if errorlevel 1 (
  echo [ERROR] Pandoc failed. Build directory kept:
  echo %BUILD%
  exit /b 1
)

if not exist "%SVGDIR%" mkdir "%SVGDIR%"

copy /Y "%BUILD%\*.svg" "%SVGDIR%\" >nul

rmdir /S /Q "%BUILD%"

exit /b 0
```

其中最重要的是：

```bat
copy /Y "%BUILD%\*.svg" "%SVGDIR%\"
```

这一步负责把临时目录里的 SVG 复制到最终输出目录。

------

## 9. 当前 Lua filter 的关键设计

### 9.1 使用 SHA1 作为文件名

每个公式根据以下内容生成哈希：

```text
公式类型 + 公式内容
```

因此：

```tex
E=mc^2
```

会稳定生成同一个 SVG 文件名。好处是：

1. 同一个公式不会重复生成；
2. 文件名不会包含特殊字符；
3. 适合批量转换。

------

### 9.2 使用 `--no-fonts`

dvisvgm 调用参数为：

```bash
dvisvgm --no-fonts --exact-bbox formula.xdv -o formula.svg
```

其中：

| 参数           | 作用                                          |
| -------------- | --------------------------------------------- |
| `--no-fonts`   | 将字体轮廓转成 path，减少目标机器字体缺失问题 |
| `--exact-bbox` | 尽量裁剪到公式实际边界，避免 SVG 周围空白过大 |

------

### 9.3 使用 `--wrap=none`

Pandoc 命令中使用：

```bash
--wrap=none
```

作用是避免 Pandoc 输出 Markdown 时自动硬换行，使生成的 Markdown 更易读。

------

## 10. 常见问题

### 10.1 为什么有时没有生成 `math-svg/`

如果 Pandoc 或 LaTeX 在中途失败，BAT 脚本不会执行复制步骤，因此不会生成最终的 `math-svg/`。

这种情况下会保留：

```text
D:\Projects\pandoc_docx_template\.math-svg-build
```

可以查看其中的 `.tex` 或 `.log` 文件定位出错公式。

------

### 10.2 为什么临时目录最后消失了

这是正常现象。BAT 脚本在成功后会执行：

```bat
rmdir /S /Q "%BUILD%"
```

因此：

```text
D:\Projects\pandoc_docx_template\.math-svg-build
```

只在失败时保留。

------

### 10.3 如果公式中有中文怎么办

当前方案已经支持中文，因为使用了：

```tex
\usepackage{fontspec}
\usepackage{xeCJK}
```

以及：

```bash
xelatex -no-pdf
```

可以处理：

```tex
\text{风光互补}
```

------

### 10.4 如果公式用了额外宏包怎么办

如果公式中使用了未包含的命令，比如：

```tex
\ce{H2O}
```

需要在 Lua filter 的 LaTeX 模板中增加：

```tex
\usepackage[version=4]{mhchem}
```

如果使用：

```tex
\si{kWh}
```

则需要增加：

```tex
\usepackage{siunitx}
```

------

## 11. 方案优点

1. **批量化**：整个 Markdown 文档中的公式可一次性全部转换；
2. **适合 Typora**：可以通过导出按钮直接运行；
3. **兼容中文公式**：使用 XeLaTeX + xeCJK；
4. **路径稳定**：TeX 编译阶段使用英文临时目录，避免中文路径问题；
5. **矢量清晰**：SVG 可任意缩放，适合 Word/PPT/WPS；
6. **失败可排查**：失败时保留临时目录和 `.log` 文件；
7. **成功后自动清理**：成功导出后删除临时 build 目录，只保留最终 SVG。

------

## 12. 方案限制

1. 转成 SVG 后，公式不再是可编辑公式；
2. 输出 Markdown 会被 Pandoc 重新格式化；
3. 特殊 LaTeX 宏包需要手动加入 Lua filter 的模板；
4. 所有 SVG 默认集中放在同级 `math-svg/` 中，如果同目录转换多个 Markdown，会共享该目录；
5. 如果后续移动 Markdown 文件，需要一起移动 `math-svg/` 文件夹。

------

## 13. 推荐最终工作流

```text
原始 Markdown
    ↓ Typora 自定义导出
Pandoc + Lua filter
    ↓
XeLaTeX 编译公式
    ↓
dvisvgm 生成 SVG
    ↓
BAT 复制 SVG
    ↓
生成：
  xxxsvg.md
  math-svg/
```

该方案适合需要将 Markdown 公式稳定转为 SVG 图片，并进一步用于 Word、PPT、WPS 或网页展示的场景。