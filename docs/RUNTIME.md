# 런타임 패키지 — API

게임 안에서 저장된 애니메이션을 재생하는 쪽. 에디터와 `Core/`를 **같은 소스로**
공유한다. 스튜디오에서 본 것과 게임에서 도는 것이 갈라지면 안 된다.

만들어져 있다. 이 문서가 그 API다.

---
## 쓰는 모습

```lua
const AnimationPlayer = require(ReplicatedStorage.RokinIdiotAnimationPlayer)

const track = AnimationPlayer:LoadAnimation(save, character, sword)
track.Looped = true
track:Play(0.3)

track:GetMarkerReachedSignal("Impact"):Connect(function()
	hitbox:Fire()
end)
```

`save`로 받는 것:

- 내보낸 `StringValue` (Export Animation to Workspace가 만드는 것)
- 그걸 담고 있는 `Folder` / `Model` — 안에서 StringValue를 찾는다
- JSON 문자열 자체

아이템은 **자리 = 아이템 Id**로 이어서 넘긴다. Id에 구멍이 있으면 (2번을
지워서 1, 3만 남은 경우) 표로 넘긴다. 두 번째 인자가 Instance면 앞의 방식,
table이면 뒤의 방식으로 읽는다.

```lua
AnimationPlayer:LoadAnimation(save, character, sword)
AnimationPlayer:LoadAnimation(save, { [1] = character, [3] = sword })
```

에디터의 Bindings 폴더는 미리보기 전용이라 런타임에는 오지 않는다.
여기서 넘긴 것이 실제로 움직인다.

---

## 서비스

```lua
AnimationPlayer:LoadAnimation(save, ...) -> Track
AnimationPlayer:GetPlayingTracks() -> { Track }
AnimationPlayer:StopAll(fadeTime?)
```

옵션 표는 따로 받지 않는다. 만들어진 트랙의 속성을 고치면 된다. 어차피
`Looped`나 `Speed`는 재생 중에도 바꿀 수 있어야 해서 속성이어야 한다.

```lua
const track = AnimationPlayer:LoadAnimation(save, character)
track.Looped = true
track.Priority = 5        -- 문서에 적힌 값을 덮어쓴다
track.Restore = false     -- 멈춰도 원래 값으로 안 돌린다
track.FireMarkers = false -- 마커 신호를 울리지 않는다
track:Play(0.3)
```

require는 이미 만들어진 서비스 하나를 돌려준다. 여럿을 만들면 중재자가
갈라져서 우선순위가 서로를 못 본다.

## Track

`RobloxStyleObject`를 상속하므로 **로블록스의 AnimationTrack처럼 속성으로**
읽고 쓴다. 속성에 대입하면 `Changed`와 `GetPropertyChangedSignal`이 울린다.

```lua
-- 속성
track.Animation     : StringValue   -- 이 트랙이 재생 중인 저장 값
track.IsPlaying     : boolean
track.Length        : number        -- 초
track.Looped        : boolean
track.Priority      : number        -- 문서에 적힌 값으로 시작한다
track.Speed         : number
track.TimePosition  : number
track.WeightCurrent : number        -- 지금 비중
track.WeightTarget  : number        -- 가고 있는 목표 비중

track.MissingItems  : { number }    -- 인스턴스를 못 받은 아이템 Id (우리 것)
track.Restore       : boolean       -- 멈출 때 원래 값으로 돌릴지 (기본 true)
track.FireMarkers   : boolean       -- 마커 신호를 울릴지 (기본 true)

-- 메소드
track:AdjustSpeed(speed: number?)
track:AdjustWeight(weight: number?, fadeTime: number?)
track:GetMarkerReachedSignal(name: string): Signal
track:GetTimeOfKeyframe(name: string): number?
track:Play(fadeTime: number?, weight: number?, speed: number?)
track:Stop(fadeTime: number?)
track:Destroy()

-- 신호
track.DidLoop           -- 반복이 한 바퀴 돌았다
track.KeyframeReached   -- (name: string) 이름 붙은 시점을 지났다
track.Stopped           -- 재생이 끝났다 (아직 페이드아웃 중일 수 있다)
track.Ended             -- 페이드아웃까지 끝나 더는 아무것도 안 건드린다
```

`Stopped` → `Ended` 순서다. 로블록스 AnimationTrack이 이렇게 정의돼 있다 —
`Stopped`는 재생이 끝난 순간, `Ended`는 페이드아웃이 끝나고 대상이 원래
모습으로 돌아간 순간이다. 페이드가 없으면 둘이 이어서 울린다.

`GetMarkerReachedSignal`은 같은 이름으로 부르면 같은 Signal을 돌려준다.
없는 이름으로 불러도 만들어 준다 — 마커를 나중에 추가할 수 있어야 한다.

`GetTimeOfKeyframe`은 그 이름의 키프레임이 없으면 `nil`을 돌려준다.
로블록스는 오류를 던지지만, 애니메이션은 나중에 고쳐질 수 있는 데이터라
이름 하나 때문에 게임 로직이 멈추는 편이 더 나쁘다.

`KeyframeReached`는 로블록스에서 deprecated지만 실제로는 동작하고, 우리는
`Keyframe`이 곧 이름 붙은 시점이라 뜻이 분명하다. 그래서 그대로 둔다.

로블록스에 있지만 **넣지 않는 것**: `GetParameter` / `SetParameter` /
`GetParameterDefaults`. 로블록스 문서에 시그니처만 있고 무엇에 쓰는지가
한 줄도 없다. 우리 문서에는 파라미터라는 개념 자체가 없다.

---

## 키프레임과 마커

로블록스의 `Keyframe` / `KeyframeMarker`와 같은 짜임새다.

**키프레임**은 이름 붙은 시점이다. 트랙마다 찍는 값 키(다이아몬드)와는 다른
것이다. 값 키는 트랙에 딸리고, 키프레임은 문서 전체에 딸린다.

**마커**는 키프레임 안에 들어간다. 한 키프레임에 여러 개 넣을 수 있다.
이게 마커를 키프레임 안에 넣는 이유다 — 같은 시점에 "타격"과 "발소리"를
동시에 울려야 하는 경우가 실제로 있다.

```lua
keyframes = {
    { t = 0.5, name = "Impact", markers = { { name = "Hit" }, { name = "Sound" } } },
    { t = 1.2, name = "Step",   markers = {} },
}
```

- 한 시점에 키프레임은 하나다. 줄이 하나뿐이라 겹치면 하나가 가려진다
- 키프레임 하나에 마커는 여러 개다
- 마커가 없는 키프레임도 된다. `GetTimeOfKeyframe`으로 시점만 찾는 용도

재생헤드가 키프레임을 지나면 이 순서로 울린다.

1. `KeyframeReached` — 키프레임 이름으로 한 번
2. `GetMarkerReachedSignal(마커이름)` — 그 키프레임 안의 마커마다 한 번

값 키의 메소드 호출과 같은 규칙이다. `(지난 시점, 지금 시점]` 구간이고
앞으로 갈 때만 울린다. 되감을 때 다시 울리면 소리가 두 번 난다.

우선순위나 비중과는 무관하다. 상태가 아니라 사건이라 그대로 울린다.

---

## 여럿이 겹칠 때

한 프레임에 이렇게 돈다.

1. 재생 중인 트랙마다 시간과 비중을 밀고, 값을 **계산만** 한다
2. 계산한 값을 `(인스턴스, 속성)`마다 모은다 (claim)
3. 모인 것을 중재해서 **한 번만 쓴다**

### 우선순위가 먼저

`(인스턴스, 속성)`마다 **숫자가 큰 쪽만 남는다.** 진 쪽은 그 프레임에 아무
일도 하지 않는다. 우선순위는 트랙 단위이지 속성 단위가 아니다.

### 남은 것들끼리 비중으로 섞는다

같은 우선순위가 여럿이면 값 타입에 따라 갈린다.

**섞을 수 있는 타입** (number, CFrame, Color3, Vector3 ... `Value.lerp`가 있는 것):

```
total = Σ w
total >= 1 이면   Σ(w · v) / total
total <  1 이면   Σ(w · v) + (1 - total) · 원래값
```

비중이 모자란 만큼은 **오브젝트의 원래 값**이 채운다. 그래야 트랙 하나를
0.3초에 걸쳐 페이드인할 때 원래 모습에서 자연스럽게 넘어온다. 모자란 자리를
정규화로 메우면 (로블록스가 그러는 것으로 보인다) 비중 0.1에서도 이미 온전한
애니메이션이 되어 페이드가 눈에 보이지 않는다.

**섞을 수 없는 타입** (boolean, string, EnumItem, Instance):

절반 켜진 파티클 같은 건 없다. 그래서 **비중이 1에 닿은 트랙만** 값을 넣고,
그런 트랙이 여럿이면 **먼저 재생을 시작한 쪽**이 가져간다.

페이드 중에는 값이 아직 안 들어간다. 페이드아웃 중에도 마지막까지 값을 들고
있다가 0에 닿을 때 놓는다. 뚝 끊기지만 그게 이 타입들에 맞는 동작이다
(키프레임의 Constant 이징과 같은 생각).

### 메소드와 마커는 중재하지 않는다

상태가 아니라 사건이다. 우선순위가 낮아도, 비중이 0.2여도 그 지점을 지나면
호출되고 울린다. 비중은 "얼마나 섞을까"인데 `:Emit()`을 0.2번 부를 수는 없다.

---

## fadeTime

비중이 목표까지 **일정한 속도로(Linear)** 기어가는 시간이다.

```lua
track:Play(0.3)              -- 0.3초에 걸쳐 비중 0 -> 1
track:AdjustWeight(0.5, 0.2) -- 0.2초에 걸쳐 지금 비중 -> 0.5
track:Stop(0.3)              -- 0.3초에 걸쳐 -> 0, 닿으면 정말로 멈춘다
```

`fadeTime`이 0이면 그 자리에서 바로 목표 비중이 된다.

`Stop(fadeTime)`은 값을 즉시 놓지 않는다. `Stopped`는 바로 울리지만, 비중이
0에 닿아야 `Ended`가 울리고 그때 원복이 일어난다. 페이드아웃 도중에도
`IsPlaying`은 참이다.

---

## 멈추면 원래대로 돌린다

건드린 값은 트랙이 멈출 때 되돌린다. 파티클 `Enabled`를 켜놓고 끝나버리면
그 자리에 계속 남는다.

되돌릴 값은 **그 속성을 아무 트랙이든 처음 건드린 순간**에 적어둔 값이다.
두 트랙이 같은 속성을 건드렸다면 먼저 온 쪽이 적어둔 값이 진짜 원래 값이다.
그래서 적어두는 곳은 트랙이 아니라 중재자다.

지는 쪽이 멈출 때는 원복하지 않는다. 이긴 쪽이 그 값을 들고 있다. 아무도
그 속성을 claim하지 않게 된 프레임에만 원래 값으로 돌아간다.

---

## 아이템이 비면 그냥 무시한다

`LoadAnimation(save, character)` 만 넘겼는데 문서에 2번 아이템이 있으면,
2번을 쓰는 트랙은 그냥 빠진다. 에러도 경고도 없다 — 일부러 하나만 넘기고
쓰는 경우가 있고, 그때마다 출력창이 더러워지면 안 된다.

빠진 번호는 `track.MissingItems`에 남는다. 궁금할 때만 보면 된다.

---

## 어디서 돌릴까

**클라이언트를 권한다.** 서버에서도 돌아가지만 두 가지가 다르다.

- 속성 변경이 **전부 복제된다.** 파티클 하나를 프레임마다 바꾸면 그게 그대로
  네트워크 트래픽이다. 보는 사람이 많을수록 비싸진다
- `Motor6D.Transform`은 **아예 복제되지 않는다.** 리그 포즈는 서버에서
  돌려도 다른 사람에게 보이지 않는다

그래서 리그가 들어간 컷씬은 클라이언트에서 돌려야 하고, 서버 재생은 보는
사람이 적거나 값이 드물게 바뀌는 연출에서나 쓸 만하다.

서버가 "지금 이 컷씬 틀어" 하고 알리는 건 게임 쪽 몫이다. 패키지는 리모트를
들고 있지 않는다. 필요하면 나중에 얇은 브로드캐스트 계층을 얹는다.

같은 값은 다시 쓰지 않는다 (`Arbiter`가 쓰기 전에 확인한다). 서버에서 돌릴
때는 이게 그대로 아낀 트래픽이 된다.


## 준비 작업 (완료)

### `Core/Applier` 분리

값을 실제로 꽂는 절반을 [`Core/Applier`](../src/Core/Applier.luau)로 뺐다.
`Sampler`가 "t초에 값이 얼마인가"까지 답하고, `Applier`가 그 값을 쓴다.
종류별 적용(property / method / motor6d / transform), 경로 캐시, 같은 값 건너뛰기,
Origin 기준 상대 위치 환산이 전부 여기 있다.

`Applier`는 재생을 모른다. 시간을 받아 그 시점을 칠할 뿐이다. 스냅샷·원복·
재생·정지는 부르는 쪽이 맡는다. 부르는 쪽은 host 표 하나를 채워 넘긴다.

```lua
Applier.new({
    GetDocument, ResolveItem, OriginCFrame,
    Remember, BaseValue, RestoreProperty, OnWrite,
})
```

에디터의 `Preview/Player`는 이제 이 host를 채우는 일과 스냅샷·선택 비켜두기만
한다. 런타임 Track도 같은 자리에 자기 host를 끼우면 된다.

### `Core`가 플러그인을 모르게

`Locale`이 `PluginEnv`를 직접 require하던 것을 끊었다. 이제 접근자를 받는다.

```lua
Locale.Init(PluginEnv.GetSetting, PluginEnv.SetSetting)  -- init.server에서
```

아무도 `Init`을 부르지 않으면 기본 언어(영어)로 그냥 돈다. 런타임에서는 오류
문구 몇 개에만 쓰이므로 그걸로 충분하다. 이걸 안 끊으면 `Core`를 게임에 넣는
순간 없는 `Plugin/PluginEnv`를 찾다가 터진다.

### `Debug` 기본 꺼짐

`Debug.Enabled`가 기본 `false`다. 재는 곳이 프레임마다 도는 자리(Sampler,
Applier)에 있어서, 게임에서까지 표를 건드리면 아무도 안 보는 통계에 값을
치르게 된다. 에디터만 `init.server`에서 켠다.

### 빌드 두 갈래, 소스 한 벌

```
default.project.json          src/Plugin + src/Core + 그 안에 RokinIdiotAnimationPlayer
animationPlayer.project.json  RokinIdiotAnimationPlayer 단독
```

`Core`와 `Packages`는 **두 빌드 모두에서** 플레이어 모듈의 자식으로 붙는다.
그래서 플레이어 코드는 어느 쪽에서 열리든 `script.Core` / `script.Packages`로
찾으면 된다.

플러그인 빌드에는 `Core`가 두 벌 들어간다 (플러그인 뿌리에 하나, 플레이어
안에 하나). 소스는 한 벌이므로 갈라지지 않고, 이렇게 해야 Workspace로 꺼낸
플레이어 폴더가 그 자체로 완결된다. 파일 크기는 190KB 남짓 늘어난다.

### Export Player to Workspace

메뉴 → `Workspace에 플레이어 내보내기`. 플러그인 안의 플레이어 폴더를 그대로
복제해 Workspace에 놓고 선택한다. 원본은 건드리지 않는다 — 옮겨버리면 다음에
꺼낼 게 없다. 쓰는 사람은 이걸 ReplicatedStorage 같은 곳으로 옮겨 require한다.
