import sys
import zipfile
import shutil
import tempfile
from pathlib import Path
from lxml import etree

NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
}

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def w_el(tag):
    return W + tag


def make_border(tag, val="single", size="12", space="0", color="auto"):
    """
    Word 边框线宽单位是 eighths of a point：
    size="12" -> 1.5 pt
    size="6"  -> 0.75 pt
    size="4"  -> 0.5 pt
    """
    el = etree.Element(w_el(tag))
    el.set(w_el("val"), val)
    el.set(w_el("sz"), size)
    el.set(w_el("space"), space)
    el.set(w_el("color"), color)
    return el


def make_nil_border(tag):
    el = etree.Element(w_el(tag))
    el.set(w_el("val"), "nil")
    return el


def clear_children(el):
    for child in list(el):
        el.remove(child)


def get_or_create(parent, tag):
    child = parent.find(f"w:{tag}", NS)
    if child is None:
        child = etree.SubElement(parent, w_el(tag))
    return child


def get_tc_borders(tc):
    tcPr = tc.find("w:tcPr", NS)
    if tcPr is None:
        tcPr = etree.Element(w_el("tcPr"))
        tc.insert(0, tcPr)

    tcBorders = tcPr.find("w:tcBorders", NS)
    if tcBorders is None:
        tcBorders = etree.SubElement(tcPr, w_el("tcBorders"))

    return tcBorders


def reset_cell_borders(tc):
    """
    清空单元格边框，然后显式设为无边框。
    """
    tcBorders = get_tc_borders(tc)
    clear_children(tcBorders)

    tcBorders.append(make_nil_border("top"))
    tcBorders.append(make_nil_border("left"))
    tcBorders.append(make_nil_border("bottom"))
    tcBorders.append(make_nil_border("right"))
    tcBorders.append(make_nil_border("insideH"))
    tcBorders.append(make_nil_border("insideV"))


def replace_border(tc, tag, border_el):
    """
    替换某个单元格指定方向的边框。
    """
    tcBorders = get_tc_borders(tc)

    old = tcBorders.find(f"w:{tag}", NS)
    if old is not None:
        tcBorders.remove(old)

    tcBorders.append(border_el)


def clear_table_level_borders(tbl):
    """
    清除表格级边框，避免和单元格级边框冲突。
    """
    tblPr = tbl.find("w:tblPr", NS)
    if tblPr is None:
        tblPr = etree.Element(w_el("tblPr"))
        tbl.insert(0, tblPr)

    tblBorders = tblPr.find("w:tblBorders", NS)
    if tblBorders is None:
        tblBorders = etree.SubElement(tblPr, w_el("tblBorders"))

    clear_children(tblBorders)

    tblBorders.append(make_nil_border("top"))
    tblBorders.append(make_nil_border("left"))
    tblBorders.append(make_nil_border("bottom"))
    tblBorders.append(make_nil_border("right"))
    tblBorders.append(make_nil_border("insideH"))
    tblBorders.append(make_nil_border("insideV"))


def mark_first_row_as_header(first_row):
    """
    标记第一行为表头行。
    """
    trPr = first_row.find("w:trPr", NS)
    if trPr is None:
        trPr = etree.Element(w_el("trPr"))
        first_row.insert(0, trPr)

    if trPr.find("w:tblHeader", NS) is None:
        etree.SubElement(trPr, w_el("tblHeader"))


def set_three_line_table(tbl):
    """
    使用单元格级边框生成三线表：
    第一行上边框：1.5 磅
    第一行下边框：0.75 磅
    最后一行下边框：1.5 磅
    其他边框全部无
    """
    rows = tbl.findall("w:tr", NS)
    if not rows:
        return

    clear_table_level_borders(tbl)

    # 先清空所有单元格边框
    for tc in tbl.findall(".//w:tc", NS):
        reset_cell_borders(tc)

    first_row = rows[0]
    last_row = rows[-1]

    mark_first_row_as_header(first_row)

    # 第一行：顶线 + 表头下线
    for tc in first_row.findall("w:tc", NS):
        replace_border(tc, "top", make_border("top", size="12"))
        replace_border(tc, "bottom", make_border("bottom", size="6"))

    # 最后一行：底线
    for tc in last_row.findall("w:tc", NS):
        replace_border(tc, "bottom", make_border("bottom", size="12"))


def patch_document_xml(xml_bytes):
    parser = etree.XMLParser(remove_blank_text=False)
    root = etree.fromstring(xml_bytes, parser)

    tables = root.findall(".//w:tbl", NS)

    for tbl in tables:
        set_three_line_table(tbl)

    return etree.tostring(
        root,
        xml_declaration=True,
        encoding="UTF-8",
        standalone=True
    )


def patch_docx(input_docx, output_docx=None):
    input_docx = Path(input_docx)

    if output_docx is None:
        output_docx = input_docx
    else:
        output_docx = Path(output_docx)

    if not input_docx.exists():
        raise FileNotFoundError(f"找不到文件：{input_docx}")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        temp_docx = tmpdir / "patched.docx"

        with zipfile.ZipFile(input_docx, "r") as zin:
            with zipfile.ZipFile(temp_docx, "w", zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    data = zin.read(item.filename)

                    if item.filename == "word/document.xml":
                        data = patch_document_xml(data)

                    zout.writestr(item, data)

        shutil.copyfile(temp_docx, output_docx)


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        print("用法：")
        print("  python fix-three-line-tables.py input.docx")
        print("  python fix-three-line-tables.py input.docx output.docx")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) == 3 else None

    patch_docx(input_path, output_path)

    if output_path:
        print(f"已完成三线表处理：{output_path}")
    else:
        print(f"已完成三线表处理：{input_path}")