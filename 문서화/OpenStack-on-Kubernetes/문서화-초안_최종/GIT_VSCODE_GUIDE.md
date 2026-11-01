# VS Code로 커밋하고 GitHub에 올리기

이미 저장소를 내려받아(clone) VS Code로 열었고, **작업용 브랜치도 만들어 둔 상태**를 가정합니다.
(Windows는 `Ctrl`, Mac은 `Cmd` 로 읽으세요.)

## 용어 세 가지

| 용어 | 뜻 |
|---|---|
| 커밋 (commit) | 바뀐 파일들을 **내 컴퓨터 안에** 한 묶음으로 저장하는 것. 아직 GitHub에는 안 올라갑니다. |
| 푸시 (push) | 내 컴퓨터의 커밋을 **GitHub로 올리는 것**. |
| 브랜치 (branch) | 작업 갈래. 내 브랜치에서 작업하면 `main` 을 건드리지 않습니다. |

흐름은 항상 **파일 수정 → 스테이지(담기) → 커밋 → 푸시** 입니다.

## 0. 처음 한 번만

1. Git이 설치되어 있는지 확인합니다. VS Code 터미널(`` Ctrl+` ``)에서 `git --version` 을 입력해 버전이 나오면 됩니다. 안 나오면 [git-scm.com](https://git-scm.com) 에서 설치한 뒤 VS Code를 다시 켭니다.
2. 커밋에 찍힐 이름과 이메일을 정합니다.

   ```bash
   git config --global user.name "표시할 이름"
   git config --global user.email "숫자ID+깃허브아이디@users.noreply.github.com"
   git config --global core.quotepath false
   ```

   > [!WARNING]
   > **커밋 기록에는 이름과 이메일이 영구히 남고, 저장소를 공개하면 누구나 봅니다.**
   > 블라인드 심사 여부가 확인되기 전까지는 실명과 학교·회사 메일을 쓰지 마세요.
   > GitHub 설정(Settings → Emails)에서 `Keep my email addresses private` 를 켜고, 그 화면에 나오는
   > `...@users.noreply.github.com` 주소를 이메일로 쓰면 됩니다. 이미 커밋한 뒤에 바꾸면 이전 커밋은 그대로 남습니다.

   마지막 줄(`core.quotepath`)은 한글 파일 이름이 `\355\225...` 처럼 깨져 보이는 것을 막습니다.

## 1. 파일 넣기

1. 이 폴더(가이드북)를 저장소 안의 원하는 위치에 복사합니다. 예: `문서화/OpenStack-on-Kubernetes/가이드북/`
2. **저장소에 이미 있는 `.gitignore` 는 덮어쓰지 마세요.** 같이 드린 `gitignore-append.txt` 의 내용을 기존 `.gitignore` **맨 아래에 붙여 넣기만** 합니다.
3. `LICENSE`, `tox.ini`, `doc/` 는 건드리지 않습니다.

## 2. 지금 어느 브랜치인지 확인

VS Code **왼쪽 아래 상태 표시줄**에 브랜치 이름이 보입니다. 내가 만든 브랜치가 아니면 그 이름을 클릭해서 내 브랜치를 선택합니다.
(`main` 에 바로 커밋하지 않도록 꼭 확인하세요.)

## 3. 올리기 전에 점검 (중요)

1. 왼쪽 막대의 **소스 제어** 아이콘(가지 모양)을 누릅니다. (`Ctrl+Shift+G`) 바뀐 파일 목록이 보입니다. 파일을 클릭하면 바뀐 줄이 색으로 보입니다.
2. 아래 항목이 문서에 들어 있지 않은지 **전체 검색**(`Ctrl+Shift+F`)으로 확인합니다.
   - 서버의 공인 IP 주소, 개인 컴퓨터 이름
   - `token`, `password`, `BEGIN ... PRIVATE KEY`
   - 팀원 실명, 소속
3. 아래 파일이 목록에 **없어야** 합니다. 있으면 올리지 말고 `.gitignore` 를 확인하세요.
   - `terraform.tfstate`, `.terraform/`, `tfplan*`
   - `logs/`, `.bash_history`, `history-backup-*.txt`
   - `admin.conf`, `kubeconfig*`, `.kube/`, `id_*` (개인키)

> [!WARNING]
> **한 번 GitHub에 올라간 비밀(키, 토큰, IP)은 파일을 지워도 커밋 기록에 남습니다.**
> 실수로 올렸다면 혼자 지우려 하지 말고 팀에 알려서 키를 새로 발급받으세요.

## 4. 스테이지 → 커밋

1. 소스 제어 화면의 **변경 사항(Changes)** 줄 위에 마우스를 올리고 **`+`** (모든 변경 사항 스테이지)를 누릅니다. 파일이 **스테이징된 변경 사항** 으로 올라갑니다. (일부만 올리려면 파일 옆의 `+` 를 누릅니다.)
2. 위쪽 **메시지** 칸에 무엇을 했는지 적습니다.

   ```text
   docs: 0~4단계 가이드북 초안 추가
   ```

   > [!NOTE]
   > 메시지는 "무엇을 왜 바꿨는지"를 한 줄로 씁니다. 예: `docs: 4단계 스토리지 설정과 오류 항목 보강`, `fix: 1단계 AppArmor 해결 절차 수정`.

3. **커밋** 버튼(또는 `Ctrl+Enter`)을 누릅니다.
   "스테이징된 변경 사항이 없습니다. 모든 변경 사항을 커밋할까요?" 라고 물으면 **예** 를 눌러도 됩니다.

## 5. 푸시 (GitHub로 올리기)

- 이 브랜치를 **처음** 올릴 때는 소스 제어 화면에 **브랜치 게시(Publish Branch)** 버튼이 보입니다. 누르고, 저장소 이름(`origin`)을 선택합니다.
- 이미 올린 브랜치라면 **변경 내용 동기화(Sync Changes)** (위아래 화살표) 버튼을 누릅니다.
- GitHub 로그인 창이나 브라우저가 열리면 **로그인하고 허용(Authorize)** 합니다. 토큰이나 비밀번호를 파일에 적지 마세요.

터미널로 하면 같은 일입니다. (`<브랜치>` 는 상태 표시줄의 이름)

```bash
git status                                  # 바뀐 파일 확인
git add 문서화/OpenStack-on-Kubernetes/가이드북   # 담기
git commit -m "docs: 0~4단계 가이드북 초안 추가"  # 커밋
git push -u origin <브랜치>                   # 처음 한 번
git push                                    # 다음부터
```

## 6. GitHub에서 확인하고 합치기

1. 브라우저에서 GitHub 저장소를 엽니다. 푸시 직후에는 위에 **`Compare & pull request`** 버튼이 뜹니다.
2. 눌러서 제목과 설명을 쓰고 **Pull request 만들기**. 팀원이 확인한 뒤 `main` 에 합칩니다.
3. 가이드북 파일이 의도한 폴더에 보이고, 표와 알림 상자가 제대로 나오는지 눈으로 확인합니다.

> [!NOTE]
> 저장소는 **비공개(Private)** 로 시작하고, 블라인드 심사 여부를 확인한 뒤에 공개로 바꾸는 것을 권합니다.

## 7. 다음부터 반복

```text
작업 시작 전: 소스 제어 → "변경 내용 동기화"(풀) 로 팀원 변경을 먼저 받는다
→ 파일 수정 → 저장 → 변경 사항 확인 → + → 메시지 → 커밋 → 푸시
```

## 막혔을 때

| 증상 | 원인 | 해결 |
|---|---|---|
| `Author identity unknown` | 이름과 이메일 미설정 | 0번의 `git config` 두 줄을 실행 |
| `rejected ... non-fast-forward` | 다른 사람이 먼저 올림 | 먼저 `git pull` (또는 Sync Changes)로 받은 뒤 다시 푸시 |
| `Permission denied` / `403` | 저장소 쓰기 권한 없음 | 저장소 관리자에게 Collaborator로 추가 요청 |
| 병합 충돌(Conflict) 표시 | 같은 줄을 둘이 고침 | VS Code의 **병합 편집기**에서 `현재 변경 / 수신 변경 / 둘 다` 중 선택 후 저장, 스테이지, 커밋 |
| 한글 경로가 `"\355\225..."` 로 보임 | quotepath | `git config --global core.quotepath false` |
| 푸시한 파일이 안 보임 | 다른 브랜치를 보고 있음 | GitHub 화면 왼쪽 위 브랜치 선택에서 내 브랜치로 바꿈 |
| 올리면 안 되는 파일을 스테이지함 | 실수 | 스테이징된 변경 사항에서 그 파일 옆 `-` 를 눌러 되돌림 (커밋 전이면 안전) |
