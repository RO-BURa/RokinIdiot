# RokinIdiot — 특수 애니메이션 에디터 플러그인 설계

## 개요

VFX/컷씬 중심의 로블록스 스튜디오 특수 애니메이션 에디터 플러그인.
일반 캐릭터 애니메이션뿐 아니라 **파티클, 속성 변화, 메소드 호출**을 하나의
타임라인에서 같이 연출하고, 게임에서는 아이템만 대입해서 재생한다.

```lua
local track = RokinIdiotAnimationPlayerService:PlayAnimation(saveValue, {
    [1] = workspace.Hero,
    [2] = workspace.Villain,
})
track.Speed = 1.5
track:Play()
```

## 확정된 설계 결정

| 항목 | 결정 |
|---|---|
| UI 스택 | 순수 Instance + OOP 클래스 (외부 의존성 0) |
| 리그 저작 | 뷰포트에서 직접 포즈 → `Key` 버튼으로 캡처 (Moon Animator 방식) |
| 리그 데이터 | `Motor6D.Transform` 키프레임 (C0/C1 미변경) |
| 재생 위치 | 클라이언트 로컬 재생. 서버는 신호만 브로드캐스트 |
| 아이템 위치 | Origin Item 기준 상대 CFrame |
| 대상 리그 | 컷씬 전용 리그 + 플레이어 캐릭터 둘 다 |
| 바인딩 | 엘리먼트 경로는 `a.b.c` 문자열, 아이템은 `ObjectValue` |
| 보간 | 보간 가능한 타입은 이징 곡선, 나머지는 스텝 |
| fps | 프로젝트별 사용자 지정 |
| 스냅 단위 | 프레임 수로 지정, 기본 2f. 키와 재생헤드가 이 격자에 붙는다 |
| 키 편집 | 우클릭 메뉴 + Edit Keyframe 모달 (상시 인스펙터 없음) |
| 동시 편집 | 플레이스당 1명 (하트비트 잠금) |
| 언어 | English / 한국어. 기본 English, 플러그인 설정에 저장 |

## 저장 구조

```
ServerStorage.RokinIdiotAnimationSaves
 ├─ _Lock                 (StringValue) 편집 잠금 정보
 └─ MyCutscene            (StringValue) Value = 애니메이션 JSON
      └─ Bindings         (Folder)
           ├─ 1           (ObjectValue → workspace.Character1)
           └─ 2           (ObjectValue → workspace.Rig)
```

런타임은 `StringValue.Value`만 읽는다. `Bindings`는 스튜디오 미리보기 전용이라
게임에서는 자연스럽게 무시된다.

`Export Animation to Workspace`는 `Bindings`까지 같이 내보낸다. 작업을 다른
플레이스로 옮길 때 아이템 연결이 따라가야 하기 때문이다. 이때 폴더를 `Clone`
하면 안 된다 — ObjectValue가 가리키는 대상이 복사 범위 밖이라 참조가 끊긴다.
새 ObjectValue를 만들어 `Value`를 직접 넣어야 한다.

### 가져오기

내보낸 StringValue를 다른 플레이스로 들고 왔을 때의 반대 방향 길이다.
홈 화면이 Explorer 선택을 지켜보다가, 고른 것이

- `StringValue` 이고
- `Value`가 우리 스키마(`schemaVersion` + `items` + `tracks`)로 읽히고
- 저장 폴더 밖에 있으면

가져오기 안내를 띄운다. 저장하기를 누르면 저장 폴더로 **복사**한다.
원본은 그대로 둔다 — 부모를 옮기면 사용자가 놓아둔 자리가 사라진다.

## 프로젝트 스키마 (v3)

```lua
{
    schemaVersion = 3,
    name          = "MyCutscene",
    fps           = 30,     -- 타임라인 눈금
    snapUnit      = 2,      -- 키가 붙는 간격, 프레임 단위
    duration      = 5,      -- 초
    priority      = 0,      -- 그냥 숫자. Enum.AnimationPriority가 아니다
    originItemId  = 1,      -- 아이템 위치의 절대 기준
    nextItemId    = 3,
    items = {
        { id = 1, name = "Character1", kind = "rig" },   -- rig | object
        { id = 2, name = "Character2", kind = "rig" },
    },
    tracks = {
        {
            itemId    = 1,
            path      = "HumanoidRootPart.RootAttachment.MainParticle",
            kind      = "property",         -- property | method | motor6d | transform
            target    = "Enabled",
            valueType = "boolean",
            keys = {
                { t = 0.0, v = false },
                { t = 0.5, v = true, ease = { "Sine", "Out" } },
            },
        },
        {
            itemId = 1,
            path   = "HumanoidRootPart.RootAttachment.MainParticle",
            kind   = "method",
            target = "Emit",
            keys   = { { t = 0.5, args = { 25 } } },
        },
    },
    keyframes = {
        { t = 0.5, name = "Impact", markers = { { name = "Hit" }, { name = "Sound" } } },
        { t = 1.2, name = "Step", markers = {} },
    },
}
```

### 엘리먼트 표기 파싱

사용자가 직접 입력한다.

- `Enabled` → 속성 트랙 (`kind = "property"`)
- `:Emit()` → 메소드 트랙 (`kind = "method"`, target = `Emit`)
- 판정: 문자열이 `:`로 시작하고 `)`로 끝나면 메소드, `:` 와 `(` 사이가 이름
- 표기 안의 인자는 무시되고, **인자는 키프레임마다 인스펙터에서 편집**한다
  (`:Emit()` 트랙에서 키 A는 5개, 키 B는 20개 방출)

### Instance 값

`Adornee`, `PrimaryPart`, `Attachment0` 처럼 인스턴스를 값으로 갖는 속성은
절대 경로로 저장할 수 없다. 게임에서는 매번 다른 인스턴스가 들어오기 때문이다.
그래서 **아이템 번호 기준**으로 적는다. 아이템 대입 규칙을 그대로 재사용한다.

```
(빈 칸) 또는 nil   →  값 없음
[2]                →  2번 아이템 자신
[2].Handle.Tip     →  2번 아이템 아래 경로
```

실제 인스턴스로 바뀌는 건 미리보기와 런타임이 대입 테이블을 들고
`PathSpec.resolveInstanceRef`를 부를 때다.

### 속성 범위 (하드코딩)

로블록스는 속성의 허용 범위를 스크립트로 알려주지 않는다. `Transparency`가
0~1이라는 걸 알려면 적어두는 수밖에 없다. `Core/PropertySpec`에 클래스별로
모아두고, 여기 적힌 속성은 키를 고르면 바로 아래에 슬라이더가 뜬다.

새 속성을 추가하려면 그 파일에 한 줄 적으면 된다.

### 값 타입

속성 트랙을 만들 때 타입을 직접 고를 수 있다. 기본값 `(Auto)`는
바인딩된 인스턴스의 현재 값을 읽어서 정한다. 바인딩이 없거나 지원하지 않는
타입이면 `number`로 떨어진다.

### 트랙 종류

- `property` — 값 보간. 타입별로 이징 or 스텝
- `method` — 시점 이벤트. 재생헤드가 키를 통과할 때 1회 호출
- `motor6d` — 리그 관절. `path`가 Motor6D를 가리키고 값은 `Transform` CFrame
- `transform` — 아이템 루트의 월드 위치. Origin Item 기준 상대 CFrame

## 모듈 구조

디스크 배치와 만들어지는 트리가 다르다. `Core`는 소스에서 한 곳에 있고,
프로젝트 파일이 그걸 두 빌드에 각각 붙인다.

```
src/
  Core/                     ← 에디터와 런타임이 함께 쓴다
    Signal.luau             경량 이벤트
    Maid.luau               정리 헬퍼
    Schema.luau             스키마 정의 / 새 프로젝트 / 마이그레이션
    Project.luau            문서 모델 + Undo 스택 + 변경 알림
    Ops.luau                문서를 고치는 모든 것 (Commit 안에서만 부른다)
    Outline.luau            문서 → 한 줄짜리 행 목록 (두 패널이 공유)
    PathSpec.luau           "a.b.c" 해석, ":Emit()" 파싱
    Value.luau              타입별 직렬화 / 보간
    Easing.luau             키 사이를 잇는 방식
    Sampler.luau            t 시점의 값·이벤트·마커  ← 에디터와 런타임이 공유
    Applier.luau            그 값을 실제 인스턴스에 꽂는 절반  ← 공유
    RigResolver.luau        Motor6D 그래프 탐색
    Reflection.luau         ReflectionService 감싸기 (에디터에서만 쓴다)
    PropertySpec.luau       속성 목록·범위 (에디터에서만 쓴다)
    Locale.luau             언어 전환 + 변경 알림 + T(key, ...)
    Strings/                En.luau, Ko.luau  (키는 두 파일이 동일)
  Plugin/
    init.server.luau        툴바 + DockWidget 부트스트랩
    Plugin/
      PluginEnv.luau        plugin 객체 보관
      Store.luau            저장 / 로드 / 목록 / 바인딩 / 내보내기
      Lock.luau             단독 편집 잠금 (하트비트)
      Recents.luau          최근 작업 목록
    UI/
      Theme.luau            테마 전환 + 변경 알림
      Style/Dark.luau, Light.luau
      Component.luau        컴포넌트 베이스 클래스
      Components/           Button, Menu, Dialog
      App.luau              화면 전환
      Screens/              HomeScreen, EditorScreen
      Editor/               TopBar, ElementTree, Timeline, KeyEditor, ...
    Preview/
      Player.luau           재생 / 스크럽 / 원복 스냅샷 (Applier의 host)
  RokinIdiotAnimationPlayer/
    init.luau               게임에서 쓰는 서비스
    RokinIdiotAnimationTrack.luau
    Docs/                   init.luau(영어), 한국어.luau
```

만들어지는 트리:

```
RokinIdiot (플러그인)          RokinIdiotAnimationPlayer (게임에 넣는 것)
├ Core                        ├ Core          ← 같은 소스
├ Plugin                      ├ Packages
├ UI                          ├ Docs
├ Preview                     └ RokinIdiotAnimationTrack
└ RokinIdiotAnimationPlayer
  ├ Core     ← 같은 소스
  └ Packages
```

플러그인 빌드에 `Core`가 두 벌 들어간다. 소스는 한 벌이라 갈라지지 않고,
이렇게 해야 Workspace로 꺼낸 플레이어 폴더가 그 자체로 완결된다.

다만 **두 벌은 서로 다른 모듈 인스턴스**다. 플러그인이 자기 `Core.Debug`를
켜도 플레이어 안의 `Core.Debug`는 꺼진 채다. 지금은 플러그인이 플레이어를
require하지 않고 복제만 하므로 문제가 없다.

핵심은 `Core/Sampler`와 `Core/Applier`를 **에디터 미리보기와 런타임이 공유**하는 것.
스튜디오에서 본 결과와 게임에서의 결과가 갈라질 수 없다.

## 기술 노트

### Motor6D.Transform

관절의 회전 델타. 부모 뼈 기준 상대값이라 어느 위치에서 재생하든 동일하다.
`C0`/`C1`은 건드리지 않으므로 리그를 다시 만들거나 스케일을 바꿔도 안 깨진다.
Animator 없이도 직접 쓰면 즉시 반영된다.

**복제되지 않는다.** 그래서 재생은 각 클라이언트가 로컬로 수행한다.
서버는 "재생해" 신호만 쏘고 계산은 클라이언트가 한다 (대역폭 ~0, 렉 없음).

### 포즈 캡처

스튜디오 편집 모드에서는 뷰포트에서 파트를 옮겨도 `Motor6D.Transform`이
따라 바뀌지 않는다. 그래서 파트가 놓인 자리에서 관절 값을 되계산한다.

```
Part1.CFrame = Part0.CFrame * C0 * Transform * C1:Inverse()
Transform    = (Part0.CFrame * C0):Inverse() * Part1.CFrame * C1
```

덕분에 "뷰포트에서 팔을 돌린 다음 키를 찍는다"가 그대로 성립한다.
반대로 재생할 때는 `Transform`만 써주면 파트가 따라 움직인다.

### Animator 충돌

플레이어 캐릭터처럼 Animator가 살아있는 리그에 입힐 때는
`BindToRenderStep`을 `Enum.RenderPriority.Character.Value + 1`로 잡아
기본 Animator보다 나중에 덮어쓴다.

### 보간

`TweenService:Create`를 쓰지 않는다. 타임라인 스크럽·역재생·Speed 변경·
일시정지가 전부 필요하므로 매 프레임 "지금 t초의 값"을 계산한다.
이징 곡선만 `TweenService:GetValue(alpha, style, direction)`로 빌려 쓰므로
결과는 Tween과 동일하다.

보간 가능: number, Vector3, Vector2, Color3, CFrame, UDim2, NumberRange
스텝: boolean, string, Enum, 그 외

### 0초와 첫 키 사이

오브젝트가 **원래 갖고 있던 값이 0초의 암묵적인 키**처럼 동작한다.
0초부터 첫 키까지는 그 값에서 첫 키 값으로 곧게(Linear) 이어진다.

```
원래 Transparency 0,  1.0초에 키 1  →  0.5초에 0.5
```

첫 키 값을 그대로 물려버리면 0.5초에 켜지는 파티클이 0초부터 켜져 있게 된다.
시작 값을 직접 정하고 싶으면 0초에 키를 하나 찍으면 된다.

이 구간은 언제나 Linear다. 키의 `ease`는 "그 키에서 다음 키로" 가는 방식을
뜻하므로 첫 키 앞 구간에는 적용할 이징이 없다.

보간이 안 되는 타입은 `Value.lerp`가 앞 값을 유지하므로 첫 키에 닿기 전까지
원래 값이 그대로 남는다. `Enabled` 같은 것에는 그게 맞는 동작이다.

이징 이름은 `Core/Easing`에 모아둔다. TweenService의 EasingStyle에 두 개를 더한다.

- `Linear` — 곧게 이음 (기본값. 저장 파일에는 아예 안 적는다)
- `Constant` — 잇지 않고 다음 키에 닿을 때까지 앞 키 값을 유지

`Easing.apply(ease, alpha)`가 진행도에 곡선을 입힌다. `Constant`는 0을 돌려주므로
보간하면 앞 키 값이 그대로 남는다. 샘플러는 이 함수만 부르면 된다.

### 미리보기 안전장치

재생 전에 건드릴 모든 속성을 스냅샷하고, 정지·에러·위젯 닫힘 시 원복한다.
미리보기는 `ChangeHistoryService`에 기록하지 않는다 (문서 편집만 기록).

## 구현 단계

1. ~~위젯 / 홈 / Recent / 저장·잠금 / 테마 / TopBar~~ 완료
2. ~~아이템 / 엘리먼트 / 트랙 트리 + 타임라인~~ 완료
   - [x] 아이템 추가·이름변경·Id 변경·삭제, Explorer 선택으로 바인딩, Origin 지정
   - [x] 엘리먼트 추가·경로수정·삭제
   - [x] 트랙 추가·삭제 (`:Emit()` / `Enabled` 파싱, 값 타입 선택 + 자동 추론)
   - [x] 눈금자 / 재생헤드 / 스냅 단위 / 길이·fps / Ctrl+휠 확대 / 좌우 행 정렬
   - [x] 키프레임 찍기·옮기기(겹침 금지)·지우기, 우클릭 메뉴
   - [x] Edit Keyframe 창 (시간, 값, 이징, 메소드 인자, Capture)
   - [x] 속성 범위를 아는 것들은 키 아래 슬라이더로 바로 편집
   - [x] 다른 플레이스에서 가져오기 / 내보내기
3. 미리보기 재생 + Motor6D 포즈 캡처  ← 현재
   - [x] `Core/Sampler` — t 시점의 값·이벤트 계산 (에디터와 런타임이 공유)
   - [x] 재생 컨트롤 (Preview 토글, Play/Stop, 배속, 반복)
   - [x] 미리보기 전 스냅샷 → 끄거나 닫을 때 원복
   - [x] `motor6d` 트랙 + 뷰포트 포즈 캡처 (`Capture Rig Pose`)
   - [x] `transform` 트랙 (Origin Item 기준 상대 위치, `Capture Position`)
   - [ ] 본 마스킹, 스크럽 중 메소드 호출 여부 옵션
4. 런타임 패키지 분리

## 나중에

- 본 마스킹 (상체만 우리 애니메이션, 하체는 기본 걷기 유지)
- 곡선 에디터 (이징을 그래프로)

### 문구 (Locale)

UI에 보이는 글은 전부 `Core/Strings/En.luau` / `Ko.luau`의 키를 거친다.
`Locale.T(key, ...)`는 인자가 있으면 `string.format`까지 해준다.
키가 없으면 영어로, 영어에도 없으면 키를 그대로 돌려주므로 문구 하나가
빠져도 화면이 비지 않는다.

지켜야 할 것 두 가지.

- **인자 순서는 언어마다 같아야 한다.** `string.format`에는 자리 번호가
  없어서 순서를 바꿀 방법이 없다. 어순이 안 맞으면 문장을 다시 쓴다.
- **`PluginEnv`와 `Signal`의 문구는 번역하지 않는다.** `Locale`이 이 둘을
  require하고 있어서 반대로 걸면 require가 순환한다. 둘 다 버그일 때만
  보이는 글이라 영어로 적어둔다.

만들 때 한 번 넣고 마는 글자(라벨, 버튼)는 언어를 바꿔도 그대로 남는다.
`Component:BindLocale(apply)`로 다시 넣는다. `BindTheme`과 같은 모양이고,
등록 즉시 한 번 호출되므로 화면이 다 서기 전에 부르면 안 되는 갱신은
`built` 플래그로 첫 호출을 건너뛴다.

성능 기록(`Debug`)의 이름은 집계 키라서 번역하지 않고 그대로 모으고,
출력할 때 `report()`에서만 `Locale.T`를 태운다. 언어를 바꿔도 통계가
둘로 갈라지지 않는다.

툴바 버튼 툴팁만은 예외다. 플러그인이 뜰 때 한 번 만들어지므로 언어를
바꿔도 스튜디오를 다시 켜야 바뀐다.

### 엘리먼트 트리 겹침

엘리먼트는 문서에 `a.b.c` 문자열로 평평하게 들어 있지만, 화면에서는
경로가 겹치는 것끼리 접어서 보여준다. `Frame` 과 `Frame.UIStroke` 가 둘 다
있으면 UIStroke는 Frame 안에 들어가고 이름도 `UIStroke` 만 남는다.

부모는 **내 경로의 앞부분이면서 가장 긴 엘리먼트**다. 중간 단계가 엘리먼트로
없으면 (`Frame` 없이 `Frame.UIStroke` 만 있을 때) 그 자리에 줄을 만들지 않고
남은 경로를 통째로 이름에 쓴다. 없는 줄을 만들어봐야 눌러도 할 게 없다.

빈 경로(`""`)는 부모로 치지 않는다. 그건 아이템 자신이고 그 줄은 이미 위에
아이템으로 있다. 부모로 삼으면 접었을 때 그 아이템의 모든 줄이 같이 사라진다.

부모를 접으면 트랙뿐 아니라 하위 엘리먼트도 같이 접힌다.

### 우선순위 (priority)

`Enum.AnimationPriority`가 아니라 그냥 정수다. 에디터는 창에서 받아 문서에
적어두기만 하고 아무 데도 쓰지 않는다. 여러 애니메이션이 겹칠 때 어느 쪽을
위에 둘지는 재생하는 쪽이 이 숫자를 보고 정한다.

숫자로 둔 이유는 Enum이면 다섯 단계밖에 없어서다. VFX는 같은 단계 안에서도
순서를 갈라야 할 때가 있다.

### 키프레임 (keyframes) 과 마커

로블록스의 `Keyframe` / `KeyframeMarker`와 같은 짜임새다.

**키프레임**은 이름 붙은 시점이다. 트랙마다 찍는 값 키(다이아몬드)와는 다른
것이다 — 값 키는 트랙에 딸리고 값을 갖고, 키프레임은 문서 전체에 딸리고
이름과 마커를 갖는다.

**마커**는 키프레임 안에 들어간다. 한 키프레임에 여러 개 넣을 수 있다.
이게 마커를 키프레임 안에 넣은 이유다 — 같은 지점에서 "타격"과 "발소리"를
함께 울려야 하는 경우가 실제로 있는데, 예전처럼 마커 자체가 시점이면
한 자리에 하나뿐이라 그게 안 된다.

에디터는 기록만 한다. 지날 때 무슨 일을 할지는 재생하는 쪽이 정한다
(`Sampler.keyframesBetween`이 구간을 알려준다).

값 키와 규칙이 같다.

- 한 시점에 키프레임은 하나다. 줄이 하나뿐이라 겹치면 하나가 가려진다
- 끌어서 옮길 때 다른 키프레임이 앉은 자리에는 못 놓지만 지나가는 건 된다
- 길이를 줄이면 밖으로 나간 키프레임은 지워진다

키프레임 줄은 눈금자 바로 밑, 행 목록 위에 있다. 문서 하나에 딸린 것이라 행과
같이 스크롤하지 않는다. 왼쪽 패널에는 같은 높이의 `KEYFRAMES` 이름표만 둔다
(`Metrics.MARKER_HEIGHT`).

딱지에는 키프레임 이름을 쓰고, 마커를 들고 있으면 개수를 뒤에 붙인다
(`Impact (2)`). 마커를 넣고 빼는 건 딱지 우클릭 메뉴에서 한다. 메뉴에 하위
메뉴가 없어서 마커 하나를 한 줄씩 편다.

### 키프레임 여러 개 고르기

레인 위에서 **Shift+드래그**하면 사각형을 그려 그 안의 키를 모두 고른다.
**전에 고르던 것은 그대로 두고 얹는다.** 사각형은 Shift로만 열리니 여기서
갈아치우면 여러 번에 나눠 고를 방법이 없어진다. 새로 시작하려면 빈 곳을
그냥 클릭한다.

키 위에서 **Shift+클릭**하면 그 키를 골라둔 것에 더하고, 이미 골라둔 키면 뺀다.
키 위에서 시작한 Shift는 사각형이 아니다 — 눌렀다 뗄 때까지 기다려야 클릭인지
드래그인지 갈리는데, 그동안 아무 반응이 없으면 눌린 건지 알 수가 없다.

줄이 적어서 스크롤이 없을 때 그 아래 빈 자리에서도 사각형이 시작된다.
레인 버튼이 안 깔린 곳이라 클릭이 스크롤 프레임까지 온다.
사각형 좌표는 캔버스 기준으로 잡는다. 끄는 동안 목록이 스크롤될 수 있어서
화면 좌표로 잡아두면 사각형이 내용과 따로 논다.

고른 것 중 아무 키나 우클릭하면 그 묶음을 다루는 메뉴가 뜬다.

- `Delete Selected (N)` — 한 번의 Commit으로 전부 지운다
- `Edit Selected... (N)` — 타입이 전부 같을 때만 나온다
- `Deselect`

"타입이 같다"는 판단은 `EditorState:MultiFramesShareType`이 한다. 트랙 종류가
같아야 하고, 속성이면 값 타입과 Enum 종류까지, 메소드면 메소드 이름까지 같아야
한다. 메소드는 인자가 대상마다 다른 뜻이라 이름이 다르면 한 값을 넣을 수 없다.

여럿을 고치는 창은 `KeyEditor.openMulti`가 연다. 값과 이징만 받고 **시간 칸은
아예 없앤다.** 서로 다른 시간에 있는 키들이라 한 값으로 맞출 수가 없고, 맞춰봐야
전부 한 자리에 겹친다.

여럿 골라둔 동안에는 `GetSelectedFrame()`이 nil이라 아래 편집 바(QuickEdit)가
접힌다. 그 바는 값 하나를 전제로 만들어져 있다. 하나만 골리면 평범한 선택으로
넘겨서 편집 바가 그대로 뜬다.

레인의 왼쪽 클릭 판단은 `InputBegan` 한 곳에서만 한다. `MouseButton1Down`과
나눠 쓰면 어느 쪽이 먼저 오는지에 기대게 되는데 그 순서는 보장되지 않는다.

### 키프레임 줄 끄기

옵션 → `키프레임 줄 보이기` (기본 켜짐). 끄면 그 줄이 사라지고 행 목록이 그만큼
위로 올라온다. 두 패널이 `Metrics.topHeight(showMarkers)`를 같이 쓰므로 좌우가
어긋나지 않는다.

설정은 프로젝트가 아니라 플러그인 설정에 넣는다 (`UI/Editor/ViewOptions`).
저장 파일을 남과 주고받아도 이 값은 따라가지 않는다 — 사람에 딸린 취향이다.

### 머리말 배치

```
왼쪽 패널                          오른쪽 패널
┌ ELEMENTS          [+ Item] ┐ ┌ 1.93s / 5.00s  frame 58   Enabled = true   [우선순위 확대 스냅 길이 fps] ┐
├ [Preview][Play][배속][반복] ┤ ├ 눈금자 ──────────────────────────────────────────────────────────┤
├ KEYFRAMES                   ┤ ├ 키프레임 줄                                                      ┤
└ 행 목록                     ┘ └ 레인                                                             ┘
```

미리보기 조작 버튼은 **왼쪽 눈금자 자리**에 있다. 원래 행 시작 위치를 맞추려고
비워둔 띠였다. 버튼을 만드는 건 재생기를 들고 있는 타임라인이고, 자리는 트리가
`RulerSlot`으로 내주고 `EditorScreen`이 둘을 이어준다.

버튼 줄은 `RulerSpacer` 안에 한 겹(`TransportSlot`)을 더 두고 거기 담는다.
구분선까지 같은 부모에 두면 줄 세우기에 딸려 들어가 버튼 옆에 서 버린다.

오른쪽 머리말 가운데는 **고른 키프레임 이야기**다.

- 아무것도 안 골랐으면 비어 있다. 늘 무언가 떠 있으면 읽지 않게 된다
- 하나면 `Enabled = true` 처럼 값을 보여준다 (메소드는 `Emit(25)`)
- 둘 이상이면 개수만. 값이 서로 달라 하나로 보여줄 수가 없다

### 값 키의 이름과 마커

트랙 위 다이아몬드(값 키)에도 이름과 마커를 붙일 수 있다. 우클릭 메뉴에서
`Name Keyframe...` 과 `Add Marker...` 로 넣는다. 이름이 붙었거나 마커를 든
키는 다이아몬드 위에 작은 표가 선다 — 그게 없으면 이름을 지어놓고도 어느
키에 지었는지 알 수가 없다.

이름을 비우면 이름이 떨어진다. 마커는 같은 이름을 한 키에 둘 넣을 수 없다.
신호는 이름으로 받으므로 둘이면 같은 신호가 두 번 울릴 뿐이다.

저장 파일에는 붙였을 때만 남는다 (`name`, `markers`가 없으면 필드 자체가
없다). 이름 없는 키가 대부분인데 빈 값이 키마다 붙으면 읽기만 어려워진다.

**이름 붙은 것이 두 군데에 있다.** 값 키에 붙인 것과, 키프레임 줄에 값 없이
시점만 찍어둔 것. 재생하는 쪽에서는 둘을 구분할 이유가 없어서
`Sampler.keyframesBetween`이 한 목록으로 합쳐서 돌려준다.

둘을 나눠 둔 이유는 쓰임이 다르기 때문이다. 값 키의 이름은 "이 동작이
일어나는 순간"에 붙이는 것이고, 키프레임 줄은 값과 상관없이 시점만 표시하고
싶을 때 쓴다.

### 값 리터럴 (Core/Literal)

메소드 인자는 칸마다 타입이 다를 수 있는데 알려줄 사람이 없다. 그래서 적은
글에서 타입을 알아낸다.

```
25,  true,  "글자",  nil,  Vector3(1,2,3),  Enum.Material.Neon,  [2].Handle
```

따옴표 없는 낱말도 문자열로 봐준다. 인자로 이름을 넘기는 일이 흔한데 매번
따옴표를 강요하면 성가시기만 하다. 대신 `25`나 `true`를 **글자로** 넣고 싶을
때는 따옴표가 필요하므로 입력 칸의 안내에 예시를 적어둔다.

읽은 결과는 타입을 달고 있는 상자다.

```lua
args = { { t = "number", v = 25 }, { t = "nil" }, { t = "Vector3", v = { 1, 2, 3 } } }
```

**상자로 담는 이유는 저장이 JSON이기 때문이다.** 배열 한가운데를 nil로 비우면
길이를 믿을 수 없게 되어 뒤의 인자가 통째로 사라진다. 모든 칸이 표면 구멍이
생기지 않는다.

호출할 때는 상자를 풀어 `table.unpack(args, 1, args.n)`으로 **개수를 명시해서**
넘긴다. 푼 뒤에는 가운데가 진짜 nil이라 `#`로 센 길이는 거기서 끊긴다.

### 색 미리보기

`Color3`, `BrickColor`, `ColorSequence` 트랙은 키프레임 마름모를 그 색으로
칠한다. 숫자를 읽는 것보다 색을 보는 편이 빠르다. 고른 키는 강조색으로 덮는다
— 어느 게 골라졌는지가 더 급한 정보다.

편집 창에서는 값 칸 왼쪽에 견본을 세우고 Capture할 때마다 갱신한다.
`ColorSequence`는 글로 "키포인트 3개"밖에 못 보여주므로 여기서는 이 견본이
유일한 단서다. 색이 여럿이라 하나로 줄이면 그라디언트인지도 알 수 없어서,
견본에 `UIGradient`를 얹고 값을 그대로 꽂는다. 실제 모양이 그대로 보인다.

마름모는 8px에 45도로 돌아가 있어 그라디언트를 넣어봐야 알아볼 수 없다.
거기서는 가운데 색 하나만 쓴다.

### 속성을 고치면 골라둔 키에 받아 적는다

키를 고른 채로 스튜디오 Properties에서 그 속성을 만지면, 고친 값이 골라둔
키 전부에 들어간다. 색이나 숫자는 패널에서 만지작거리며 맞추는 게 자연스러운데,
맞춰놓고 다시 Capture를 누르러 가는 건 손이 한 번 더 가는 일이다.

켜지는 조건은 넷이다.

- **미리보기가 켜져 있을 것**. 꺼져 있을 때 스튜디오에서 오브젝트를 그냥
  만지면 골라둔 키가 따라 바뀌면 안 된다
- 골라둔 키가 **전부 같은 트랙**일 것 (`EditorState:GetSelectedTrack`).
  섞여 있으면 어느 속성을 받아 적어야 할지 알 수 없다
- **속성 트랙**일 것. 메소드는 값이 없고, 리그 관절과 위치는 편집 모드에서
  속성이 바뀌지 않아 (되계산해서 찍는다) 들을 것이 없다
- **미리보기가 쓴 값이 아닐 것**. 재생 중이거나 `Player:IsApplying()`이면
  건너뛴다. 우리가 쓴 값까지 받아 적으면 재생헤드가 지나갈 때마다 골라둔
  키가 제 값을 잃는다.
  속성 변경 이벤트는 Deferred라 쓰고 한참 뒤에 온다. 그래서 `IsApplying`은
  값을 쓸 때 1을 더하고, `task.defer`를 두 번 거친 뒤 1을 뺀다. defer는
  이미 큐에 들어간 이벤트들 뒤에 줄을 서므로 그 이벤트가 오는 동안 켜져 있다.
  한 프레임에 여러 번 쓰면 먼저 내린 쪽이 뒤 이벤트를 놓치므로 불리언이 아니라 숫자다

여럿을 골랐으면 한 번의 Commit으로 전부에 같은 값이 들어간다.

### 고른 키로 재생헤드 이동 (옵션, 기본 켜짐)

옵션 → `고른 키프레임으로 재생헤드 이동`. 키를 고르면 재생헤드가 그 자리로
간다. 고른 키의 값을 보려면 어차피 그 시점을 봐야 해서 대개는 따라가는 게
맞지만, 다른 시점을 보면서 키를 고르고 싶을 때가 있어 끌 수 있게 뒀다.

두 경우에는 따라가지 않는다.

- **여럿 골랐을 때** — 어느 키로 가야 할지 정할 수 없고, 사각형으로 훑을
  때마다 재생헤드가 튀면 성가시다
- **재생 중** — 재생헤드는 지금 흐르고 있는 중이다

### 재생헤드를 옮기면 선택 해제 (옵션, 기본 꺼짐)

옵션 → `재생헤드를 옮기면 키프레임 선택 해제`. 눈금자·키프레임 줄·재생헤드
손잡이로 재생헤드를 옮길 때 키 선택을 풀지 정한다. 기본은 풀지 않는다 —
키를 골라둔 채로 재생헤드를 끌며 앞뒤 모습을 확인하는 게 자연스럽다.

트랙 줄의 빈 자리를 누르는 건 여기에 해당하지 않는다. 그건 "키 바깥을 누른
것"이라 늘 선택이 풀린다.
