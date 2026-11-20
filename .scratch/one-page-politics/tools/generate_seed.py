#!/usr/bin/env python3
"""把《澄潇宇考研政治主张整理.md》第三部分转成 spec.md §6 的 seed 格式。

这是一次性内容管线：解析器与协议在 spec.md 冻结，种子只生成一次。
运行：python3 .scratch/one-page-politics/tools/generate_seed.py
输出：app/assets/default_sheet.md
"""

from __future__ import annotations

import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CORPUS = ROOT / "澄潇宇考研政治主张整理.md"
OUT = ROOT / "app" / "assets" / "default_sheet.md"

SUBJECT_ORDER = ["马原", "史纲", "思修", "新思想", "时政"]
SUBJECT_BY_NUM = {"1": "马原", "2": "史纲", "3": "思修", "4": "新思想", "5": "时政"}

TOMBSTONE_WORDS = [
    "一切", "所有", "唯一", "完全", "彻底", "无条件", "一成不变", "亘古不变", "始终",
    "根本", "决定", "主导", "取代", "创造", "全面清除",
    "已经", "已实现", "已形成", "已完成",
    "纯粹", "简单加和", "线性", "自发", "自然", "自然而然", "自然显露",
    "具体", "细致", "完整", "全面",
    "就业率", "失业率",
]

ROUND2_KEYWORDS = [
    "核心", "根本", "首要", "本质", "标志", "第一次", "唯一", "首次",
    "前提", "宗旨", "出发点", "落脚点", "法宝", "灵魂", "精髓",
]

# 语料中明确成对、且适合做“双胞胎”的对比；手工整理，避免机械拆分产生歧义。
PAIRS = [
    ("马原", "1.2 资本主义与垄断",
     "[对比] 绝对剩余价值（延长总劳动时间） <> 相对剩余价值（总劳动时间不变、必要时间缩短） | 口诀: 绝对延总，相对缩必"),
    ("马原", "1.2 资本主义与垄断",
     "[对比] 不变资本（价值转移，不带来剩余价值） <> 可变资本（价值由工人劳动再生产，带来剩余价值）"),
    ("马原", "1.2 资本主义与垄断",
     "[对比] 平均利润（部门之间竞争形成） <> 超额利润（部门内部企业竞争形成）"),
    ("史纲", "2.4 易混对比与土地政策",
     "[对比] 工作重心转向城市（七届二中全会） <> 革命重心转向城市（1949 年进北平） | 口诀: 工作七二，革命进京"),
    ("史纲", "2.2 新文化运动、五四与孙中山",
     "[对比] 旧民主主义革命（资产阶级领导） <> 新民主主义革命（无产阶级领导） | 口诀: 新旧看领导"),
    ("史纲", "2.4 易混对比与土地政策",
     "[对比] 遵义会议（生死攸关的转折点） <> 八七会议（大革命失败到土地革命战争兴起）"),
    ("史纲", "2.4 易混对比与土地政策",
     "[对比] 辛亥革命（民主共和观念深入人心） <> 五四运动（新民主主义革命开端）"),
    ("新思想", "未分章",
     "[对比] 政协制度（基本政治制度，是组织不是制度） <> 人大制度（根本政治制度）"),
    ("新思想", "未分章",
     "[对比] 高质量发展（全面建设社会主义现代化国家的首要任务） <> 新质生产力（推动高质量发展的着力点）"),
    ("思修", "未分章",
     "[对比] 法律至上·普遍适用（所有人、机构、组织都要遵守） <> 法律至上·不可违反（不论职位高低，违法必受制裁惩罚）"),
]

GENERIC_PROMPTS = [
    "政治", "中心", "首要目的", "根本动力", "可能性", "命名", "继续发展",
    "抗日", "解放战争", "建国初期", "遵义", "抗战", "五四", "垄断",
    "投资", "有机构成", "资本划分", "生产工具", "货币本质",
    "平均利润", "超额利润", "革命首要问题",
]


def clean(text: str) -> str:
    return text.strip().strip("。；; ：:").replace("|", "／")


def split_topic(bullet: str):
    """返回 (topic, body)。topic 用于给短题干补上下文。"""
    colon = bullet.find("：")
    eq = bullet.find("＝")
    if colon >= 0 and (eq < 0 or colon < eq):
        return clean(bullet[:colon]), bullet[colon + 1 :]
    if eq >= 0:
        return clean(bullet[:eq]), bullet[eq + 1 :]
    semi = bullet.find("；")
    if semi >= 0:
        return clean(bullet[:semi]), bullet[semi + 1 :]
    return clean(bullet), ""


def contextualize(prompt: str, topic: str) -> str:
    prompt = clean(prompt)
    if not topic or not prompt:
        return prompt
    if prompt in topic or topic in prompt:
        return prompt if len(prompt) >= len(topic) else topic
    if len(prompt) <= 8 or prompt in GENERIC_PROMPTS:
        return f"{topic}：{prompt}"
    return prompt


def parse_true_false(clause: str):
    m = re.match(r"^(?P<stmt>.+?)＝(?P<val>错|对)(?:（[^）]*）)?$", clause)
    if m:
        return clean(m.group("stmt")), m.group("val") == "对", ""
    m = re.match(r"^(?P<stmt>.+?)（(?P<val>错|对)）$", clause)
    if m:
        return clean(m.group("stmt")), m.group("val") == "对", ""
    m = re.search(r"（“(?P<stmt>.+?)”＝(?P<val>错|对)）$", clause)
    if m:
        explanation = clean(clause[: m.start()])
        return clean(m.group("stmt")), m.group("val") == "对", explanation
    return None


def strip_correction(clause: str):
    m = re.match(r"^(?P<stmt>.+?)（应为(?P<fix>.+?)）$", clause)
    if m:
        return clean(m.group("stmt")), f"应为{clean(m.group('fix'))}"
    m = re.match(r"^(?P<stmt>.+?)（(?P<note>朝鲜例|原文如此)）$", clause)
    if m:
        return clean(m.group("stmt")), clean(m.group("note"))
    return clean(clause), ""


def take_mnemonic(answer: str):
    m = re.search(r"（“([^”]{1,16})”）$", answer)
    if m:
        return answer[: m.start()].strip(), m.group(1).strip()
    m = re.search(r"（口诀[:：]\s*([^）]{1,24})）$", answer)
    if m:
        return answer[: m.start()].strip(), m.group(1).strip()
    return answer, ""


def needs_round2(subject: str, chapter: str, prompt: str, answer: str) -> bool:
    text = prompt + answer
    if any(k in text for k in ROUND2_KEYWORDS):
        return True
    if subject == "史纲" and any(k in chapter for k in ("会议", "抗日战争", "易混", "专题")):
        return True
    return False


def make_mapping(subject, chapter, prompt, answer, mnemonic="", round2_hint="", drill=False):
    prompt = clean(prompt)
    answer = clean(answer)
    if not prompt or not answer:
        return None
    answer, found = take_mnemonic(answer)
    mnemonic = found or mnemonic
    parts = [f"[配对] {prompt} == {answer}"]
    if mnemonic:
        parts.append(f"口诀: {mnemonic}")
    line = " | ".join(parts)
    if needs_round2(subject, chapter, prompt, answer + round2_hint):
        line += " #二轮"
    if drill:
        line += " #配对"
    return line


def make_tf(subject, chapter, prompt, is_true, explanation):
    prompt = clean(prompt)
    if not prompt:
        return None
    words = [w for w in TOMBSTONE_WORDS if w in prompt]
    parts = [f"[{'对' if is_true else '错'}] {prompt}"]
    if explanation:
        parts.append(f"解析: {clean(explanation)}")
    if words and not is_true:
        parts.append("墓碑词: " + "，".join(words))
    line = " | ".join(parts)
    if needs_round2(subject, chapter, prompt, explanation):
        line += " #二轮"
    return line


def extract_blocks():
    lines = CORPUS.read_text(encoding="utf-8").splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith("# 三、一页纸内容"))
    end = next(i for i, l in enumerate(lines) if l.startswith("# 附录"))

    subject = None
    chapter = None
    blocks: "OrderedDict[str, OrderedDict[str, list[str]]]" = OrderedDict()
    skipped: list[tuple[str, str, str]] = []

    for raw in lines[start + 1 : end]:
        line = raw.rstrip()
        if line.startswith("## "):
            m = re.match(r"## (\d+)\.\s*(.+)", line)
            if m and m.group(1) in SUBJECT_BY_NUM:
                subject = SUBJECT_BY_NUM[m.group(1)]
                chapter = None
            continue
        if line.startswith("### "):
            chapter = line[4:].strip()
            continue
        if not line.startswith("- "):
            continue
        if subject is None:
            skipped.append(("?", "?", line))
            continue
        chapter_name = chapter or "未分章"
        blocks.setdefault(subject, OrderedDict()).setdefault(chapter_name, [])

        bullet = line[2:].strip()
        if bullet.startswith("例：") or bullet.startswith("例:"):
            skipped.append((subject, chapter_name, bullet))
            continue

        mode = None
        if bullet.startswith("常见错项："):
            mode = "wrong"
            bullet = bullet[len("常见错项：") :]
        elif bullet.startswith("看似生涩但正确的原话："):
            mode = "right"
            bullet = bullet[len("看似生涩但正确的原话：") :]

        topic, body = split_topic(bullet)
        clauses = [clean(c) for c in re.split(r"[；;]", bullet) if clean(c)]
        tf_clauses = [(c, parse_true_false(c)) for c in clauses]
        has_tf = any(tf is not None for _, tf in tf_clauses) or mode is not None

        if mode is not None or has_tf:
            for clause, tf in tf_clauses:
                if tf is None and mode in ("wrong", "right"):
                    prompt, explanation = strip_correction(clause)
                    tf = (prompt, mode == "right", explanation)
                if tf is not None:
                    item = make_tf(subject, chapter_name, *tf)
                    if item:
                        blocks[subject][chapter_name].append(item)
                    else:
                        skipped.append((subject, chapter_name, clause))
                elif "＝" not in clause:
                    # 正误段落里的非判断句多为上下文碎片，跳过，避免生成无意义卡片。
                    skipped.append((subject, chapter_name, clause))
                else:
                    prompt, answer = clause.split("＝", 1)
                    item = make_mapping(
                        subject, chapter_name,
                        contextualize(prompt, topic), answer,
                    )
                    if item:
                        blocks[subject][chapter_name].append(item)
                    else:
                        skipped.append((subject, chapter_name, clause))
            continue

        # 单一对应或纯列表：整条做成一张有上下文的卡，避免碎片题干。
        eq_count = bullet.count("＝")
        if eq_count <= 1:
            if eq_count == 1:
                prompt, answer = bullet.split("＝", 1)
                item = make_mapping(
                    subject, chapter_name,
                    contextualize(prompt, topic), answer,
                    drill=("；" not in bullet),
                )
            else:
                item = make_mapping(subject, chapter_name, topic, body or bullet)
            if item:
                blocks[subject][chapter_name].append(item)
            else:
                skipped.append((subject, chapter_name, bullet))
            continue

        # 多个对应：拆成带 topic 上下文的单条。
        unmapped = []
        for clause in clauses:
            if "＝" not in clause:
                unmapped.append(clause)
                continue
            prompt, answer = clause.split("＝", 1)
            item = make_mapping(
                subject, chapter_name,
                contextualize(prompt, topic), answer,
            )
            if item:
                blocks[subject][chapter_name].append(item)
            else:
                skipped.append((subject, chapter_name, clause))
        if unmapped and len("；".join(unmapped)) >= 20:
            item = make_mapping(
                subject, chapter_name,
                f"{topic}：其他要点", "；".join(unmapped),
            )
            if item:
                blocks[subject][chapter_name].append(item)
            else:
                skipped.append((subject, chapter_name, "；".join(unmapped)))
        elif unmapped:
            skipped.append((subject, chapter_name, "；".join(unmapped)))

    for subject, chapter, line in PAIRS:
        blocks.setdefault(subject, OrderedDict()).setdefault(chapter, []).append(line)

    return blocks, skipped


def main():
    blocks, skipped = extract_blocks()

    seen: dict[tuple[str, str], int] = {}
    deduped: list[tuple[str, str, str]] = []
    fixed = 0
    for subject in SUBJECT_ORDER:
        for chapter, items in blocks.get(subject, {}).items():
            for item in items:
                prefix = item.split("] ", 1)[1].split(" ==", 1)[0].split(" | ", 1)[0].strip()
                key = (subject, prefix)
                if key in seen:
                    fixed += 1
                    if item.startswith("[配对]"):
                        item = item.replace(f"{prefix} ==", f"{prefix}（{chapter}） ==", 1)
                    else:
                        item = item.replace(prefix, f"{prefix}（{chapter}）", 1)
                seen[key] = seen.get(key, 0) + 1
                deduped.append((subject, chapter, item))

    out: list[str] = []
    last_subject = None
    last_chapter = None
    for subject, chapter, item in deduped:
        if subject != last_subject:
            out.append(f"# {subject}")
            last_subject = subject
            last_chapter = None
        if chapter != last_chapter:
            out.append(f"## {chapter}")
            last_chapter = chapter
        out.append(f"- {item}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8")

    counts = Counter()
    type_counts = Counter()
    for subject, chapter, item in deduped:
        counts[subject] += 1
        if item.startswith("[配对]"):
            type_counts["mapping"] += 1
        elif item.startswith("[对]") or item.startswith("[错]"):
            type_counts["trueFalse"] += 1
        else:
            type_counts["pair"] += 1

    print(f"written {OUT}")
    print(f"items {len(deduped)}  {dict(counts)}  {dict(type_counts)}")
    print(f"deduped {fixed}  skipped {len(skipped)}")
    for subject, chapter, clause in skipped[:60]:
        print(f"SKIP\t{subject}\t{chapter}\t{clause}")


if __name__ == "__main__":
    main()
