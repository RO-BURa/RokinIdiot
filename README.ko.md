# RokinIdiot

[English](README.md) · **한국어**

VFX와 컷씬을 위한 로블록스 스튜디오 애니메이션 에디터 플러그인.

캐릭터 리그, 파티클, 속성 변화, 메소드 호출을 하나의 타임라인에서 같이
연출한다. 게임에서는 움직일 오브젝트만 넘기고 재생하면 된다.

```lua
const AnimationPlayer = require(ReplicatedStorage.RokinIdiotAnimationPlayer)

const track = AnimationPlayer:LoadAnimation(save, workspace.Hero, workspace.Villain)
track:Play(0.3)

track:GetMarkerReachedSignal("Impact"):Connect(function()
	hitbox:Fire()
end)
```

## 기능

**에디터**

- 아이템 → 엘리먼트 → 트랙 트리. Explorer의 아무 오브젝트에나 묶을 수 있다
- 속성 트랙 (number, Color3, CFrame, UDim2, NumberSequence, ColorSequence,
  EnumItem, Instance 참조 ...)
- `:Emit()` 같은 메소드 트랙. 인자는 키프레임마다 따로
- 리그 포즈: 뷰포트에서 자세를 잡고 모든 `Motor6D`를 한 번에 캡처
- 아이템 위치는 기준 아이템에 대한 상대값이라 어디서 틀어도 같은 연출
- 키프레임마다 이징 (TweenService의 모든 스타일 + `Linear`, `Constant`)
- 이름 붙은 키프레임과 마커. 런타임에서 신호로 받는다
- 스크럽·배속·반복이 되는 미리보기. 끄면 건드린 값이 전부 원래대로
- 키프레임을 고른 채로 Properties 패널에서 값을 바꾸면 키에 들어간다
- 여러 개 고르기 (Shift+드래그 / Shift+클릭), 끌어서 옮기기, 스냅, 확대
- 플레이스당 한 명만 편집 (Team Create용 잠금)
- 다크 / 라이트 테마, English / 한국어

**런타임** (`RokinIdiotAnimationPlayer`)

- 로블록스 `AnimationTrack`과 같은 모양: `Play`, `Stop`, 페이드, 비중,
  배속 (역재생 포함), 반복, `Stopped` / `Ended` / `DidLoop`
- 같은 오브젝트에 여러 애니메이션이 겹치면 우선순위와 비중으로 중재
- 멈추면 건드린 값을 원래대로 되돌린다
- 에디터 미리보기와 같은 계산 코드를 쓴다. 스튜디오와 게임 결과가 갈라지지 않는다

## 설치

[Rokit](https://github.com/rojo-rbx/rokit)으로 소스에서 빌드한다.

```bash
rokit install      # rojo, wally, stylua, luau-lsp
wally install      # 런타임 패키지
rojo build default.project.json --plugin RokinIdiot.rbxm
```

`--plugin`을 붙이면 스튜디오 플러그인 폴더에 바로 저장된다. 스튜디오를 다시
켜면 툴바에 **RokinIdiot** 버튼이 생긴다.

## 쓰는 법

1. 툴바에서 창을 열고 새 애니메이션을 만든다.
2. Explorer에서 오브젝트를 고르고 **+ Item**을 누르면 추가와 연결이 같이 된다.
3. 엘리먼트(아이템 아래 경로, 예: `HumanoidRootPart.RootAttachment.Sparks`)와
   트랙(`Enabled`, `Rate`, `:Emit()` ...)을 추가한다.
4. 스튜디오에서 값을 맞추고 키프레임을 찍는다. **Preview**를 켜면 바로 보인다.
5. **메뉴 → Workspace에 애니메이션 내보내기**로 게임에 넣을 `StringValue`를 얻는다.
6. **메뉴 → Workspace에 플레이어 내보내기**로 런타임 모듈을 얻는다.
   `ReplicatedStorage`로 옮기고 LocalScript에서 require한다.

애니메이션은 클라이언트에서 돌린다. `Motor6D.Transform`은 복제되지 않고,
서버에서 바꾼 속성은 프레임마다 복제된다.

## 문서

- 런타임 API — 내보낸 모듈 안의 `Docs`(영어), `Docs/한국어`
- [docs/RUNTIME.md](docs/RUNTIME.md) — 런타임 설계 메모
- [docs/PLAN.md](docs/PLAN.md) — 에디터 설계 메모

## 개발

```bash
stylua src                                             # 포맷
rojo sourcemap default.project.json -o sourcemap.json  # luau-lsp용
rojo build animationPlayer.project.json -o RokinIdiotAnimationPlayer.rbxm  # 런타임만
```

`src/Core`는 에디터와 런타임이 같이 쓴다. 두 빌드 모두에 붙어서 미리보기와
게임이 같은 코드로 돈다.

## 앞으로

- 본 마스킹 (상체만 우리 애니메이션, 다리는 기본 걷기 유지)
- 이징 곡선 에디터
- 스튜디오 `Ctrl+Z`로 실행 취소 / 다시 실행

## 라이선스

[MIT](LICENSE)
