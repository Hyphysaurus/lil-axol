extends Node
## Leaderboard — tiny Supabase REST client for the shared high-score table ("the tide
## board"). The anon key is public by design; Row Level Security on the table only allows
## reading scores and inserting sanity-checked rows (name 1..12 chars, score 0..1M).
## Friendly-competition grade, not tamper-proof. Works on desktop and web (CORS is open
## on Supabase's REST endpoint).

const URL := "https://mxefgdecmauqfyklsylz.supabase.co/rest/v1/lilaxol_scores"
const KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14ZWZnZGVjbWF1cWZ5a2xzeWx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyODYwMjgsImV4cCI6MjA5MTg2MjAyOH0.7H-ooxHIhWKFQTwvRNPotZmtJkThLvKgflYPg7RILPc"

## Post a score. Returns true on success.
func submit(player: String, score: int) -> bool:
	var r := HTTPRequest.new()
	r.timeout = 8.0              # web: a stalled fetch must fail, not hang "sending..." forever
	add_child(r)
	var body := JSON.stringify({"name": player.substr(0, 12), "score": score})
	if r.request(URL, _headers(true), HTTPClient.METHOD_POST, body) != OK:
		r.queue_free()
		return false
	var res: Array = await r.request_completed
	r.queue_free()
	return res[1] >= 200 and res[1] < 300

## Top scores, best first: [{name, score}, ...]. Empty array on any failure.
func fetch_top(limit := 10) -> Array:
	var r := HTTPRequest.new()
	r.timeout = 8.0              # web: bail after 8s instead of awaiting a dead request forever
	add_child(r)
	var url := "%s?select=name,score&order=score.desc&limit=%d" % [URL, limit]
	if r.request(url, _headers(false), HTTPClient.METHOD_GET) != OK:
		r.queue_free()
		return []
	var res: Array = await r.request_completed
	r.queue_free()
	if res[1] != 200:
		return []
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return parsed if parsed is Array else []

func _headers(posting: bool) -> PackedStringArray:
	var h := PackedStringArray(["apikey: " + KEY, "Authorization: Bearer " + KEY])
	if posting:
		h.append("Content-Type: application/json")
		h.append("Prefer: return=minimal")
	return h
