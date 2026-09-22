#!/usr/bin/env python3
"""Two-page large-print A4 script for stage folder reading."""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph
from reportlab.pdfgen import canvas
from pathlib import Path
from pypdf import PdfReader

FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"

pdfmetrics.registerFont(TTFont("DejaVu", FONT_REG))
pdfmetrics.registerFont(TTFont("DejaVuBold", FONT_BOLD))

OUT = Path(__file__).with_name("Antiformalisticheskiy_raek_2str_krupny_shrift.pdf")
OUT_RU = Path(__file__).with_name("Раек_2_страницы.pdf")
OUT_ROOT = Path(__file__).resolve().parents[2] / "Raek_2_pages.pdf"

TITLE = "Антиформалистический раек"
SPEAKER = "Начальник ОМБ:"

PARAS = [
    "Сегодня на повестке дня обсуждение музыкального сочинения, которое попало к нам благодаря бдительности нашего ценного сотрудника!",
    "Должен сообщить, что «Рукопись данного сочинения была обнаружена в ящике с нечистотами кандидатом изящных наук П.&nbsp;И.&nbsp;Опостыловым. Тщательно отделив от рукописи прилипшие к ней нечистоты, тов.&nbsp;Опостылов, предварительно изучив её (рукопись), передал нам.",
    "Судя по всему, это произведение, по причинам мне неизвестным, осталось незаконченным. Несмотря на принятые меры (были опрошены все композиторы, писатели и поэты), авторов (автора?) музыки и текста обнаружить не удалось. Однако выдающиеся качества как музыки, так и текста заставляют нас считать, что мы имеем дело с выдающимся произведением.",
    "Композитор (…хотя не лишено возможности, что композитор и поэт являются одним лицом) мастерски использует народное творчество. Музыка органически сливается с текстом, изобилующим глубокими мыслями, вытекающими из вдохновляющих указаний. Превосходно отточенный стих заставляет думать о разносторонности дарования автора текста. В живой и ясной форме выступают три оратора, участники свободной дискуссии: И.&nbsp;С.&nbsp;Единицын, А.&nbsp;А.&nbsp;Двойкин и Д.&nbsp;Т.&nbsp;Тройкин.",
    "Автор как бы вводит нас во Дворец Культуры, на собрание, посвящённое жгучей проблеме современности; а именно, борьбе реалистического направления в музыке с формалистическим направлением в ней же.",
    "Тонким сатирическим штрихом («народу у нас сегодня маловато»), он едко высмеивает некоторых горекультработников, не умеющих привлечь внимание жадных до культуры наших посетителей клубов к жгучим проблемам музыкознания и языкознания. Особенно убедительно композитор излагает наиболее значительные мысли текста. Где идет речь о мелодичности, музыка мелодична. Где речь идет об изящности&nbsp;— музыка изящна. Именно так, и только так должны сливаться музыка и текст.",
    "Не все, однако, удалось автору музыки. Он неправильно артикулирует Римский-Корсáков, хотя всему миру известно, что надо произносить Римский-Корсакóв (см.&nbsp;речь на Съезде композиторов). Это является крупным, но не решающим недостатком данного произведения. Основные достоинства произведения, его предельная ясность, с которой автор как бы вкладывает в рот полный взволнованной страстности афоризм…",
    "Здесь рукопись П.&nbsp;И.&nbsp;Опостылова обрывается. Некоторое время тому назад тов.&nbsp;Опостылов, борясь, согласно вдохновляющим указаниям, направо и налево, утратил равновесие и упал в ящик с нечистотами. Когда о трагической гибели П.&nbsp;И.&nbsp;Опостылова узнали вышестоящие и высокостоящие музыкальные деятели, они единодушно заявили: «Жаль, жаль. Нам Опостыловы нужны».",
    "Долг наших музыкальных деятелей и особенно работников Отдела Музыкальной Безопасности, во имя увековечения светлой памяти тов.&nbsp;Опостылова, действовать в том же духе.",
]


class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_mark(num)
            super().showPage()
        super().save()

    def draw_page_mark(self, page_count):
        page = self._pageNumber
        self.setFillColorRGB(0.35, 0.35, 0.35)
        self.setFont("DejaVu", 8)
        self.drawRightString(A4[0] - 8 * mm, 6 * mm, f"{page}/{page_count}")
        side = "лево" if page == 1 else "право"
        self.drawString(8 * mm, 6 * mm, side)


def build(
    font_size: float,
    out_path: Path,
    leading_ratio: float = 1.08,
    para_gap_ratio: float = 0.05,
) -> int:
    leading = font_size * leading_ratio
    styles = {
        "title": ParagraphStyle(
            "title",
            fontName="DejaVuBold",
            fontSize=font_size,
            leading=leading,
            alignment=TA_CENTER,
            spaceAfter=1,
            textColor=(0, 0, 0),
        ),
        "speaker": ParagraphStyle(
            "speaker",
            fontName="DejaVuBold",
            fontSize=font_size,
            leading=leading,
            alignment=TA_LEFT,
            spaceBefore=0,
            spaceAfter=font_size * para_gap_ratio,
            textColor=(0, 0, 0),
        ),
        "body": ParagraphStyle(
            "body",
            fontName="DejaVuBold",
            fontSize=font_size,
            leading=leading,
            alignment=TA_LEFT,
            spaceAfter=font_size * para_gap_ratio,
            textColor=(0, 0, 0),
            firstLineIndent=0,
        ),
    }

    doc = SimpleDocTemplate(
        str(out_path),
        pagesize=A4,
        leftMargin=6 * mm,
        rightMargin=6 * mm,
        topMargin=6 * mm,
        bottomMargin=8 * mm,
        title="Антиформалистический раек — чтение (крупный шрифт, 2 стр.)",
        author="по тексту CamScanner 17.09.2026",
    )

    story = [
        Paragraph(TITLE, styles["title"]),
        Paragraph(SPEAKER, styles["speaker"]),
    ]
    for p in PARAS:
        story.append(Paragraph(p, styles["body"]))

    doc.build(story, canvasmaker=NumberedCanvas)
    return len(PdfReader(str(out_path)).pages)


def write_all(size: float, lead: float, gap: float) -> None:
    build(size, OUT, lead, gap)
    OUT_RU.write_bytes(OUT.read_bytes())
    OUT_ROOT.write_bytes(OUT.read_bytes())


def main():
    # Largest size that still fits on exactly 2 A4 sheets.
    size, lead, gap = 20.2, 1.08, 0.05
    write_all(size, lead, gap)
    pages = len(PdfReader(str(OUT)).pages)
    print(f"font={size}pt leading={lead} gap={gap} pages={pages} -> {OUT}")
    if pages != 2:
        raise SystemExit(f"expected 2 pages, got {pages}")


if __name__ == "__main__":
    main()
