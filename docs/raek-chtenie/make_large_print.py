#!/usr/bin/env python3
"""Two-page large-print A4 script for stage folder reading."""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    PageBreak,
)
from reportlab.pdfgen import canvas
from pathlib import Path

FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"

pdfmetrics.registerFont(TTFont("DejaVu", FONT_REG))
pdfmetrics.registerFont(TTFont("DejaVuBold", FONT_BOLD))

OUT = Path(__file__).with_name("Antiformalisticheskiy_raek_2str_krupny_shrift.pdf")

# Text follows the user's CamScanner page (abridged stage version).
TITLE = "Антиформалистический раек"
SPEAKER = "Начальник ОМБ:"

# Page 1
P1 = [
    "Сегодня на повестке дня обсуждение музыкального сочинения, которое попало к нам благодаря бдительности нашего ценного сотрудника!",
    "Должен сообщить, что «Рукопись данного сочинения была обнаружена в ящике с нечистотами кандидатом изящных наук П.&nbsp;И.&nbsp;Опостыловым. Тщательно отделив от рукописи прилипшие к ней нечистоты, тов.&nbsp;Опостылов, предварительно изучив её (рукопись), передал нам.",
    "Судя по всему, это произведение, по причинам мне неизвестным, осталось незаконченным. Несмотря на принятые меры (были опрошены все композиторы, писатели и поэты), авторов (автора?) музыки и текста обнаружить не удалось. Однако выдающиеся качества как музыки, так и текста заставляют нас считать, что мы имеем дело с выдающимся произведением.",
    "Композитор (…хотя не лишено возможности, что композитор и поэт являются одним лицом) мастерски использует народное творчество. Музыка органически сливается с текстом, изобилующим глубокими мыслями, вытекающими из вдохновляющих указаний. Превосходно отточенный стих заставляет думать о разносторонности дарования автора текста. В живой и ясной форме выступают три оратора, участники свободной дискуссии: И.&nbsp;С.&nbsp;Единицын, А.&nbsp;А.&nbsp;Двойкин и Д.&nbsp;Т.&nbsp;Тройкин.",
]

# Page 2
P2 = [
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
        self.setFont("DejaVu", 11)
        self.setFillColorRGB(0.25, 0.25, 0.25)
        label = f"{page} / {page_count}"
        self.drawRightString(A4[0] - 14 * mm, 10 * mm, label)
        # Tiny hint so sheets are not swapped in the folder
        self.setFont("DejaVu", 9)
        side = "левый лист папки" if page == 1 else "правый лист папки"
        self.drawString(14 * mm, 10 * mm, side)


def build(font_size: float, out_path: Path, leading_ratio: float = 1.38) -> int:
    leading = font_size * leading_ratio
    title_size = font_size + 4
    speaker_size = font_size + 1.5

    styles = {
        "title": ParagraphStyle(
            "title",
            fontName="DejaVuBold",
            fontSize=title_size,
            leading=title_size * 1.2,
            alignment=TA_CENTER,
            spaceAfter=font_size * 0.18,
            textColor=(0, 0, 0),
        ),
        "speaker": ParagraphStyle(
            "speaker",
            fontName="DejaVuBold",
            fontSize=speaker_size,
            leading=speaker_size * 1.25,
            alignment=TA_LEFT,
            spaceBefore=font_size * 0.15,
            spaceAfter=max(6, font_size * 0.38),
            textColor=(0, 0, 0),
        ),
        "body": ParagraphStyle(
            "body",
            fontName="DejaVuBold",
            fontSize=font_size,
            leading=leading,
            alignment=TA_LEFT,
            spaceAfter=max(6, font_size * 0.38),
            textColor=(0, 0, 0),
            firstLineIndent=0,
        ),
    }

    doc = SimpleDocTemplate(
        str(out_path),
        pagesize=A4,
        leftMargin=11 * mm,
        rightMargin=11 * mm,
        topMargin=10 * mm,
        bottomMargin=15 * mm,
        title="Антиформалистический раек — чтение (крупный шрифт, 2 стр.)",
        author="по тексту CamScanner 17.09.2026",
    )

    story = []
    story.append(Paragraph(TITLE, styles["title"]))
    story.append(Paragraph(SPEAKER, styles["speaker"]))
    for p in P1:
        story.append(Paragraph(p, styles["body"]))
    story.append(PageBreak())
    for p in P2:
        story.append(Paragraph(p, styles["body"]))

    doc.build(story, canvasmaker=NumberedCanvas)
    from pypdf import PdfReader

    return len(PdfReader(str(out_path)).pages)


def main():
    # Prefer larger type; if it already fits on 2 pages, spend leftover
    # space on line spacing (easier to keep one's place on stage).
    tmp = OUT.with_suffix(".tmp.pdf")
    best = None
    for size in (18.0, 17.5, 17.2, 17.0, 16.7, 16.4):
        for lead in (1.42, 1.38, 1.34, 1.28, 1.24, 1.20):
            pages = build(size, tmp, lead)
            if pages == 2:
                best = (size, lead)
                break
        if best:
            break
    if not best:
        tmp.unlink(missing_ok=True)
        raise SystemExit("could not fit text on 2 pages")
    size, lead = best
    pages = build(size, OUT, lead)
    tmp.unlink(missing_ok=True)
    print(f"font={size}pt leading={lead} pages={pages} -> {OUT}")
    if pages != 2:
        raise SystemExit(f"expected 2 pages, got {pages}")


if __name__ == "__main__":
    main()
