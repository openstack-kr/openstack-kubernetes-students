# OpenInfra Lab Kit 가이드북 Sphinx 설정 (Markdown 원문, MyST 사용)
# 블라인드 심사 여부가 확인되기 전까지 소속/실명은 넣지 않는다.

project = "OpenInfra Lab Kit 가이드북"
author = "TBD"  # 블라인드 심사 여부 확인 후 결정
copyright = "2026, OpenInfra Lab Kit"
release = "v1.0"  # 제출 시점 저장소 태그와 일치시킬 것

language = "ko"

extensions = [
    "myst_parser",         # Markdown 원문을 Sphinx가 읽게 함
    "sphinx_external_toc", # 목차를 _toc.yml 로 관리 (index.md 에 Sphinx 전용 문법을 쓰지 않기 위함)
]
external_toc_path = "_toc.yml"

# `> [!NOTE]` 같은 GitHub 알림 상자를 Sphinx에서도 상자로 표시
myst_enable_extensions = ["alert", "colon_fence"]

source_suffix = {".md": "markdown"}
templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store", "README.md", "GIT_VSCODE_GUIDE.md"]

html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]
