class_name SequenceCsvCodec
extends RefCounted

## Codifica/decodifica linhas do exportador de sequências (campo de itens pode ter vírgulas).

const ITEMS_SEP := "|"


static func escape_field(value: String) -> String:
	if value.find(",") == -1 and value.find('"') == -1 and value.find("\n") == -1:
		return value
	return '"' + value.replace('"', '""') + '"'


static func items_field_from_backpack_csv(csv_text: String) -> String:
	var t := csv_text.strip_edges()
	if t.is_empty():
		return ""
	return t.replace(",", ITEMS_SEP).replace(" ", "")


static func backpack_csv_from_items_field(field: String) -> String:
	var t := field.strip_edges()
	if t.is_empty():
		return ""
	if t.find(ITEMS_SEP) != -1:
		var parts: PackedStringArray = PackedStringArray()
		for p in t.split(ITEMS_SEP, false):
			var s := p.strip_edges()
			if not s.is_empty():
				parts.append(s)
		return ", ".join(parts)
	return t


## Empacota IDs/atalhos (ex.: random_pool) no campo CSV com separador |.
static func items_field_from_packed(ids: PackedStringArray) -> String:
	if ids == null or ids.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for id in ids:
		var s := str(id).strip_edges()
		if not s.is_empty():
			parts.append(s)
	return ITEMS_SEP.join(parts)


## Interpreta o campo RND_POOL: lista |…| (novo) ou tamanho numérico (legado).
static func parse_random_pool_field(field: String) -> Dictionary:
	var t := field.strip_edges()
	if t.is_empty():
		return {"ids": PackedStringArray(), "legacy_size": 0}
	if t.is_valid_int() and t.find(ITEMS_SEP) == -1 and t.find("_") == -1 and not t.begins_with("item_"):
		return {"ids": PackedStringArray(), "legacy_size": maxi(0, int(t))}
	var ids: PackedStringArray = PackedStringArray()
	var sep := ITEMS_SEP if t.find(ITEMS_SEP) != -1 else ","
	for p in t.split(sep, false):
		var s := p.strip_edges()
		if not s.is_empty():
			ids.append(s)
	return {"ids": ids, "legacy_size": 0}


static func parse_csv_line(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var i := 0
	var n := line.length()
	var cell := ""
	var in_quotes := false
	while i < n:
		var ch := line[i]
		if in_quotes:
			if ch == '"':
				if i + 1 < n and line[i + 1] == '"':
					cell += '"'
					i += 2
					continue
				in_quotes = false
				i += 1
				continue
			cell += ch
			i += 1
			continue
		if ch == '"':
			in_quotes = true
			i += 1
			continue
		if ch == ",":
			out.append(cell)
			cell = ""
			i += 1
			continue
		cell += ch
		i += 1
	out.append(cell)
	return out
