@echo off

pandoc "${currentPath}" -f markdown+implicit_figures+pipe_tables+tex_math_dollars -s -t docx --reference-doc "D:\Projects\pandoc_docx_template\实验报告转模板.docx" -o "${outputPath}" --lua-filter="D:\Projects\pandoc_docx_template\markdown-to-docx.lua" && python "D:\Projects\pandoc_docx_template\fix-three-line-tables.py" "${outputPath}"