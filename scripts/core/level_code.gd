class_name LevelCode
extends RefCounted
## Short shareable level codes like "N-8F3K2Q": difficulty letter plus a 30-bit seed in base 32.

const ALPHABET := "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const SEED_MASK := (1 << 30) - 1


static func encode(level_seed: int, difficulty: int) -> String:
	var s := level_seed & SEED_MASK
	var out := ""
	for i in 6:
		out = ALPHABET[s & 31] + out
		s >>= 5
	return Difficulty.LETTERS[difficulty] + "-" + out


## Returns {"seed": int, "difficulty": int}, or an empty dictionary if the code is not valid.
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if c.length() != 7:
		return {}
	var d := Difficulty.LETTERS.find(c[0])
	if d < 0:
		return {}
	var s := 0
	for i in range(1, 7):
		var v := ALPHABET.find(c[i])
		if v < 0:
			return {}
		s = (s << 5) | v
	return {"seed": s, "difficulty": d}
