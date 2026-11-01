# OpenInfra Lab Kit 가이드북 (Markdown)

0~4단계 수동 구축을 바탕으로 쓴 가이드북 원문입니다. GitHub에서는 그대로 읽히고, Sphinx(MyST)로 빌드하면 웹 문서가 됩니다.

## 읽는 순서

[index.md](index.md) 의 목차를 따르세요. 용어가 어려우면 [부록 C. 용어집](appendix_glossary.md) 을 먼저 보세요.

## 파일 구성

| 파일 | 내용 |
|---|---|
| `index.md` | 목차 |
| `overview.md` | 개요, 전체 흐름, 읽는 법 |
| `ch0_prerequisites.md` ~ `ch4_prereqs.md` | 0~4단계 (작성됨) |
| `ch5_openstack.md`, `ch6_verify.md` | 5~6단계 (구축 전, 뼈대) |
| `ch7_troubleshooting.md` | 실제로 겪은 오류 모음 |
| `appendix_versions.md` | 버전 표 (`versions.env`, 논문과 일치해야 함) |
| `appendix_manual_refs.md` | 수동 수행 기준 문서 |
| `appendix_glossary.md` | 용어집 |
| `GIT_VSCODE_GUIDE.md` | VS Code로 커밋하고 GitHub에 올리는 방법 |
| `conf.py`, `_toc.yml`, `Makefile`, `requirements.txt` | Sphinx 빌드용 (문서 내용과 무관) |

## Sphinx로 빌드

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
make html                        # 결과: _build/html/index.html (Windows는 sphinx-build -b html . _build/html)
```

`make html` 은 경고를 오류로 처리합니다(`-W`). 링크가 깨졌거나 문법이 틀리면 빌드가 실패합니다.

## 작성 규칙

- **알림 상자**는 GitHub 문법을 씁니다. Sphinx에서도 같은 상자로 보입니다.

  ```markdown
  > [!NOTE]
  > 참고 내용

  > [!WARNING]
  > 꼭 읽어야 하는 주의 내용
  ```

- **미완성 부분**은 `> [!NOTE]` 상자 안에 `**TODO:**` 로 시작하게 씁니다. 제출 전에 전체 검색(`TODO:`)으로 모두 해소하세요.
- 서버 공인 IP, 개인 컴퓨터 이름, 토큰, 개인키, 팀원 실명은 문서에 쓰지 않습니다. 접속 주소는 `<서버 주소>` 로 표기합니다.
- 도구와 버전은 [appendix_versions.md](appendix_versions.md) 와 일치해야 합니다.
- 파일 사이 링크는 `[0단계](ch0_prerequisites.md)` 처럼 상대 경로로 씁니다.
