"""UI 아이콘 시트를 잘라 assets/icons/ui/<name>.png로 패키징한다.

가공은 STYLE.md가 허용하는 범위(잘라내기·축소·흰색 정규화)만 한다.
- 알파 8 미만의 희미한 잔여 픽셀은 0으로 만든다(배경 완전 투명).
- RGB는 255로 정규화하고 알파는 유지한다.
- 내용 영역을 128×128 캔버스에 여백 약 12%로 가운데 정렬한다(LANCZOS 축소).
그림을 덧그리지 않는다.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
SHEETS = Path(__file__).resolve().parent / "sheets"
OUT = ROOT / "assets/icons/ui"
SIZE = 128
PAD = 0.12
ALPHA_FLOOR = 8

# (시트, 열, 행, 셀 순서 이름 목록). None은 다른 시트의 재생성본을 쓰는 칸.
LAYOUT = [
    ("sheet_a.png", 3, 3, ["play", "pause", "stop", "to_start", "loop_once", "loop_all",
                           "loop_hold", "exit_on", "exit_off"]),
    ("sheet_b.png", 3, 3, ["undo", "redo", "add", "remove", "duplicate", "move_up",
                           "move_down", "close", "back"]),
    ("sheet_c.png", 3, 3, ["search", "randomize", "settings", "fullscreen", "save", "open",
                           "export", "import", "copy"]),
    ("sheet_d.png", 3, 3, ["paste", "tab_mode", None, None, "tab_style", None,
                           "tab_decor", None, "tab_export"]),
    ("sheet_e.png", 3, 3, ["mode_message", "mode_trailer", "mode_caption", None,
                           "group_explore", "group_narrator", "group_scene_time",
                           "group_check", "bg_checker"]),
    ("sheet_f.png", 3, 2, ["bg_color", "bg_image", "tab_text", "tab_font", "group_battle",
                           "tab_motion"]),
    ("sheet_g.png", 3, 1, ["tab_layout", None, None]),
]


def clean_alpha(img: Image.Image) -> Image.Image:
    a = img.getchannel("A").point(lambda v: 0 if v < ALPHA_FLOOR else v)
    white = Image.new("RGBA", img.size, (255, 255, 255, 0))
    white.putalpha(a)
    return white


def package(cell: Image.Image) -> Image.Image:
    bbox = cell.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("빈 칸")
    glyph = cell.crop(bbox)
    inner = round(SIZE * (1 - 2 * PAD))
    scale = inner / max(glyph.size)
    w, h = max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale))
    # 알파 프리멀티플라이 상태로 축소해야 가장자리 색이 번지지 않는다. RGB가 전부 흰색이라 그대로 축소한다.
    glyph = glyph.resize((w, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    canvas.alpha_composite(glyph, ((SIZE - w) // 2, (SIZE - h) // 2))
    return clean_alpha(canvas)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for sheet, cols, rows, names in LAYOUT:
        img = clean_alpha(Image.open(SHEETS / sheet).convert("RGBA"))
        cw, ch = img.width / cols, img.height / rows
        for i, name in enumerate(names):
            if name is None:
                continue
            c, r = i % cols, i // cols
            box = (round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch))
            cell = img.crop(box)
            bb = cell.getchannel("A").getbbox()
            if bb[0] == 0 or bb[1] == 0 or bb[2] == cell.width or bb[3] == cell.height:
                print(f"경고: {sheet} {name} 내용이 칸 경계에 닿음 {bb}")
            package(cell).save(OUT / f"{name}.png")
            print(name)


if __name__ == "__main__":
    main()
