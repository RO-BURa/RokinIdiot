--!nonstrict
-- 속성 이름 후보 목록.
--
-- 로블록스는 "이 인스턴스에 어떤 속성이 있나"를 스크립트로 알려주지 않는다.
-- ReflectionService 같은 건 플러그인에 열려있지 않고, Studio의 Properties 패널은
-- Lua에 노출되지 않은 내부 리플렉션을 쓴다.
--
-- 그래서 반대로 간다. 이름 후보를 넉넉히 들고 있다가 실제 인스턴스에서
-- 하나씩 읽어보고, 읽히는 것만 남긴다. 읽힌 값의 typeof로 값 타입까지 정확히
-- 알 수 있어서 손으로 적어둔 타입보다 믿을 만하다.
--
-- 여기엔 **쓸 수 있고 애니메이션에 의미가 있는** 이름만 넣는다.
-- ClassName이나 AbsoluteSize처럼 읽기 전용인 것은 넣지 않는다.
-- 넣지 않아도 "Custom..."으로 직접 적으면 그대로 쓸 수 있다.

return {
	--------------------------------------------------------------------------
	-- 파트 / 물리
	--------------------------------------------------------------------------
	"Anchored",
	"Archivable",
	"AssemblyLinearVelocity",
	"AssemblyAngularVelocity",
	"BrickColor",
	"CanCollide",
	"CanQuery",
	"CanTouch",
	"CastShadow",
	"CFrame",
	"CollisionGroup",
	"Color",
	"CustomPhysicalProperties",
	"EnableFluidForces",
	"Massless",
	"Material",
	"MaterialVariant",
	"Orientation",
	"PivotOffset",
	"Position",
	"Reflectance",
	"RootPriority",
	"Rotation",
	"Shape",
	"Size",
	"Transparency",
	"UsePartColor",

	-- MeshPart / SpecialMesh
	"DoubleSided",
	"MeshId",
	"Scale",
	"TextureID",
	"VertexColor",

	--------------------------------------------------------------------------
	-- 파티클 / 이펙트
	--------------------------------------------------------------------------
	"Acceleration",
	"Brightness",
	"CurveSize0",
	"CurveSize1",
	"Drag",
	"EmissionDirection",
	"Enabled",
	"FaceCamera",
	"FlipbookMode",
	"Lifetime",
	"LightEmission",
	"LightInfluence",
	"LocalTransparencyModifier",
	"LockedToPart",
	"Rate",
	"RotSpeed",
	"Segments",
	"Speed",
	"SpreadAngle",
	"Squash",
	"Texture",
	"TextureLength",
	"TextureSpeed",
	"TimeScale",
	"VelocityInheritance",
	"VelocitySpread",
	"Width0",
	"Width1",
	"WidthScale",
	"ZOffset",

	-- Trail
	"Attachment0",
	"Attachment1",
	"MaxLength",
	"MinLength",

	-- Highlight
	"DepthMode",
	"FillColor",
	"FillTransparency",
	"OutlineColor",
	"OutlineTransparency",

	--------------------------------------------------------------------------
	-- 조명
	--------------------------------------------------------------------------
	"Angle",
	"Face",
	"Range",
	"Shadows",

	--------------------------------------------------------------------------
	-- 소리
	--------------------------------------------------------------------------
	"Looped",
	"PlaybackRegionsEnabled",
	"PlaybackSpeed",
	"Playing",
	"PlayOnRemove",
	"RollOffMaxDistance",
	"RollOffMinDistance",
	"SoundId",
	"TimePosition",
	"Volume",

	-- 소리 효과
	"DryLevel",
	"WetLevel",
	"Decay",
	"Delay",
	"Depth",
	"Frequency",
	"Gain",
	"Mix",
	"Rate",

	--------------------------------------------------------------------------
	-- 화면 UI
	--------------------------------------------------------------------------
	"AnchorPoint",
	"AutomaticSize",
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderColor3",
	"BorderSizePixel",
	"ClipsDescendants",
	"Draggable",
	"GroupColor3",
	"GroupTransparency",
	"Image",
	"ImageColor3",
	"ImageRectOffset",
	"ImageRectSize",
	"ImageTransparency",
	"LayoutOrder",
	"MaxVisibleGraphemes",
	"ScaleType",
	"SliceScale",
	"Text",
	"TextColor3",
	"TextScaled",
	"TextSize",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"TextTransparency",
	"TextWrapped",
	"Thickness",
	"Visible",
	"ZIndex",

	-- UI 제약 / 꾸미기
	"CornerRadius",
	"Offset",
	"PaddingBottom",
	"PaddingLeft",
	"PaddingRight",
	"PaddingTop",
	"Padding",

	--------------------------------------------------------------------------
	-- 부착점 / 제약
	--------------------------------------------------------------------------
	"Axis",
	"SecondaryAxis",
	"WorldCFrame",
	"WorldPosition",
	"C0",
	"C1",
	"CurrentAngle",
	"DesiredAngle",
	"MaxVelocity",
	"MaxForce",
	"MaxTorque",
	"Responsiveness",
	"Restitution",
	"Stiffness",
	"Damping",
	"Length",
	"Radius",
	"TargetAngle",
	"TargetPosition",
	"Velocity",
	"AngularVelocity",
	"Attachment",

	--------------------------------------------------------------------------
	-- 표면 / 데칼
	--------------------------------------------------------------------------
	"Color3",
	"StudsPerTileU",
	"StudsPerTileV",
	"OffsetStudsU",
	"OffsetStudsV",

	--------------------------------------------------------------------------
	-- 카메라 / 하늘 / 화면 효과
	--------------------------------------------------------------------------
	"FieldOfView",
	"FieldOfViewMode",
	"Focus",
	"Density",
	"Glare",
	"Haze",
	"StarCount",
	"SunAngularSize",
	"MoonAngularSize",
	"Ambient",
	"OutdoorAmbient",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ExposureCompensation",
	"FogColor",
	"FogEnd",
	"FogStart",
	"GeographicLatitude",
	"ClockTime",
	"TimeOfDay",
	-- Bloom / Blur / ColorCorrection / DepthOfField / SunRays
	"Intensity",
	"Threshold",
	"Contrast",
	"Saturation",
	"TintColor",
	"FarIntensity",
	"NearIntensity",
	"FocusDistance",
	"InFocusRadius",
	"Spread",
	"Cover",

	--------------------------------------------------------------------------
	-- 캐릭터
	--------------------------------------------------------------------------
	"CameraOffset",
	"Health",
	"HipHeight",
	"JumpPower",
	"JumpHeight",
	"MaxHealth",
	"MaxSlopeAngle",
	"WalkSpeed",
	"AutoRotate",
	"PlatformStand",
	"Sit",

	--------------------------------------------------------------------------
	-- 값 오브젝트 / 기타
	--------------------------------------------------------------------------
	"Value",
	"Adornee",
	"AlwaysOnTop",
	"Origin",
	"Priority",
	"WeightStyle",
	"Style",
}
