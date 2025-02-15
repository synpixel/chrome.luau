export type KeyDefinition = {
	code: string?,
	key: Key,
	key_code: number?,
	text: string?,
}

export type Key =
	"Tab"
	| "*"
	| "MediaPlayPause"
	| "`"
	| "Help"
	| "End"
	| "NonConvert"
	| "Alt"
	| '"'
	| "MediaTrackPrevious"
	| "F2"
	| "AltGraph"
	| ","
	| "|"
	| "Execute"
	| "t"
	| "Enter"
	| "."
	| "Meta"
	| "?"
	| "ArrowDown"
	| "G"
	| "'"
	| "<"
	| "e"
	| ""
	| "ArrowUp"
	| ":"
	| "Attn"
	| "PageUp"
	| "Y"
	| "X"
	| "6"
	| "W"
	| "m"
	| "Enter"
	| "Enter"
	| "-"
	| "U"
	| "u"
	| "EraseEof"
	| "R"
	| "+"
	| "P"
	| "F5"
	| "["
	| "ZoomOut"
	| "M"
	| "F22"
	| "("
	| "K"
	| "C"
	| "F"
	| "\\"
	| "ArrowLeft"
	| "H"
	| "!"
	| "Meta"
	| "#"
	| "F21"
	| "%"
	| "$"
	| "j"
	| "&"
	| ")"
	| "i"
	| "F20"
	| "*"
	| "-"
	| "="
	| "/"
	| "]"
	| "1"
	| "0"
	| "3"
	| "2"
	| "5"
	| "4"
	| "7"
	| "6"
	| "9"
	| "8"
	| ";"
	| "="
	| "="
	| "F16"
	| "Pause"
	| ">"
	| "A"
	| "@"
	| "MediaTrackNext"
	| "B"
	| "E"
	| "D"
	| "Print"
	| "Convert"
	| "I"
	| "CapsLock"
	| "Home"
	| "J"
	| "ArrowUp"
	| "L"
	| "O"
	| "N"
	| "Q"
	| "F23"
	| "S"
	| "9"
	| "y"
	| "T"
	| "F7"
	| "V"
	| "s"
	| "v"
	| "End"
	| "Z"
	| "]"
	| "_"
	| "^"
	| "Alt"
	| "`"
	| "c"
	| "Cancel"
	| "e"
	| "d"
	| "g"
	| "f"
	| "i"
	| "Backspace"
	| "k"
	| "j"
	| "m"
	| "l"
	| "F24"
	| "n"
	| "h"
	| "ArrowLeft"
	| "s"
	| "r"
	| "Escape"
	| "PageUp"
	| "w"
	| "g"
	| "o"
	| "x"
	| "{"
	| "F12"
	| "}"
	| "PageDown"
	| "+"
	| "~"
	| "F11"
	| "ArrowRight"
	| "Insert"
	| "z"
	| "F19"
	| "y"
	| "F15"
	| "p"
	| "v"
	| "4"
	| "Alt"
	| "ExSel"
	| "'"
	| "t"
	| "ArrowDown"
	| "q"
	| "-"
	| "ArrowRight"
	| "p"
	| "Insert"
	| "Shift"
	| "Enter"
	| "a"
	| "o"
	| "h"
	| "b"
	| "a"
	| "ContextMenu"
	| "F9"
	| "Shift"
	| "Home"
	| "f"
	| " "
	| "ModeChange"
	| "Accept"
	| "l"
	| ","
	| "Control"
	| "7"
	| "F18"
	| "Shift"
	| "r"
	| "Clear"
	| "Cancel"
	| "CrSel"
	| "["
	| "Eject"
	| "/"
	| "/"
	| "."
	| "AudioVolumeMute"
	| "Power"
	| "k"
	| "MediaStop"
	| "d"
	| "AudioVolumeDown"
	| ";"
	| "q"
	| "NumLock"
	| "Control"
	| "F17"
	| "z"
	| "F8"
	| "F13"
	| "Clear"
	| "Meta"
	| "F10"
	| "0"
	| "Execute"
	| "F6"
	| "PageDown"
	| "PrintScreen"
	| "F4"
	| "ScrollLock"
	| "Control"
	| "F1"
	| " "
	| "CrSel"
	| "Play"
	| "F14"
	| "u"
	| "x"
	| "w"
	| "F3"
	| "n"
	| "AudioVolumeUp"
	| "c"
	| "b"
	| "8"
	| ""
	| "5"
	| "Delete"
	| "2"
	| "1"
	| "3"
	| "Select"

local qwerty: { KeyDefinition } = {
	{
		code = "Tab",
		key = "Tab",
		key_code = 9,
	},
	{
		code = "NumpadMultiply",
		key = "*",
		key_code = 106,
	},
	{
		code = "MediaPlayPause",
		key = "MediaPlayPause",
		key_code = 179,
	},
	{
		code = "Backquote",
		key = "`",
		key_code = 192,
	},
	{
		code = "Help",
		key = "Help",
		key_code = 6,
	},
	{
		code = "End",
		key = "End",
		key_code = 35,
	},
	{
		code = "NonConvert",
		key = "NonConvert",
		key_code = 29,
	},
	{
		code = "AltRight",
		key = "Alt",
		key_code = 18,
	},
	{
		code = "Quote",
		key = '"',
		key_code = 222,
	},
	{
		code = "MediaTrackPrevious",
		key = "MediaTrackPrevious",
		key_code = 177,
	},
	{
		code = "F2",
		key = "F2",
		key_code = 113,
	},
	{
		code = "AltGraph",
		key = "AltGraph",
		key_code = 225,
	},
	{
		code = "Comma",
		key = ",",
		key_code = 188,
	},
	{
		code = "Backslash",
		key = "|",
		key_code = 220,
	},
	{
		code = "Open",
		key = "Execute",
		key_code = 43,
	},
	{
		code = "KeyT",
		key = "t",
		key_code = 84,
	},
	{
		code = "Enter",
		key = "Enter",
		key_code = 13,
		text = "\r",
	},
	{
		code = "Period",
		key = ".",
		key_code = 190,
	},
	{
		code = "MetaLeft",
		key = "Meta",
		key_code = 91,
	},
	{
		code = "Slash",
		key = "?",
		key_code = 191,
	},
	{
		code = "ArrowDown",
		key = "ArrowDown",
		key_code = 40,
	},
	{
		code = "KeyG",
		key = "G",
		key_code = 71,
	},
	{
		code = "Quote",
		key = "'",
		key_code = 222,
	},
	{
		code = "Comma",
		key = "<",
		key_code = 188,
	},
	{
		code = "KeyE",
		key = "e",
		key_code = 69,
	},
	{
		code = "NumpadDecimal",
		key = "",
		key_code = 46,
	},
	{
		code = "ArrowUp",
		key = "ArrowUp",
		key_code = 38,
	},
	{
		code = "Semicolon",
		key = ":",
		key_code = 186,
	},
	{
		key = "Attn",
		key_code = 246,
	},
	{
		code = "PageUp",
		key = "PageUp",
		key_code = 33,
	},
	{
		code = "KeyY",
		key = "Y",
		key_code = 89,
	},
	{
		code = "KeyX",
		key = "X",
		key_code = 88,
	},
	{
		code = "Digit6",
		key = "6",
		key_code = 54,
	},
	{
		code = "KeyW",
		key = "W",
		key_code = 87,
	},
	{
		code = "KeyM",
		key = "m",
		key_code = 77,
	},
	{
		code = "Enter",
		key = "Enter",
		key_code = 13,
		text = "\r",
	},
	{
		code = "Enter",
		key = "Enter",
		key_code = 13,
		text = "\r",
	},
	{
		code = "NumpadSubtract",
		key = "-",
		key_code = 109,
	},
	{
		code = "KeyU",
		key = "U",
		key_code = 85,
	},
	{
		code = "KeyU",
		key = "u",
		key_code = 85,
	},
	{
		key = "EraseEof",
		key_code = 249,
	},
	{
		code = "KeyR",
		key = "R",
		key_code = 82,
	},
	{
		code = "NumpadAdd",
		key = "+",
		key_code = 107,
	},
	{
		code = "KeyP",
		key = "P",
		key_code = 80,
	},
	{
		code = "F5",
		key = "F5",
		key_code = 116,
	},
	{
		code = "BracketLeft",
		key = "[",
		key_code = 219,
	},
	{
		key = "ZoomOut",
		key_code = 251,
	},
	{
		code = "KeyM",
		key = "M",
		key_code = 77,
	},
	{
		code = "F22",
		key = "F22",
		key_code = 133,
	},
	{
		code = "Digit9",
		key = "(",
		key_code = 57,
	},
	{
		code = "KeyK",
		key = "K",
		key_code = 75,
	},
	{
		code = "KeyC",
		key = "C",
		key_code = 67,
	},
	{
		code = "KeyF",
		key = "F",
		key_code = 70,
	},
	{
		code = "Backslash",
		key = "\\",
		key_code = 220,
	},
	{
		code = "Numpad4",
		key = "ArrowLeft",
		key_code = 37,
	},
	{
		code = "KeyH",
		key = "H",
		key_code = 72,
	},
	{
		code = "Digit1",
		key = "!",
		key_code = 49,
	},
	{
		code = "MetaLeft",
		key = "Meta",
		key_code = 91,
	},
	{
		code = "Digit3",
		key = "#",
		key_code = 51,
	},
	{
		code = "F21",
		key = "F21",
		key_code = 132,
	},
	{
		code = "Digit5",
		key = "%",
		key_code = 53,
	},
	{
		code = "Digit4",
		key = "$",
		key_code = 52,
	},
	{
		code = "KeyJ",
		key = "j",
		key_code = 74,
	},
	{
		code = "Digit7",
		key = "&",
		key_code = 55,
	},
	{
		code = "Digit0",
		key = ")",
		key_code = 48,
	},
	{
		code = "KeyI",
		key = "i",
		key_code = 73,
	},
	{
		code = "F20",
		key = "F20",
		key_code = 131,
	},
	{
		code = "NumpadMultiply",
		key = "*",
		key_code = 106,
	},
	{
		code = "NumpadSubtract",
		key = "-",
		key_code = 109,
	},
	{
		code = "NumpadEqual",
		key = "=",
		key_code = 187,
	},
	{
		code = "NumpadDivide",
		key = "/",
		key_code = 111,
	},
	{
		code = "BracketRight",
		key = "]",
		key_code = 221,
	},
	{
		code = "Digit1",
		key = "1",
		key_code = 49,
	},
	{
		code = "Digit0",
		key = "0",
		key_code = 48,
	},
	{
		code = "Digit3",
		key = "3",
		key_code = 51,
	},
	{
		code = "Digit2",
		key = "2",
		key_code = 50,
	},
	{
		code = "Digit5",
		key = "5",
		key_code = 53,
	},
	{
		code = "Digit4",
		key = "4",
		key_code = 52,
	},
	{
		code = "Digit7",
		key = "7",
		key_code = 55,
	},
	{
		code = "Digit6",
		key = "6",
		key_code = 54,
	},
	{
		code = "Digit9",
		key = "9",
		key_code = 57,
	},
	{
		code = "Digit8",
		key = "8",
		key_code = 56,
	},
	{
		code = "Semicolon",
		key = ";",
		key_code = 186,
	},
	{
		code = "Equal",
		key = "=",
		key_code = 187,
	},
	{
		code = "Equal",
		key = "=",
		key_code = 187,
	},
	{
		code = "F16",
		key = "F16",
		key_code = 127,
	},
	{
		code = "Pause",
		key = "Pause",
		key_code = 19,
	},
	{
		code = "Period",
		key = ">",
		key_code = 190,
	},
	{
		code = "KeyA",
		key = "A",
		key_code = 65,
	},
	{
		code = "Digit2",
		key = "@",
		key_code = 50,
	},
	{
		code = "MediaTrackNext",
		key = "MediaTrackNext",
		key_code = 176,
	},
	{
		code = "KeyB",
		key = "B",
		key_code = 66,
	},
	{
		code = "KeyE",
		key = "E",
		key_code = 69,
	},
	{
		code = "KeyD",
		key = "D",
		key_code = 68,
	},
	{
		key = "Print",
		key_code = 42,
	},
	{
		code = "Convert",
		key = "Convert",
		key_code = 28,
	},
	{
		code = "KeyI",
		key = "I",
		key_code = 73,
	},
	{
		code = "CapsLock",
		key = "CapsLock",
		key_code = 20,
	},
	{
		code = "Home",
		key = "Home",
		key_code = 36,
	},
	{
		code = "KeyJ",
		key = "J",
		key_code = 74,
	},
	{
		code = "Numpad8",
		key = "ArrowUp",
		key_code = 38,
	},
	{
		code = "KeyL",
		key = "L",
		key_code = 76,
	},
	{
		code = "KeyO",
		key = "O",
		key_code = 79,
	},
	{
		code = "KeyN",
		key = "N",
		key_code = 78,
	},
	{
		code = "KeyQ",
		key = "Q",
		key_code = 81,
	},
	{
		code = "F23",
		key = "F23",
		key_code = 134,
	},
	{
		code = "KeyS",
		key = "S",
		key_code = 83,
	},
	{
		code = "Digit9",
		key = "9",
		key_code = 57,
	},
	{
		code = "KeyY",
		key = "y",
		key_code = 89,
	},
	{
		code = "KeyT",
		key = "T",
		key_code = 84,
	},
	{
		code = "F7",
		key = "F7",
		key_code = 118,
	},
	{
		code = "KeyV",
		key = "V",
		key_code = 86,
	},
	{
		code = "KeyS",
		key = "s",
		key_code = 83,
	},
	{
		code = "KeyV",
		key = "v",
		key_code = 86,
	},
	{
		code = "Numpad1",
		key = "End",
		key_code = 35,
	},
	{
		code = "KeyZ",
		key = "Z",
		key_code = 90,
	},
	{
		code = "BracketRight",
		key = "]",
		key_code = 221,
	},
	{
		code = "Backslash",
		key = "\\",
		key_code = 220,
	},
	{
		code = "Minus",
		key = "_",
		key_code = 189,
	},
	{
		code = "Digit6",
		key = "^",
		key_code = 54,
	},
	{
		code = "AltLeft",
		key = "Alt",
		key_code = 18,
	},
	{
		code = "Backquote",
		key = "`",
		key_code = 192,
	},
	{
		code = "KeyC",
		key = "c",
		key_code = 67,
	},
	{
		code = "Abort",
		key = "Cancel",
		key_code = 3,
	},
	{
		code = "KeyE",
		key = "e",
		key_code = 69,
	},
	{
		code = "KeyD",
		key = "d",
		key_code = 68,
	},
	{
		code = "KeyG",
		key = "g",
		key_code = 71,
	},
	{
		code = "KeyF",
		key = "f",
		key_code = 70,
	},
	{
		code = "KeyI",
		key = "i",
		key_code = 73,
	},
	{
		code = "Backspace",
		key = "Backspace",
		key_code = 8,
	},
	{
		code = "KeyK",
		key = "k",
		key_code = 75,
	},
	{
		code = "KeyJ",
		key = "j",
		key_code = 74,
	},
	{
		code = "KeyM",
		key = "m",
		key_code = 77,
	},
	{
		code = "KeyL",
		key = "l",
		key_code = 76,
	},
	{
		code = "F24",
		key = "F24",
		key_code = 135,
	},
	{
		code = "KeyN",
		key = "n",
		key_code = 78,
	},
	{
		code = "KeyH",
		key = "h",
		key_code = 72,
	},
	{
		code = "ArrowLeft",
		key = "ArrowLeft",
		key_code = 37,
	},
	{
		code = "KeyS",
		key = "s",
		key_code = 83,
	},
	{
		code = "KeyR",
		key = "r",
		key_code = 82,
	},
	{
		code = "Escape",
		key = "Escape",
		key_code = 27,
	},
	{
		code = "Numpad9",
		key = "PageUp",
		key_code = 33,
	},
	{
		code = "KeyW",
		key = "w",
		key_code = 87,
	},
	{
		code = "KeyG",
		key = "g",
		key_code = 71,
	},
	{
		code = "KeyO",
		key = "o",
		key_code = 79,
	},
	{
		code = "KeyX",
		key = "x",
		key_code = 88,
	},
	{
		code = "BracketLeft",
		key = "{",
		key_code = 219,
	},
	{
		code = "F12",
		key = "F12",
		key_code = 123,
	},
	{
		code = "BracketRight",
		key = "}",
		key_code = 221,
	},
	{
		code = "Numpad3",
		key = "PageDown",
		key_code = 34,
	},
	{
		code = "NumpadAdd",
		key = "+",
		key_code = 107,
	},
	{
		code = "Backquote",
		key = "~",
		key_code = 192,
	},
	{
		code = "F11",
		key = "F11",
		key_code = 122,
	},
	{
		code = "ArrowRight",
		key = "ArrowRight",
		key_code = 39,
	},
	{
		code = "Numpad0",
		key = "Insert",
		key_code = 45,
	},
	{
		code = "KeyZ",
		key = "z",
		key_code = 90,
	},
	{
		code = "F19",
		key = "F19",
		key_code = 130,
	},
	{
		code = "KeyY",
		key = "y",
		key_code = 89,
	},
	{
		code = "F15",
		key = "F15",
		key_code = 126,
	},
	{
		code = "KeyP",
		key = "p",
		key_code = 80,
	},
	{
		code = "KeyV",
		key = "v",
		key_code = 86,
	},
	{
		code = "Digit4",
		key = "4",
		key_code = 52,
	},
	{
		code = "AltLeft",
		key = "Alt",
		key_code = 18,
	},
	{
		key = "ExSel",
		key_code = 248,
	},
	{
		code = "Quote",
		key = "'",
		key_code = 222,
	},
	{
		code = "KeyT",
		key = "t",
		key_code = 84,
	},
	{
		code = "Numpad2",
		key = "ArrowDown",
		key_code = 40,
	},
	{
		code = "KeyQ",
		key = "q",
		key_code = 81,
	},
	{
		code = "Minus",
		key = "-",
		key_code = 189,
	},
	{
		code = "Numpad6",
		key = "ArrowRight",
		key_code = 39,
	},
	{
		code = "KeyP",
		key = "p",
		key_code = 80,
	},
	{
		code = "Insert",
		key = "Insert",
		key_code = 45,
	},
	{
		code = "ShiftRight",
		key = "Shift",
		key_code = 16,
	},
	{
		code = "NumpadEnter",
		key = "Enter",
		key_code = 13,
		text = "\r",
	},
	{
		code = "KeyA",
		key = "a",
		key_code = 65,
	},
	{
		code = "KeyO",
		key = "o",
		key_code = 79,
	},
	{
		code = "KeyH",
		key = "h",
		key_code = 72,
	},
	{
		code = "KeyB",
		key = "b",
		key_code = 66,
	},
	{
		code = "KeyA",
		key = "a",
		key_code = 65,
	},
	{
		code = "ContextMenu",
		key = "ContextMenu",
		key_code = 93,
	},
	{
		code = "F9",
		key = "F9",
		key_code = 120,
	},
	{
		code = "ShiftLeft",
		key = "Shift",
		key_code = 16,
	},
	{
		code = "Numpad7",
		key = "Home",
		key_code = 36,
	},
	{
		code = "KeyF",
		key = "f",
		key_code = 70,
	},
	{
		code = "Space",
		key = " ",
		key_code = 32,
	},
	{
		key = "ModeChange",
		key_code = 31,
	},
	{
		key = "Accept",
		key_code = 30,
	},
	{
		code = "KeyL",
		key = "l",
		key_code = 76,
	},
	{
		code = "Comma",
		key = ",",
		key_code = 188,
	},
	{
		code = "ControlLeft",
		key = "Control",
		key_code = 17,
	},
	{
		code = "Digit7",
		key = "7",
		key_code = 55,
	},
	{
		code = "F18",
		key = "F18",
		key_code = 129,
	},
	{
		code = "ShiftLeft",
		key = "Shift",
		key_code = 16,
	},
	{
		code = "KeyR",
		key = "r",
		key_code = 82,
	},
	{
		code = "Numpad5",
		key = "Clear",
		key_code = 12,
	},
	{
		code = "Abort",
		key = "Cancel",
		key_code = 3,
	},
	{
		code = "Props",
		key = "CrSel",
		key_code = 247,
	},
	{
		code = "BracketLeft",
		key = "[",
		key_code = 219,
	},
	{
		code = "Eject",
		key = "Eject",
	},
	{
		code = "Slash",
		key = "/",
		key_code = 191,
	},
	{
		code = "NumpadDivide",
		key = "/",
		key_code = 111,
	},
	{
		code = "Period",
		key = ".",
		key_code = 190,
	},
	{
		code = "AudioVolumeMute",
		key = "AudioVolumeMute",
		key_code = 173,
	},
	{
		code = "Power",
		key = "Power",
	},
	{
		code = "KeyK",
		key = "k",
		key_code = 75,
	},
	{
		code = "MediaStop",
		key = "MediaStop",
		key_code = 178,
	},
	{
		code = "KeyD",
		key = "d",
		key_code = 68,
	},
	{
		code = "AudioVolumeDown",
		key = "AudioVolumeDown",
		key_code = 174,
	},
	{
		code = "Semicolon",
		key = ";",
		key_code = 186,
	},
	{
		code = "KeyQ",
		key = "q",
		key_code = 81,
	},
	{
		code = "NumLock",
		key = "NumLock",
		key_code = 144,
	},
	{
		code = "ControlLeft",
		key = "Control",
		key_code = 17,
	},
	{
		code = "F17",
		key = "F17",
		key_code = 128,
	},
	{
		code = "KeyZ",
		key = "z",
		key_code = 90,
	},
	{
		code = "F8",
		key = "F8",
		key_code = 119,
	},
	{
		code = "F13",
		key = "F13",
		key_code = 124,
	},
	{
		code = "Numpad5",
		key = "Clear",
		key_code = 12,
	},
	{
		code = "MetaRight",
		key = "Meta",
		key_code = 92,
	},
	{
		code = "F10",
		key = "F10",
		key_code = 121,
	},
	{
		code = "Digit0",
		key = "0",
		key_code = 48,
	},
	{
		code = "Open",
		key = "Execute",
		key_code = 43,
	},
	{
		code = "F6",
		key = "F6",
		key_code = 117,
	},
	{
		code = "PageDown",
		key = "PageDown",
		key_code = 34,
	},
	{
		code = "PrintScreen",
		key = "PrintScreen",
		key_code = 44,
	},
	{
		code = "F4",
		key = "F4",
		key_code = 115,
	},
	{
		code = "ScrollLock",
		key = "ScrollLock",
		key_code = 145,
	},
	{
		code = "ControlRight",
		key = "Control",
		key_code = 17,
	},
	{
		code = "F1",
		key = "F1",
		key_code = 112,
	},
	{
		code = "Space",
		key = " ",
		key_code = 32,
	},
	{
		code = "Props",
		key = "CrSel",
		key_code = 247,
	},
	{
		key = "Play",
		key_code = 250,
	},
	{
		code = "F14",
		key = "F14",
		key_code = 125,
	},
	{
		code = "KeyU",
		key = "u",
		key_code = 85,
	},
	{
		code = "KeyX",
		key = "x",
		key_code = 88,
	},
	{
		code = "KeyW",
		key = "w",
		key_code = 87,
	},
	{
		code = "F3",
		key = "F3",
		key_code = 114,
	},
	{
		code = "KeyN",
		key = "n",
		key_code = 78,
	},
	{
		code = "AudioVolumeUp",
		key = "AudioVolumeUp",
		key_code = 175,
	},
	{
		code = "KeyC",
		key = "c",
		key_code = 67,
	},
	{
		code = "KeyB",
		key = "b",
		key_code = 66,
	},
	{
		code = "Digit8",
		key = "8",
		key_code = 56,
	},
	{
		code = "NumpadDecimal",
		key = "",
		key_code = 46,
	},
	{
		code = "Digit5",
		key = "5",
		key_code = 53,
	},
	{
		code = "Delete",
		key = "Delete",
		key_code = 46,
	},
	{
		code = "Digit2",
		key = "2",
		key_code = 50,
	},
	{
		code = "Digit1",
		key = "1",
		key_code = 49,
	},
	{
		code = "Digit3",
		key = "3",
		key_code = 51,
	},
	{
		code = "Select",
		key = "Select",
		key_code = 41,
	},
}

local function get_key_definition(key: Key): KeyDefinition?
	for _, definition in qwerty do
		if definition.key == key then
			return definition
		end
	end

	return nil
end

return {
	qwerty = qwerty,
	get_key_definition = get_key_definition,
}
