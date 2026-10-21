"""检查翻译表：找出代码里有、locale/text.csv 里还没翻译的中文文字，以及表里已经没人用的旧条目。

用法（在项目根目录）：
    python3 tools/check_translations.py          只报告
    python3 tools/check_translations.py --add    把缺的文字加到表末尾（译文留空，等人填）

代码里的中文原文就是翻译表的第一列。改了一句中文，表里要跟着改，否则那句会显示成中文。
"""
import csv
import glob
import json
import re
import sys

CSV_PATH = "locale/text.csv"
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
CHINESE = re.compile(r"[　-鿿＀-￯]")
NOT_SHOWN = ("push_error", "push_warning", "print(")  # 只给开发者看的报错不用翻译
UNTRANSLATED = {"简体中文"}  # 语言名用它自己的文字显示


def code_strings():
    found = {}
    for path in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
        for number, line in enumerate(open(path, encoding="utf-8"), 1):
            if line.lstrip().startswith("#") or any(word in line for word in NOT_SHOWN):
                continue
            last_quote = line.rfind('"')
            comment = line.find(" # ", max(last_quote, 0))
            code = line[:comment] if comment >= 0 else line
            for match in STRING.finditer(code):
                text = match.group(1)
                if CHINESE.search(text) and text not in UNTRANSLATED:
                    if "\\" in text:
                        text = text.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
                    found.setdefault(text, f"{path}:{number}")
    for path in sorted(glob.glob("scripts/**/*_timeline.json", recursive=True)):  # 篇章结局的字幕
        data = json.load(open(path, encoding="utf-8"))
        for beat in data.get("beats", []):
            found.setdefault(beat["text"], f"{path}:beat{beat['index']}")
    return found


def main():
    rows = list(csv.reader(open(CSV_PATH, encoding="utf-8")))
    table = {row[0]: row[1:] for row in rows[1:]}
    found = code_strings()
    missing = [text for text in found if text not in table or not any(table[text])]
    unused = [text for text in table if text not in found and text not in UNTRANSLATED]
    for text in missing:
        print("缺翻译", found[text], repr(text))
    for text in unused:
        print("没人用", repr(text))
    print(f"共 {len(found)} 条，缺 {len(missing)} 条，没人用 {len(unused)} 条")
    if "--add" in sys.argv:
        new = [text for text in missing if text not in table]
        with open(CSV_PATH, "a", encoding="utf-8", newline="") as file:
            csv.writer(file, lineterminator="\n").writerows([[text] + [""] * (len(rows[0]) - 1) for text in new])
        print(f"已加入 {len(new)} 条空白条目")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
