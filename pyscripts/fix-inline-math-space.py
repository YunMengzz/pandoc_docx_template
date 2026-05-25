from pathlib import Path
import re
import sys

# 匹配单行内的 $...$，避开 $$...$$ 和转义的 \$
INLINE_MATH = re.compile(
    r'(?<!\\)(?<!\$)\$(?!\$)(.*?)(?<!\\)(?<!\$)\$(?!\$)'
)

# 尽量避开行内代码 `...`
INLINE_CODE = re.compile(r'(`+[^`\n]*?\1)')


def read_text(path: Path) -> str:
    data = path.read_bytes()

    for enc in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass

    raise UnicodeDecodeError("unknown", data, 0, 1, "无法识别文件编码")


def fix_math_segment(text: str) -> str:
    def repl(match):
        inner = match.group(1)
        return "$" + inner.strip(" \t") + "$"

    return INLINE_MATH.sub(repl, text)


def fix_line(line: str) -> str:
    # 拆开行内代码，只处理非代码部分
    parts = INLINE_CODE.split(line)
    fixed_parts = []

    for part in parts:
        if part.startswith("`"):
            fixed_parts.append(part)
        else:
            fixed_parts.append(fix_math_segment(part))

    return "".join(fixed_parts)


def fix_markdown(text: str) -> str:
    lines = text.splitlines(keepends=True)
    new_lines = []

    in_code_block = False

    for line in lines:
        stripped = line.lstrip()

        # 跳过 fenced code block，避免误伤 ```...``` 或 ~~~...~~~
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_code_block = not in_code_block
            new_lines.append(line)
            continue

        if in_code_block:
            new_lines.append(line)
        else:
            new_lines.append(fix_line(line))

    return "".join(new_lines)


def main():
    if len(sys.argv) != 3:
        print("用法: python fix-inline-math-space.py input.md output.md", file=sys.stderr)
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    text = read_text(input_path)
    fixed = fix_markdown(text)

    output_path.write_text(fixed, encoding="utf-8", newline="")


if __name__ == "__main__":
    main()