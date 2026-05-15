# 模板采用github开源模板

[Achuan-2/pandoc_docx_template: Markdown导出为docx时使用的模板，可控制导出docx的段落文字、标题编号等样式，适用于obsidian、typora、思源笔记等Markdown笔记软件丨Template for exporting Markdown to docx (Word) using pandoc](https://github.com/Achuan-2/pandoc_docx_template)



# 当前命令行参数

```cmd
pandoc "${currentPath}" -f markdown+implicit_figures+pipe_tables+tex_math_dollars -s -t docx --reference-doc "D:\Projects\pandoc_docx_template\实验报告转模板.docx" -o "${outputPath}" --lua-filter="D:\Projects\pandoc_docx_template\markdown-to-docx.lua" && python "D:\Projects\pandoc_docx_template\fix-three-line-tables.py" "${outputPath}"
```





# Typora导出后图片没有编号

问题找到了：**Typora 里的 `-f native` 基本就是罪魁祸首。**

你命令行直接跑 Markdown 有图片标题，是因为 Pandoc 读的是 Markdown：

```cmd
pandoc -f markdown+implicit_figures input.md -o output.docx
```

Pandoc 会把这种图片：

```markdown
![图 1-1 软件业务定位图](./assets/xxx.png)
```

识别成 **Figure + caption**。

但你 Typora 里的参数是：

```cmd
-f native -s -o ${outputPath} -t docx --reference-doc "D:\ZJU\模板_PPT_WORD_Latex\pandoc_docx_template-main\template_标题不编号-列表第二行顶格.docx"
```

`-f native` 的意思是：**告诉 Pandoc：输入不是 Markdown，而是 Pandoc 的 native AST 格式。**

这会绕开 Markdown 的 `implicit_figures` 规则。也就是说，`![标题](图片.png)` 这种 Markdown 图片是否变成 figure，不再由 Pandoc 的 Markdown 解析器决定，而取决于 Typora 传给 Pandoc 的中间内容。Typora 很可能把图片传成了普通 image，所以到 docx 里就没有 caption。

------

## 你应该把 Typora 参数改成这样

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



# 转word中公式改为svg