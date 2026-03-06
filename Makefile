# 何を: 記事リポジトリの共通コマンドを提供する。なぜ: スキル検証と軽量チェックの入口を統一するため。

.PHONY: setup dev test lint format ci

setup:
	@echo "No additional setup configured for DIGILINE."

dev:
	@find .agents/skills -maxdepth 2 -name SKILL.md | sort

test:
	@pytest -q

lint:
	@python3 -m py_compile tests/test_skill_structure.py

format:
	@echo "No formatter configured for this repository."

ci: lint test
