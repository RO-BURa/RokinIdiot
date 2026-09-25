--!nonstrict
-- 한국어 문구. 키는 En과 같아야 한다.
-- 빠진 키는 Locale이 영어로 메우니 UI가 비어 보이지는 않는다.

return {
	-------------------------------------------------------------------------
	-- 공통
	-------------------------------------------------------------------------
	["common.ok"] = "확인",
	["common.cancel"] = "취소",
	["common.delete"] = "삭제",
	["common.none"] = "(없음)",
	["common.root"] = "(루트)",
	["common.itemRoot"] = "(아이템 루트)",

	-------------------------------------------------------------------------
	-- 되돌리기 기록에 남는 이름
	-------------------------------------------------------------------------
	["undo.addItem"] = "아이템 추가",
	["undo.renameItem"] = "아이템 이름 변경",
	["undo.deleteItem"] = "아이템 삭제",
	["undo.setItemId"] = "아이템 Id 변경",
	["undo.setItemClass"] = "아이템 종류 갱신",
	["undo.setOrigin"] = "기준 아이템 변경",
	["undo.addTrack"] = "트랙 추가",
	["undo.deleteTrack"] = "트랙 삭제",
	["undo.deleteElement"] = "엘리먼트 삭제",
	["undo.setPath"] = "경로 변경",
	["undo.setValueType"] = "값 타입 변경",
	["undo.addKey"] = "키프레임 추가",
	["undo.editKey"] = "키프레임 수정",
	["undo.moveKey"] = "키프레임 이동",
	["undo.moveKeys"] = "키프레임 여러 개 이동",
	["undo.deleteKey"] = "키프레임 삭제",
	["undo.deleteKeys"] = "키프레임 여러 개 삭제",
	["undo.editKeys"] = "키프레임 여러 개 수정",
	["undo.clearKeys"] = "키프레임 전체 삭제",
	["undo.setKeyValue"] = "키프레임 값 변경",
	["undo.setKeyValues"] = "키프레임 여러 개 값 변경",
	["undo.setKeyName"] = "키프레임 이름 지정",
	["undo.capturePose"] = "리그 포즈 캡처",
	["undo.capturePosition"] = "위치 캡처",
	["undo.setPriority"] = "우선순위 변경",
	["undo.putKeyframe"] = "키프레임 지정",
	["undo.moveKeyframe"] = "키프레임 이동",
	["undo.deleteKeyframe"] = "키프레임 삭제",
	["undo.clearKeyframes"] = "키프레임 전체 삭제",
	["undo.addMarker"] = "마커 추가",
	["undo.removeMarker"] = "마커 삭제",
	["undo.setSnap"] = "스냅 단위 변경",
	["undo.setDuration"] = "길이 변경",
	["undo.setFps"] = "fps 변경",

	-------------------------------------------------------------------------
	-- 앱 전체
	-------------------------------------------------------------------------
	["app.tooltip"] = "특수 애니메이션 에디터 열기",
	["app.namePlaceholder"] = "이름",
	["app.nameTaken"] = "'%s' 라는 작업이 이미 있습니다.",
	["app.createFailed"] = "만들지 못했습니다",
	["app.openFailed"] = "열지 못했습니다",
	["app.saveFailed"] = "저장하지 못했습니다",
	["app.exportFailed"] = "내보내지 못했습니다",
	["app.playerMissing"] = "플러그인 안에 '%s' 가 없습니다. 빌드가 온전하지 않은 것 같습니다.",
	["app.deleteTitle"] = "작업 삭제",
	["app.deleteMessage"] = "'%s' 작업을 삭제합니다. 되돌릴 수 없습니다.",
	["app.unsavedTitle"] = "저장하지 않은 변경사항",
	["app.unsavedMessage"] = "'%s' 에 저장하지 않은 변경사항이 있습니다.",
	["app.saveAndClose"] = "저장 후 닫기",
	["app.closeWithoutSaving"] = "저장하지 않고 닫기",
	["app.lockLostTitle"] = "편집 권한을 잃었습니다",
	["app.lockLostMessage"] = "%s 님이 편집을 시작해서 '%s' 작업이 닫혔습니다. 저장되지 않은 변경사항은 사라졌습니다.",
	["app.lockedTitle"] = "다른 사용자가 편집 중입니다",
	["app.lockedMessage"] = "%s 님이 이 플레이스에서 RokinIdiot을 사용 중입니다.\n"
		.. "동시에 편집하면 미리보기가 서로 겹쳐서 작업이 꼬입니다.\n\n"
		.. "그래도 열려면 편집 권한을 가져와야 합니다.",
	["app.takeOver"] = "권한 가져오기",

	-------------------------------------------------------------------------
	-- 로비 화면
	-------------------------------------------------------------------------
	["home.subtitle"] = "특수 애니메이션 에디터",
	["home.recentTitle"] = "마지막으로 하던 작업",
	["home.empty"] = "아직 만든 작업이 없습니다.\n오른쪽 위 New Animation으로 시작하세요.",
	["home.neverOpened"] = "열어본 적 없음",
	["home.justNow"] = "방금 전",
	["home.minutesAgo"] = "%d분 전",
	["home.hoursAgo"] = "%d시간 전",
	["home.daysAgo"] = "%d일 전",
	["home.foreignSelection"] = "이 플레이스에 없는 작업이 선택되어 있습니다.",
	["home.saveSelection"] = "저장하기",
	["home.importRenamed"] = "'%s' 라는 작업이 이미 있습니다. 다른 이름으로 저장합니다.",
	["home.importFailed"] = "가져오지 못했습니다",
	["home.lockedBy"] = "%s 님이 편집 중입니다. 열면 권한을 가져올지 물어봅니다.",

	-------------------------------------------------------------------------
	-- 상단 바
	-------------------------------------------------------------------------
	["topbar.menu"] = "메뉴",
	["topbar.language"] = "언어",
	["topbar.theme"] = "테마",
	["topbar.options"] = "옵션",
	["topbar.export"] = "Workspace에 애니메이션 내보내기",
	["topbar.exportPlayer"] = "Workspace에 플레이어 내보내기",
	["topbar.followSelection"] = "고른 키프레임으로 재생헤드 이동",
	["topbar.deselectOnScrub"] = "재생헤드를 옮기면 키프레임 선택 해제",
	["topbar.showMarkers"] = "키프레임 줄 보이기",
	["topbar.deselectWhilePlaying"] = "재생 중 선택 해제",

	-------------------------------------------------------------------------
	-- 왼쪽 트리 (아이템 / 엘리먼트 / 트랙)
	-------------------------------------------------------------------------
	["tree.empty"] = "아이템이 없습니다.\n\n"
		.. "Explorer에서 모델을 고르고 + Item 을 누르면\n"
		.. "그 모델이 아이템으로 등록됩니다.",
	["tree.noBinding"] = "바인딩 없음 (미리보기 불가)",
	["tree.sharedBinding"] = "-> %s  (%s번과 겹침)",
	["tree.bindFailedTitle"] = "바인딩할 수 없습니다",
	["tree.bindFailedMessage"] = "Explorer에서 오브젝트를 하나만 선택한 뒤 다시 시도하세요.",
	["tree.addItemMessage"] = "Explorer에서 오브젝트를 하나 선택한 채로 누르면 이름과 바인딩이 자동으로 채워집니다.",
	["tree.nameEmpty"] = "이름을 입력하세요.",
	["tree.itemNameTaken"] = "'%s' 라는 아이템이 이미 있습니다.",
	["tree.idMessage"] = "런타임에서 PlayAnimation에 넘기는 대입 번호입니다.\n"
		.. "이미 쓰는 번호를 넣으면 그 아이템과 서로 맞바뀝니다.",
	["tree.idPlaceholder"] = "번호",
	["tree.integerRequired"] = "정수를 입력하세요.",
	["tree.idRange"] = "1에서 999 사이여야 합니다.",
	["tree.pathPlaceholder"] = "경로",
	["tree.pathMessage"] = "아이템 루트 기준 경로를 적으세요. 비워두면 아이템 자신을 가리킵니다.",
	["tree.pathNoBinding"] = "바인딩이 없어 경로를 확인할 수 없습니다.",
	["tree.pathMissing"] = "지금 바인딩에는 '%s' 가 없습니다. 그래도 추가할 수 있습니다.",
	["tree.pathFound"] = "지금 바인딩에서 확인됨.",
	["tree.pathTaken"] = "이미 추가된 경로입니다.",
	["tree.addTrackFirstTitle"] = "Add Element — 첫 트랙",
	["tree.addTrackMessage"] = "속성은 그대로 (Enabled), 메소드는 앞에 콜론 (:Emit()).\n"
		.. "괄호 안 인자는 무시되고 키프레임마다 따로 넣습니다.",
	["tree.targetPlaceholder"] = ":Emit()  또는  Enabled",
	["tree.valueTypeLabel"] = "값 타입",
	["tree.enumTypeLabel"] = "Enum 종류",
	["tree.trackMissing"] = "지금 바인딩(%s)에는 '%s' 가 없습니다. 그래도 추가할 수 있습니다.",
	["tree.notMethod"] = "'%s' 는 메소드가 아닙니다. 콜론을 빼면 속성으로 잡힙니다.",
	["tree.isMethod"] = "'%s' 는 메소드입니다. 앞에 콜론을 붙이면 메소드로 잡힙니다.",
	["tree.methodNoType"] = "메소드 트랙에는 값 타입이 쓰이지 않습니다.",
	["tree.enumHint"] = "Enum.%s 의 항목으로 다룹니다.",
	["tree.enumUnknown"] = "어느 Enum인지 알 수 없습니다. Enum 종류를 골라주세요.",
	["tree.instanceHint"] = "값은 [아이템번호].경로 로 적습니다. 예: [2].Handle.Tip",
	["tree.inferredHint"] = "현재 값에서 %s 로 잡힙니다.",
	["tree.noBindingInfer"] = "바인딩이 없어 자동으로 알 수 없습니다. number로 잡힙니다.",
	["tree.cannotInfer"] = "자동으로 알 수 없습니다. number로 잡히니 직접 골라주세요.",
	["tree.cannotInferShort"] = "자동으로 알 수 없어 number로 잡힙니다.",
	["tree.trackTaken"] = "'%s' 는 이미 추가되어 있습니다.",
	["tree.valueTypeMessage"] = "%s 의 키프레임 값을 어떤 타입으로 다룰지 정합니다.",
	["tree.keysClearedTitle"] = "키프레임이 지워집니다",
	["tree.keysClearedMessage"] = "이미 찍은 키 %d개는 새 타입으로 읽을 수 없어 함께 지워집니다.",
	["tree.poseFailed"] = "포즈를 찍지 못했습니다",
	["tree.poseTitle"] = "리그 포즈를 찍었습니다",
	["tree.poseMessage"] = "관절 %d개를 재생헤드 자리에 기록했습니다.",
	["tree.positionFailed"] = "위치를 찍지 못했습니다",
	["tree.deleteItemTitle"] = "아이템 삭제",
	["tree.deleteItemMessage"] = "'%s' 와 그 안의 엘리먼트·트랙이 모두 지워집니다.",
	["tree.infoMessage"] = "%s\n\n바인딩: %s",
	["tree.bindingNone"] = "없음",

	-------------------------------------------------------------------------
	-- 속성 고르는 창
	-------------------------------------------------------------------------
	["picker.noBinding"] = "바인딩 없음",
	["picker.properties"] = "속성 %d",
	["picker.methods"] = "메소드 %d",
	["picker.search"] = "검색",
	["picker.alreadyAdded"] = "이미 있음",
	["picker.otherMethods"] = "그 밖의 메소드",
	["picker.otherProperties"] = "그 밖의 속성",
	["picker.emptyList"] = "고를 수 있는 게 없습니다.\nCustom으로 직접 적어주세요.",
	["picker.noBindingList"] = "바인딩이 없어 목록을 만들 수 없습니다.\nCustom으로 직접 적어주세요.",
	["picker.noMatch"] = "'%s' 에 맞는 게 없습니다.",

	-------------------------------------------------------------------------
	-- 키프레임 편집 창
	-------------------------------------------------------------------------
	["key.time"] = "시간",
	["key.frameInfo"] = "프레임 %d / %d   (스냅 %s)",
	["key.args"] = "인자",
	["key.value"] = "값",
	["key.valuePlaceholder"] = [[25,  true,  "글자",  nil,  Vector3(1,2,3),  Enum.Material.Neon,  [2].Handle]],
	["key.easing"] = "이징",
	["key.methodHint"] = "메소드는 재생헤드가 이 지점을 지날 때 한 번 호출됩니다.",
	["key.constantHint"] = "%s 는 보간하지 않고 다음 키까지 값을 유지합니다.",
	["key.thisType"] = "이 타입",
	["key.timeNumber"] = "시간은 숫자여야 합니다.",
	["key.timeTaken"] = "%.3f초 에 이미 키프레임이 있습니다.",
	["key.nilInMiddle"] = "인자 중간에 nil은 넣을 수 없습니다.",
	["key.checkValue"] = "값을 확인하세요.",
	["key.readFailed"] = "값을 읽을 수 없습니다.",
	["literal.unknownType"] = "'%s' 라는 값 타입은 없습니다.",
	["key.nameMessage"] = "이 키프레임의 이름입니다. 비우면 이름을 뗍니다.\n"
		.. "이름이 있으면 런타임에서 GetTimeOfKeyframe으로 찾을 수 있습니다.",
	["key.namePlaceholder"] = "키프레임 이름",
	["key.markerMessage"] = "%.2fs 자리의 키프레임에 마커를 넣습니다.",

	-------------------------------------------------------------------------
	-- 타임라인
	-------------------------------------------------------------------------
	["timeline.preview"] = "미리보기",
	["timeline.empty"] = "왼쪽에서 아이템과 엘리먼트를 추가하면 여기에 트랙이 생깁니다.",
	["timeline.speed"] = "배속 x%.2g",
	["timeline.loop"] = "반복",
	["timeline.zoom"] = "확대 x%.2g",
	["timeline.snap"] = "스냅 %s",
	["timeline.duration"] = "길이 %.2fs",
	["timeline.priority"] = "우선순위 %d",
	["timeline.priorityMessage"] = "저장 파일에 숫자로만 적어두는 값입니다. 에디터는 기록만 하고,\n"
		.. "이 값을 어떻게 쓸지는 재생하는 쪽이 정합니다.",
	["timeline.priorityPlaceholder"] = "숫자",
	["timeline.numberRequired"] = "숫자를 입력하세요.",
	["timeline.integerRequired"] = "정수를 입력하세요.",
	["timeline.speedMessage"] = "미리보기 재생 속도입니다. 저장되는 애니메이션에는 영향이 없습니다.",
	["timeline.speedPlaceholder"] = "배속",
	["timeline.speedRange"] = "0.05에서 8 사이여야 합니다.",
	["timeline.snapMessage"] = "키프레임과 재생헤드가 붙는 간격을 프레임 수로 정합니다.\n"
		.. "2면 두 프레임마다 붙고, 1이면 모든 프레임에 붙습니다.",
	["timeline.snapPlaceholder"] = "프레임",
	["timeline.snapHint"] = "%d fps 기준 %.4f초 간격",
	["timeline.snapRange"] = "1에서 240 사이여야 합니다.",
	["timeline.durationMessage"] = "초 단위. 줄이면 그 뒤에 있는 키프레임은 지워집니다.",
	["timeline.durationPlaceholder"] = "초",
	["timeline.durationLost"] = "키프레임 %d개가 지워집니다.",
	["timeline.durationLostBoth"] = "키프레임 %d개와 마커 %d개가 지워집니다.",
	["timeline.durationRange"] = "0.1초에서 3600초 사이여야 합니다.",
	["timeline.fpsMessage"] = "타임라인 눈금과 키프레임이 붙는 간격입니다.\n"
		.. "재생 자체는 항상 모니터 주사율만큼 부드럽습니다.",
	["timeline.fpsRange"] = "1에서 240 사이여야 합니다.",
	["timeline.selectedCount"] = "키프레임 %d개 선택 중",
	["timeline.clearKeysTitle"] = "키프레임 전체 삭제",
	["timeline.clearKeysMessage"] = "%s 의 키프레임 %d개를 모두 지웁니다.",

	-------------------------------------------------------------------------
	-- 마커
	-------------------------------------------------------------------------
	["marker.message"] = "%.2fs 자리에 이름을 찍어둡니다. 에디터는 기록만 합니다.",
	["marker.addMessage"] = "키프레임 '%s' 에 마커를 넣습니다.",
	["marker.markerPlaceholder"] = "마커 이름",
	["marker.duplicate"] = "'%s' 는 이 키프레임에 이미 있습니다.",
	["marker.namePlaceholder"] = "키프레임 이름",
	["marker.nameEmpty"] = "이름을 입력하세요.",
	["marker.nameTooLong"] = "이름은 64자 이하여야 합니다.",
	["marker.overwrite"] = "이 자리에 이미 키프레임이 있습니다 (%s). 이름만 바뀝니다.",
	["marker.clearTitle"] = "키프레임 전체 삭제",
	["marker.clearMessage"] = "키프레임 %d개와 그 안의 마커를 모두 지웁니다.",

	-------------------------------------------------------------------------
	-- 값 입력
	-------------------------------------------------------------------------
	["value.numbersOnly"] = "숫자만 쉼표로 구분해 입력하세요. 예: %s",
	["value.numberCount"] = "숫자 %d개가 필요합니다 (%d개 입력됨). 예: %s",
	["value.number"] = "숫자를 입력하세요.",
	["value.boolean"] = "true 또는 false 를 입력하세요.",
	["value.rangeOrder"] = "최소값이 최대값보다 클 수 없습니다.",
	["value.brickColor"] = "브릭 색 이름을 정확히 입력하세요. 예: Really red",
	["value.enumName"] = "Enum 이름을 함께 입력하세요. 예: Material.Neon",
	["value.enumMissing"] = "Enum.%s.%s 를 찾을 수 없습니다.",
	["value.keypoints"] = "키포인트 %d개 — Capture로만 바꿀 수 있습니다",
	["value.captureOnly"] = "이 타입은 직접 입력할 수 없습니다. Capture를 쓰세요.",
	["value.unsupported"] = "(지원하지 않는 타입)",
	["value.notEditable"] = "이 타입은 편집할 수 없습니다.",
	["value.noBinding"] = "바인딩된 오브젝트가 없습니다.",
	["value.instanceRef"] = "Instance 값은 [아이템번호].경로 로 직접 적어주세요.",
	["value.missingProperty"] = "%s 에 '%s' 가 없습니다.",
	["value.typeMismatch"] = "현재 값은 %s 인데 트랙은 %s 로 잡혀 있습니다.",

	-------------------------------------------------------------------------
	-- 캡처(포즈·위치)
	-------------------------------------------------------------------------
	["state.noMotor6d"] = "이 아이템 안에 Motor6D가 없습니다.",
	["state.noOriginBinding"] = "기준 아이템(Origin)에 바인딩이 없어 상대 위치를 잴 수 없습니다.",
	["state.noPivot"] = "위치를 읽을 수 없는 오브젝트입니다.",

	-------------------------------------------------------------------------
	-- 경로 / 대상 파싱
	-------------------------------------------------------------------------
	["path.doubleDot"] = "점을 연속으로 쓸 수 없습니다.",
	["path.tooLong"] = "경로가 너무 깁니다.",
	["path.targetEmpty"] = "속성 이름이나 메소드 이름을 입력하세요.",
	["path.badMethod"] = "메소드 이름이 올바르지 않습니다. 예: :Emit()",
	["path.badProperty"] = "속성 이름이 올바르지 않습니다. 예: Enabled",
	["path.refStart"] = "아이템 번호로 시작해야 합니다. 예: [2] 또는 [2].Handle.Tip (비우면 nil)",
	["path.badItemId"] = "아이템 번호가 올바르지 않습니다.",

	-------------------------------------------------------------------------
	-- 이징
	-------------------------------------------------------------------------
	["easing.constant"] = "다음 키에 닿을 때까지 값을 그대로 유지합니다.",
	["easing.linear"] = "두 키 사이를 일정한 속도로 잇습니다.",

	-------------------------------------------------------------------------
	-- 저장 / 잠금 / 스키마
	-------------------------------------------------------------------------
	["store.folderConflict"] = "[RokinIdiot] ServerStorage.%s 가 Folder가 아니라 %s 입니다. 이름을 바꾸거나 지워주세요.",
	["store.nameEmpty"] = "이름을 입력하세요.",
	["store.nameTooLong"] = "이름은 50자 이하여야 합니다.",
	["store.nameReserved"] = "'%s' 는 예약된 이름입니다.",
	["store.corrupt"] = "[RokinIdiot] 저장 파일이 손상되어 읽을 수 없습니다: ",
	["store.notFound"] = "[RokinIdiot] '%s' 작업을 찾을 수 없습니다.",
	["store.nameTaken"] = "[RokinIdiot] '%s' 라는 작업이 이미 있습니다.",
	["lock.unknownUser"] = "알 수 없는 사용자",
	["lock.userNamed"] = "사용자 %s",
	["lock.holder"] = "%s (%d초 전 활동)",
	["schema.notTable"] = "[RokinIdiot] 문서가 테이블이 아닙니다",
	["schema.tooNew"] = "[RokinIdiot] 이 프로젝트는 스키마 v%d로 저장되었습니다. "
		.. "플러그인이 지원하는 최신 버전은 v%d입니다. 플러그인을 업데이트하세요.",
	["schema.noPath"] = "[RokinIdiot] 스키마 v%d에서 올라갈 경로가 없습니다",

	-------------------------------------------------------------------------
	-- 내부 오류
	-------------------------------------------------------------------------
	["error.pluginEnv"] = "[RokinIdiot] PluginEnv.Set이 아직 호출되지 않았습니다",
	["error.commit"] = "[RokinIdiot] '%s' 편집 실패, 되돌림: %s",
	["error.cleanup"] = "[RokinIdiot] 정리 중 오류: ",
	["error.handler"] = "[RokinIdiot] 시그널 핸들러 오류: ",

	-------------------------------------------------------------------------
	-- 출력창에 찍는 것
	-------------------------------------------------------------------------
	["log.debugCleared"] = "[RokinIdiot] 성능 기록을 비웠습니다.",
	["log.reflectionUnavailable"] = "[RokinIdiot] ReflectionService를 쓸 수 없습니다. 적어둔 후보 목록으로 동작합니다.",
	["log.reflectionReady"] = "[RokinIdiot] ReflectionService 사용 가능. 대상 클래스: %s",
	["reflection.unavailable"] = "[RokinIdiot] ReflectionService를 쓸 수 없습니다.",
	["reflection.callFailed"] = "[RokinIdiot] GetPropertiesOfClass('%s') 실패: %s",
	["reflection.notTable"] = "[RokinIdiot] 표가 아니라 %s 를 돌려줬습니다.",
	["reflection.header"] = "[RokinIdiot] %s 속성 %d개. 앞 3개의 속 모양:",

	-------------------------------------------------------------------------
	-- 성능 기록 (이름이 곧 집계 키라 report에서만 번역한다)
	-------------------------------------------------------------------------
	["debug.empty"] = "[RokinIdiot] 기록된 게 없습니다. 미리보기를 재생한 뒤 다시 눌러보세요.",
	["debug.header"] = "[RokinIdiot] 성능 기록  (재는 것 자체도 비용이 있으니 절대값보다 비율을 보세요)",
	["debug.countLine"] = "  %-26s 횟수 %d",
	["debug.statLine"] = "  %-26s 호출 %-7d 합계 %-12s 평균 %-12s 최대 %s   마지막 %s",
	["debug.beforeFirstKey"] = "구간: 첫 키 앞",
	["debug.afterLastKey"] = "구간: 마지막 키 뒤",
	["debug.betweenKeys"] = "구간: 키 사이 (전체)",
	["debug.openLock"] = "열기: 잠금 잡기",
	["debug.openLoad"] = "열기: 저장 파일 읽기",
	["debug.openScreen"] = "열기: 에디터 화면 만들기",
	["debug.openTotal"] = "열기: 전체",
	["debug.rulerRedraw"] = "눈금자 다시 그리기",
	["debug.rulerTicks"] = "눈금자 눈금 개수",
	["debug.lockHeartbeat"] = "잠금 하트비트 (15초마다)",
	["debug.applyAt"] = "Player:ApplyAt (프레임 전체)",
	["debug.frameWithWrite"] = "프레임 간격 (값 쓴 프레임)",
	["debug.frameNoWrite"] = "프레임 간격 (값 안 쓴 프레임)",
	["debug.skipSameValue"] = "쓰기 건너뜀 (값 같음)",
	["debug.writeProperty"] = "속성 쓰기",
	["debug.writePivot"] = "위치 쓰기 (PivotTo)",
	["debug.band1"] = "프레임 분포: ~20ms (정상)",
	["debug.band2"] = "프레임 분포: 20~34ms",
	["debug.band3"] = "프레임 분포: 34~50ms (눈에 보임)",
	["debug.band4"] = "프레임 분포: 50~100ms",
	["debug.band5"] = "프레임 분포: 100ms+ (확실한 멈춤)",
}
