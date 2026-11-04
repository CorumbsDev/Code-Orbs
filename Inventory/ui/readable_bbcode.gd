class_name ReadableBbcode
## A KiwiSoda não tem negrito real; o [b] sintético engrossa o traço e vira mancha.
## Converte ênfase em cor + tamanho leve, sem trocar a fonte.


const EMPHASIS_OPEN := "[color=#FFE08A]"
const EMPHASIS_CLOSE := "[/color]"


static func for_ui(bbcode: String) -> String:
	if bbcode.is_empty():
		return bbcode
	var s := bbcode
	s = s.replace("[b]", EMPHASIS_OPEN)
	s = s.replace("[/b]", EMPHASIS_CLOSE)
	s = s.replace("[B]", EMPHASIS_OPEN)
	s = s.replace("[/B]", EMPHASIS_CLOSE)
	return s


## Remove tags BBCode para texto puro (ex.: console Ver Script / comentários Python).
static func strip_tags(bbcode: String) -> String:
	if bbcode.is_empty():
		return bbcode
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	return re.sub(bbcode, "", true).strip_edges()
