--!strict
-- 다크 테마 토큰. Light.luau와 키 구성이 반드시 같아야 한다.

return {
	name = "Dark",
	color = {
		windowBackground = Color3.fromRGB(26, 26, 28),
		topBar = Color3.fromRGB(30, 30, 33),
		panel = Color3.fromRGB(34, 34, 37),
		panelAlt = Color3.fromRGB(42, 42, 46),

		border = Color3.fromRGB(55, 55, 60),
		divider = Color3.fromRGB(46, 46, 51),

		text = Color3.fromRGB(235, 235, 238),
		textMuted = Color3.fromRGB(145, 145, 152),
		textOnAccent = Color3.fromRGB(255, 255, 255),

		accent = Color3.fromRGB(66, 150, 255),
		accentHover = Color3.fromRGB(88, 166, 255),
		accentPressed = Color3.fromRGB(52, 130, 228),

		buttonBackground = Color3.fromRGB(52, 52, 57),
		buttonHover = Color3.fromRGB(64, 64, 70),
		buttonPressed = Color3.fromRGB(44, 44, 49),

		rowHover = Color3.fromRGB(46, 46, 51),
		rowSelected = Color3.fromRGB(40, 66, 102),

		danger = Color3.fromRGB(226, 86, 86),
		dangerHover = Color3.fromRGB(238, 104, 104),

		inputBackground = Color3.fromRGB(22, 22, 24),
		scrim = Color3.fromRGB(0, 0, 0),
	},
	scrimTransparency = 0.45,
}
