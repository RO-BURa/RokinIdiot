# RokinIdiot

VFX / 컷씬 중심의 로블록스 스튜디오 특수 애니메이션 에디터 플러그인.

일반 캐릭터 애니메이션뿐 아니라 파티클, 속성 변화, 메소드 호출을 하나의
타임라인에서 같이 연출하고, 게임에서는 아이템만 대입해서 재생한다.

```lua
local track = RokinIdiotAnimationPlayerService:PlayAnimation(saveValue, {
    [1] = workspace.Hero,
    [2] = workspace.Villain,
})
track:Play()
```

설계 문서는 [docs/PLAN.md](docs/PLAN.md) 참고.

## 개발

플러그인 빌드:

```bash
rojo build --plugin asdf.rbxm
```

포맷과 정적 분석:

```bash
stylua src
```

```bash
rojo sourcemap default.project.json -o sourcemap.json
```

## 구현 현황

- [x] 1단계 — 위젯 / 홈 / Recent / 저장·잠금 / 테마 / TopBar
- [~] 2단계 — 아이템·엘리먼트·트랙 트리와 타임라인 (키프레임 편집 남음)
- [ ] 3단계 — 미리보기 재생 + Motor6D 포즈 캡처
- [ ] 4단계 — 런타임 패키지 분리
