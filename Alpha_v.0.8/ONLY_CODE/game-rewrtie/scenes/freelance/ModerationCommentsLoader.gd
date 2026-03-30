class_name ModerationCommentsLoader
extends RefCounted

const DEFAULT_TEMPLATE_PATH := "res://resources/freelance/moderation_comments_template.json"


static func load_comments(path: String = DEFAULT_TEMPLATE_PATH) -> Array:
	var payload: Dictionary = load_comments_payload(path)
	var comments: Array[Dictionary] = []
	var raw_comments: Variant = payload.get("comments", [])

	if raw_comments is Array:
		for entry in raw_comments:
			if entry is Dictionary:
				comments.append(entry.duplicate(true))

	return comments


static func load_comments_payload(path: String = DEFAULT_TEMPLATE_PATH) -> Dictionary:
	var target_path: String = path if not path.is_empty() else DEFAULT_TEMPLATE_PATH

	if not FileAccess.file_exists(target_path):
		return {
			"version": 1,
			"comments": [],
		}

	var file := FileAccess.open(target_path, FileAccess.READ)

	if file == null:
		return {
			"version": 1,
			"comments": [],
		}

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if not (parsed is Dictionary) and not (parsed is Array):
		return {
			"version": 1,
			"comments": [],
		}

	var version: int = 1
	var normalized_comments: Array[Dictionary] = []
	var raw_comments: Variant = []

	if parsed is Dictionary:
		version = int(parsed.get("version", 1))
		raw_comments = parsed.get("comments", [])
	else:
		raw_comments = parsed

	if raw_comments is Array:
		for raw_entry in raw_comments:
			if not (raw_entry is Dictionary):
				continue

			var normalized_entry: Dictionary = normalize_comment_entry(raw_entry)

			if normalized_entry.is_empty():
				continue

			normalized_comments.append(normalized_entry)

	return {
		"version": version,
		"comments": normalized_comments,
	}


static func normalize_comment_entry(entry: Dictionary) -> Dictionary:
	var text: String = String(entry.get("text", "")).strip_edges()

	if text.is_empty():
		return {}

	var category: String = String(entry.get("category", "uncategorized")).strip_edges()

	if category.is_empty():
		category = "uncategorized"

	var normalized_tags: Array[String] = []
	var raw_tags: Variant = entry.get("tags", [])

	if raw_tags is Array:
		for raw_tag in raw_tags:
			var tag: String = String(raw_tag).strip_edges()

			if tag.is_empty():
				continue

			normalized_tags.append(tag)

	return {
		"text": text,
		"category": category,
		"should_reject": bool(entry.get("should_reject", false)),
		"tags": normalized_tags,
	}
