--!nonstrict
-- 영어 문구. 기본 언어이자 다른 언어에 빠진 키를 메우는 자리이므로
-- 여기에는 모든 키가 있어야 한다.
--
-- 서식 문자열의 인자 순서는 언어마다 같아야 한다. string.format에는
-- 자리 번호가 없어서 순서를 바꿀 방법이 없기 때문이다.

return {
	-------------------------------------------------------------------------
	-- 공통
	-------------------------------------------------------------------------
	["common.ok"] = "OK",
	["common.cancel"] = "Cancel",
	["common.delete"] = "Delete",
	["common.none"] = "(none)",
	["common.root"] = "(root)",
	["common.itemRoot"] = "(item root)",

	-------------------------------------------------------------------------
	-- 되돌리기 기록에 남는 이름
	-------------------------------------------------------------------------
	["undo.addItem"] = "Add item",
	["undo.renameItem"] = "Rename item",
	["undo.deleteItem"] = "Delete item",
	["undo.setItemId"] = "Change item Id",
	["undo.setItemClass"] = "Refresh item kind",
	["undo.setOrigin"] = "Change origin item",
	["undo.addTrack"] = "Add track",
	["undo.deleteTrack"] = "Delete track",
	["undo.deleteElement"] = "Delete element",
	["undo.setPath"] = "Change path",
	["undo.setValueType"] = "Change value type",
	["undo.addKey"] = "Add keyframe",
	["undo.editKey"] = "Edit keyframe",
	["undo.moveKey"] = "Move keyframe",
	["undo.moveKeys"] = "Move keyframes",
	["undo.deleteKey"] = "Delete keyframe",
	["undo.deleteKeys"] = "Delete keyframes",
	["undo.editKeys"] = "Edit keyframes",
	["undo.clearKeys"] = "Delete all keyframes",
	["undo.setKeyValue"] = "Change keyframe value",
	["undo.setKeyValues"] = "Change keyframe values",
	["undo.setKeyName"] = "Name keyframe",
	["undo.capturePose"] = "Capture rig pose",
	["undo.capturePosition"] = "Capture position",
	["undo.setPriority"] = "Change priority",
	["undo.putKeyframe"] = "Set keyframe",
	["undo.moveKeyframe"] = "Move keyframe",
	["undo.deleteKeyframe"] = "Delete keyframe",
	["undo.clearKeyframes"] = "Delete all keyframes",
	["undo.addMarker"] = "Add marker",
	["undo.removeMarker"] = "Remove marker",
	["undo.setSnap"] = "Change snap unit",
	["undo.setDuration"] = "Change length",
	["undo.setFps"] = "Change fps",

	-------------------------------------------------------------------------
	-- 앱 전체
	-------------------------------------------------------------------------
	["app.tooltip"] = "Open the special animation editor",
	["app.namePlaceholder"] = "Name",
	["app.nameTaken"] = "An animation named '%s' already exists.",
	["app.createFailed"] = "Could not create it",
	["app.openFailed"] = "Could not open it",
	["app.saveFailed"] = "Could not save it",
	["app.exportFailed"] = "Could not export it",
	["app.playerMissing"] = "'%s' is not inside the plugin. The build may be incomplete.",
	["app.deleteTitle"] = "Delete animation",
	["app.deleteMessage"] = "'%s' will be deleted. This cannot be undone.",
	["app.unsavedTitle"] = "Unsaved changes",
	["app.unsavedMessage"] = "'%s' has changes that are not saved.",
	["app.saveAndClose"] = "Save and close",
	["app.closeWithoutSaving"] = "Close without saving",
	["app.lockLostTitle"] = "Edit access lost",
	["app.lockLostMessage"] = "%s started editing, so '%s' was closed. Unsaved changes are gone.",
	["app.lockedTitle"] = "Someone else is editing",
	["app.lockedMessage"] = "%s is using RokinIdiot in this place.\n"
		.. "Editing at the same time makes the previews collide and tangles both sessions.\n\n"
		.. "To open it anyway you have to take over edit access.",
	["app.takeOver"] = "Take over",

	-------------------------------------------------------------------------
	-- 로비 화면
	-------------------------------------------------------------------------
	["home.subtitle"] = "Special Animation Editor",
	["home.recentTitle"] = "Recent work",
	["home.empty"] = "No animations yet.\nStart with New Animation at the top right.",
	["home.neverOpened"] = "never opened",
	["home.justNow"] = "just now",
	["home.minutesAgo"] = "%d min ago",
	["home.hoursAgo"] = "%d hr ago",
	["home.daysAgo"] = "%d days ago",
	["home.foreignSelection"] = "The selected animation is not saved in this place.",
	["home.saveSelection"] = "Save it here",
	["home.importRenamed"] = "'%s' already exists here, so it is saved under another name.",
	["home.importFailed"] = "Could not import it",
	["home.lockedBy"] = "%s is editing. Opening it will ask to take over.",

	-------------------------------------------------------------------------
	-- 상단 바
	-------------------------------------------------------------------------
	["topbar.menu"] = "Menu",
	["topbar.language"] = "Language",
	["topbar.theme"] = "Theme",
	["topbar.options"] = "Options",
	["topbar.export"] = "Export Animation to Workspace",
	["topbar.exportPlayer"] = "Export Player to Workspace",
	["topbar.followSelection"] = "Playhead follows selected keyframe",
	["topbar.showMarkers"] = "Show keyframe lane",
	["topbar.deselectWhilePlaying"] = "Deselect while playing",

	-------------------------------------------------------------------------
	-- 왼쪽 트리 (아이템 / 엘리먼트 / 트랙)
	-------------------------------------------------------------------------
	["tree.empty"] = "No items yet.\n\n"
		.. "Pick a model in the Explorer and press + Item\n"
		.. "to register it as an item.",
	["tree.noBinding"] = "no binding (preview unavailable)",
	["tree.sharedBinding"] = "-> %s  (shared with #%s)",
	["tree.bindFailedTitle"] = "Cannot bind it",
	["tree.bindFailedMessage"] = "Select exactly one object in the Explorer and try again.",
	["tree.addItemMessage"] = "With one object selected in the Explorer, the name and binding are filled in for you.",
	["tree.nameEmpty"] = "Enter a name.",
	["tree.itemNameTaken"] = "An item named '%s' already exists.",
	["tree.idMessage"] = "The slot number PlayAnimation takes at runtime.\n"
		.. "Entering a number that is already used swaps the two items.",
	["tree.idPlaceholder"] = "Number",
	["tree.integerRequired"] = "Enter a whole number.",
	["tree.idRange"] = "Must be between 1 and 999.",
	["tree.pathPlaceholder"] = "Path",
	["tree.pathMessage"] = "Write the path from the item root. Leave it empty to point at the item itself.",
	["tree.pathNoBinding"] = "There is no binding, so the path cannot be checked.",
	["tree.pathMissing"] = "The current binding has no '%s'. You can still add it.",
	["tree.pathFound"] = "Found in the current binding.",
	["tree.pathTaken"] = "That path is already added.",
	["tree.addTrackFirstTitle"] = "Add Element — first track",
	["tree.addTrackMessage"] = "Properties as they are (Enabled), methods with a leading colon (:Emit()).\n"
		.. "Arguments inside the parentheses are ignored; each keyframe carries its own.",
	["tree.targetPlaceholder"] = ":Emit()  or  Enabled",
	["tree.valueTypeLabel"] = "Value type",
	["tree.enumTypeLabel"] = "Enum type",
	["tree.trackMissing"] = "The current binding (%s) has no '%s'. You can still add it.",
	["tree.notMethod"] = "'%s' is not a method. Drop the colon to treat it as a property.",
	["tree.isMethod"] = "'%s' is a method. Put a colon in front to treat it as one.",
	["tree.methodNoType"] = "Method tracks do not use a value type.",
	["tree.enumHint"] = "Handled as an item of Enum.%s.",
	["tree.enumUnknown"] = "Cannot tell which Enum it is. Please pick the enum type.",
	["tree.instanceHint"] = "Write the value as [item number].path, for example [2].Handle.Tip",
	["tree.inferredHint"] = "Read as %s from the current value.",
	["tree.noBindingInfer"] = "There is no binding to read from, so it is treated as number.",
	["tree.cannotInfer"] = "It cannot be worked out, so it falls back to number. Please pick one.",
	["tree.cannotInferShort"] = "It cannot be worked out, so it falls back to number.",
	["tree.trackTaken"] = "'%s' is already added.",
	["tree.valueTypeMessage"] = "Choose how the keyframe values of %s are handled.",
	["tree.keysClearedTitle"] = "Keyframes will be deleted",
	["tree.keysClearedMessage"] = "The %d keys already recorded cannot be read as the new type, so they go with it.",
	["tree.poseFailed"] = "Could not capture the pose",
	["tree.poseTitle"] = "Rig pose captured",
	["tree.poseMessage"] = "Recorded %d joints at the playhead.",
	["tree.positionFailed"] = "Could not capture the position",
	["tree.deleteItemTitle"] = "Delete item",
	["tree.deleteItemMessage"] = "'%s' and every element and track inside it will be deleted.",
	["tree.infoMessage"] = "%s\n\nBinding: %s",
	["tree.bindingNone"] = "none",

	-------------------------------------------------------------------------
	-- 속성 고르는 창
	-------------------------------------------------------------------------
	["picker.noBinding"] = "no binding",
	["picker.properties"] = "Properties %d",
	["picker.methods"] = "Methods %d",
	["picker.search"] = "Search",
	["picker.alreadyAdded"] = "added",
	["picker.otherMethods"] = "Other methods",
	["picker.otherProperties"] = "Other properties",
	["picker.emptyList"] = "There is nothing to pick.\nUse Custom to write it yourself.",
	["picker.noBindingList"] = "There is no binding to read, so the list is empty.\nUse Custom to write it yourself.",
	["picker.noMatch"] = "Nothing matches '%s'.",

	-------------------------------------------------------------------------
	-- 키프레임 편집 창
	-------------------------------------------------------------------------
	["key.time"] = "Time",
	["key.frameInfo"] = "frame %d / %d   (snap %s)",
	["key.args"] = "Arguments",
	["key.value"] = "Value",
	["key.valuePlaceholder"] = [[25,  true,  "text",  nil,  Vector3(1,2,3),  Enum.Material.Neon,  [2].Handle]],
	["key.easing"] = "Easing",
	["key.methodHint"] = "Methods are called once as the playhead passes this point.",
	["key.constantHint"] = "%s is held until the next key instead of being interpolated.",
	["key.thisType"] = "this type",
	["key.timeNumber"] = "The time has to be a number.",
	["key.timeTaken"] = "There is already a keyframe at %.3fs.",
	["key.nilInMiddle"] = "nil cannot sit between other arguments.",
	["key.checkValue"] = "Check the value.",
	["key.readFailed"] = "The value could not be read.",
	["literal.unknownType"] = "There is no value type called '%s'.",
	["key.nameMessage"] = "A name for this keyframe. Leave it empty to remove the name.\n"
		.. "Named keyframes can be found with GetTimeOfKeyframe at runtime.",
	["key.namePlaceholder"] = "Keyframe name",
	["key.markerMessage"] = "Adds a marker to the keyframe at %.2fs.",

	-------------------------------------------------------------------------
	-- 타임라인
	-------------------------------------------------------------------------
	["timeline.preview"] = "Preview",
	["timeline.empty"] = "Add items and elements on the left and their tracks show up here.",
	["timeline.speed"] = "Speed x%.2g",
	["timeline.loop"] = "Loop",
	["timeline.zoom"] = "Zoom x%.2g",
	["timeline.snap"] = "Snap %s",
	["timeline.duration"] = "Length %.2fs",
	["timeline.priority"] = "Priority %d",
	["timeline.priorityMessage"] = "A plain number written into the save. The editor only records it;\n"
		.. "what it means is up to whatever plays the animation back.",
	["timeline.priorityPlaceholder"] = "Number",
	["timeline.numberRequired"] = "Enter a number.",
	["timeline.integerRequired"] = "Enter a whole number.",
	["timeline.speedMessage"] = "Preview playback speed. It changes nothing in the saved animation.",
	["timeline.speedPlaceholder"] = "Speed",
	["timeline.speedRange"] = "Must be between 0.05 and 8.",
	["timeline.snapMessage"] = "How far apart keyframes and the playhead snap, counted in frames.\n"
		.. "2 snaps every second frame, 1 snaps to every frame.",
	["timeline.snapPlaceholder"] = "Frames",
	["timeline.snapHint"] = "%d fps, so %.4fs apart",
	["timeline.snapRange"] = "Must be between 1 and 240.",
	["timeline.durationMessage"] = "In seconds. Shrinking it deletes the keyframes past the new end.",
	["timeline.durationPlaceholder"] = "Seconds",
	["timeline.durationLost"] = "%d keyframes will be deleted.",
	["timeline.durationLostBoth"] = "%d keyframes and %d markers will be deleted.",
	["timeline.durationRange"] = "Must be between 0.1 and 3600 seconds.",
	["timeline.fpsMessage"] = "The spacing of the ruler and of keyframe snapping.\n"
		.. "Playback itself is always as smooth as your monitor.",
	["timeline.fpsRange"] = "Must be between 1 and 240.",
	["timeline.selectedCount"] = "%d keyframes selected",
	["timeline.clearKeysTitle"] = "Delete all keyframes",
	["timeline.clearKeysMessage"] = "All %d keyframes of %s will be deleted.",

	-------------------------------------------------------------------------
	-- 마커
	-------------------------------------------------------------------------
	["marker.message"] = "A named point at %.2fs. The editor only records it.",
	["marker.addMessage"] = "Adds a marker to the keyframe '%s'.",
	["marker.markerPlaceholder"] = "Marker name",
	["marker.duplicate"] = "'%s' is already on this keyframe.",
	["marker.namePlaceholder"] = "Keyframe name",
	["marker.nameEmpty"] = "Enter a name.",
	["marker.nameTooLong"] = "The name has to be 64 characters or fewer.",
	["marker.overwrite"] = "There is already a keyframe here (%s). Only its name changes.",
	["marker.clearTitle"] = "Delete all keyframes",
	["marker.clearMessage"] = "All %d keyframes and the markers inside them will be deleted.",

	-------------------------------------------------------------------------
	-- 값 입력
	-------------------------------------------------------------------------
	["value.numbersOnly"] = "Enter numbers separated by commas. Example: %s",
	["value.numberCount"] = "%d numbers are needed (%d given). Example: %s",
	["value.number"] = "Enter a number.",
	["value.boolean"] = "Enter true or false.",
	["value.rangeOrder"] = "The minimum cannot be larger than the maximum.",
	["value.brickColor"] = "Enter an exact BrickColor name. Example: Really red",
	["value.enumName"] = "Include the enum name. Example: Material.Neon",
	["value.enumMissing"] = "Enum.%s.%s does not exist.",
	["value.keypoints"] = "%d keypoints, only Capture can change this",
	["value.captureOnly"] = "This type cannot be typed in. Use Capture.",
	["value.unsupported"] = "(unsupported type)",
	["value.notEditable"] = "This type cannot be edited.",
	["value.noBinding"] = "There is no bound object.",
	["value.instanceRef"] = "Write Instance values yourself as [item number].path",
	["value.missingProperty"] = "%s has no '%s'.",
	["value.typeMismatch"] = "The value is %s but the track is set to %s.",

	-------------------------------------------------------------------------
	-- 캡처(포즈·위치)
	-------------------------------------------------------------------------
	["state.noMotor6d"] = "There is no Motor6D inside this item.",
	["state.noOriginBinding"] = "The origin item has no binding, so relative positions cannot be measured.",
	["state.noPivot"] = "This object has no position that can be read.",

	-------------------------------------------------------------------------
	-- 경로 / 대상 파싱
	-------------------------------------------------------------------------
	["path.doubleDot"] = "Dots cannot be written back to back.",
	["path.tooLong"] = "The path is too long.",
	["path.targetEmpty"] = "Enter a property name or a method name.",
	["path.badMethod"] = "That method name is not valid. Example: :Emit()",
	["path.badProperty"] = "That property name is not valid. Example: Enabled",
	["path.refStart"] = "Must start with an item number. Example: [2] or [2].Handle.Tip (empty means nil)",
	["path.badItemId"] = "That item number is not valid.",

	-------------------------------------------------------------------------
	-- 이징
	-------------------------------------------------------------------------
	["easing.constant"] = "Holds the value until it reaches the next key.",
	["easing.linear"] = "Connects the two keys at a steady speed.",

	-------------------------------------------------------------------------
	-- 저장 / 잠금 / 스키마
	-------------------------------------------------------------------------
	["store.folderConflict"] = "[RokinIdiot] ServerStorage.%s is a %s, not a Folder. Please rename or remove it.",
	["store.nameEmpty"] = "Enter a name.",
	["store.nameTooLong"] = "The name has to be 50 characters or fewer.",
	["store.nameReserved"] = "'%s' is a reserved name.",
	["store.corrupt"] = "[RokinIdiot] The save file is damaged and cannot be read: ",
	["store.notFound"] = "[RokinIdiot] There is no animation named '%s'.",
	["store.nameTaken"] = "[RokinIdiot] An animation named '%s' already exists.",
	["lock.unknownUser"] = "unknown user",
	["lock.userNamed"] = "user %s",
	["lock.holder"] = "%s (active %ds ago)",
	["schema.notTable"] = "[RokinIdiot] The document is not a table",
	["schema.tooNew"] = "[RokinIdiot] This project was saved with schema v%d. "
		.. "The newest version this plugin knows is v%d. Please update the plugin.",
	["schema.noPath"] = "[RokinIdiot] There is no upgrade path from schema v%d",

	-------------------------------------------------------------------------
	-- 내부 오류
	-------------------------------------------------------------------------
	["error.pluginEnv"] = "[RokinIdiot] PluginEnv.Set has not been called yet",
	["error.commit"] = "[RokinIdiot] '%s' failed and was rolled back: %s",
	["error.cleanup"] = "[RokinIdiot] Error while cleaning up: ",
	["error.handler"] = "[RokinIdiot] Error in a signal handler: ",

	-------------------------------------------------------------------------
	-- 출력창에 찍는 것
	-------------------------------------------------------------------------
	["log.debugCleared"] = "[RokinIdiot] Performance log cleared.",
	["log.reflectionUnavailable"] = "[RokinIdiot] ReflectionService is not available. Falling back to the built-in list.",
	["log.reflectionReady"] = "[RokinIdiot] ReflectionService is available. Class in view: %s",
	["reflection.unavailable"] = "[RokinIdiot] ReflectionService is not available.",
	["reflection.callFailed"] = "[RokinIdiot] GetPropertiesOfClass('%s') failed: %s",
	["reflection.notTable"] = "[RokinIdiot] It gave back a %s instead of a table.",
	["reflection.header"] = "[RokinIdiot] %s has %d properties. Shape of the first 3:",

	-------------------------------------------------------------------------
	-- 성능 기록 (이름이 곧 집계 키라 report에서만 번역한다)
	-------------------------------------------------------------------------
	["debug.empty"] = "[RokinIdiot] Nothing recorded yet. Play the preview and press this again.",
	["debug.header"] = "[RokinIdiot] Performance log  (measuring costs something too, so read the ratios rather than the absolute numbers)",
	["debug.countLine"] = "  %-26s count %d",
	["debug.statLine"] = "  %-26s calls %-7d total %-12s avg %-12s max %s   last %s",
	["debug.beforeFirstKey"] = "Range: before the first key",
	["debug.afterLastKey"] = "Range: after the last key",
	["debug.betweenKeys"] = "Range: between keys (whole)",
	["debug.openLock"] = "Open: take the lock",
	["debug.openLoad"] = "Open: read the save file",
	["debug.openScreen"] = "Open: build the editor screen",
	["debug.openTotal"] = "Open: total",
	["debug.rulerRedraw"] = "Ruler redraw",
	["debug.rulerTicks"] = "Ruler tick count",
	["debug.lockHeartbeat"] = "Lock heartbeat (every 15s)",
	["debug.applyAt"] = "Player:ApplyAt (whole frame)",
	["debug.frameWithWrite"] = "Frame gap (frames that wrote)",
	["debug.frameNoWrite"] = "Frame gap (frames that did not)",
	["debug.skipSameValue"] = "Writes skipped (same value)",
	["debug.writeProperty"] = "Property write",
	["debug.writePivot"] = "Position write (PivotTo)",
	["debug.band1"] = "Frame spread: ~20ms (fine)",
	["debug.band2"] = "Frame spread: 20~34ms",
	["debug.band3"] = "Frame spread: 34~50ms (visible)",
	["debug.band4"] = "Frame spread: 50~100ms",
	["debug.band5"] = "Frame spread: 100ms+ (a clear stall)",
}
