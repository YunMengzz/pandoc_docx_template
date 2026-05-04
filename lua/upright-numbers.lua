function Math(el)
    local text = el.text
  
    text = text:gsub("(%d+%.?%d*)", "\\mathrm{%1}")
  
    return pandoc.Math(el.mathtype, text)
  end

  return { Math = Math }