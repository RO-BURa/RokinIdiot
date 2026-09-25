--!strict
-- 라이트 테마 토큰. Dark.luau와 키 구성이 반드시 같아야 한다.

return {
	name = "Light",
	color = {
		windowBackground = Color3.fromRGB(242, 242, 245),
		topBar = Color3.fromRGB(250, 250, 252),
		panel = Color3.fromRGB(255, 255, 255),
		panelAlt = Color3.fromRGB(246, 246, 249),

		border = Color3.fromRGB(214, 214, 220),
		divider = Color3.fromRGB(228, 228, 233),

		text = Color3.fromRGB(28, 28, 32),
		textMuted = Color3.fromRGB(118, 118, 128),
		textOnAccent = Color3.fromRGB(255, 255, 255),

		accent = Color3.fromRGB(0, 110, 230),
		accentHover = Color3.fromRGB(24, 130, 245),
		accentPressed = Color3.fromRGB(0, 94, 200),

		buttonBackground = Color3.fromRGB(238, 238, 242),
		buttonHover = Color3.fromRGB(228, 228, 234),
		buttonPressed = Color3.fromRGB(218, 218, 225),

		rowHover = Color3.fromRGB(238, 238, 243),
		rowSelected = Color3.fromRGB(210, 228, 250),

		danger = Color3.fromRGB(208, 52, 52),
		dangerHover = Color3.fromRGB(224, 70, 70),

		inputBackground = Color3.fromRGB(255, 255, 255),
		scrim = Color3.fromRGB(0, 0, 0),
	},
	scrimTransparency = 0.35,
}
