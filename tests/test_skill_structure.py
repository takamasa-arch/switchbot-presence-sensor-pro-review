"""何を: 追加したスキルの基本構造を検証する。なぜ: SKILL.md と参照ガイドの欠落や frontmatter 崩れを早期に検出するため。"""

import re
from pathlib import Path


def test_gadget_blog_skill_files_exist() -> None:
    root = Path(__file__).resolve().parents[1]
    skill_dir = root / ".agents" / "skills" / "gadget-blog-article-best-practices"

    assert (skill_dir / "SKILL.md").exists()
    assert (skill_dir / "agents" / "openai.yaml").exists()
    assert (skill_dir / "references" / "style-guide.md").exists()


def test_gadget_blog_skill_frontmatter_is_populated() -> None:
    root = Path(__file__).resolve().parents[1]
    skill_md = (
        root
        / ".agents"
        / "skills"
        / "gadget-blog-article-best-practices"
        / "SKILL.md"
    ).read_text(encoding="utf-8")

    # 何を: YAML パーサーに依存せず frontmatter を点検する。なぜ: 最小環境でも make test を通せるようにするため。
    match = re.match(r"^---\n(.*?)\n---", skill_md, re.DOTALL)
    assert match is not None

    frontmatter = match.group(1)
    assert "name: gadget-blog-article-best-practices" in frontmatter
    assert "description:" in frontmatter
    assert "[TODO:" not in skill_md
