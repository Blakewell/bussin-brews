extends Node
## Loads all JSON game data once. No game content lives in scripts.

var drinks: Array = []
var treats: Array = []
var drink_base_month := ""
var locations: Array = []
var weather: Dictionary = {}
var events: Array = []
var cpi_headlines: Dictionary = {}
var characters: Array = []
var generations: Dictionary = {}
var dialogue: Dictionary = {}
var cpi: Cpi
var economy: Economy


func _ready() -> void:
	var drink_data := _load("res://data/drinks.json")
	drinks = drink_data.drinks
	drink_base_month = drink_data.base_month
	treats = _load("res://data/treats.json").treats
	locations = _load("res://data/locations.json").locations
	weather = _load("res://data/weather.json")
	var event_data := _load("res://data/events.json")
	events = event_data.events
	cpi_headlines = event_data.cpi_headlines
	characters = _load("res://data/characters.json").characters
	generations = _load("res://data/generations.json").generations
	dialogue = _load("res://data/dialogue.json")
	cpi = Cpi.new(_load("res://data/cpi.json"))
	economy = Economy.new(cpi, drink_base_month)


func drink(id: String) -> Dictionary:
	for d in drinks:
		if d.id == id:
			return d
	return {}


## Any sellable item: a drink or a bakery treat.
func item(id: String) -> Dictionary:
	var d := drink(id)
	if not d.is_empty():
		return d
	for t in treats:
		if t.id == id:
			return t
	return {}


func location(id: String) -> Dictionary:
	for l in locations:
		if l.id == id:
			return l
	return {}


func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "Missing data file: " + path)
	var parsed = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary, "Bad JSON in " + path)
	return parsed
