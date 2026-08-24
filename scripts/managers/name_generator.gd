## NameGenerator — procedural agent name generation: pairs a random first
## name with a random last name from fixed pools, drawn broadly enough
## (50x50 = 2500 combinations) that a roster of recruits doesn't feel
## repetitive. A static utility (RefCounted), not an autoload.
class_name NameGenerator
extends RefCounted

const FIRST_NAMES: PackedStringArray = [
	"Mara", "Iris", "Desmond", "Kalinda", "Elena", "Marcus", "Priya", "Kenji", "Amara", "Viktor",
	"Soraya", "Diego", "Fatima", "Lars", "Naledi", "Kwame", "Yuki", "Astrid", "Rashid", "Camila",
	"Dmitri", "Zara", "Oren", "Anya", "Tobias", "Chidi", "Mei", "Sven", "Layla", "Alessio",
	"Nadia", "Kaito", "Esperanza", "Bjorn", "Amina", "Rafael", "Tamsin", "Hiroshi", "Zuri", "Callum",
	"Selin", "Mateo", "Ingrid", "Boipelo", "Emrys", "Saoirse", "Renata", "Idris", "Katarzyna", "Milo",
]

const LAST_NAMES: PackedStringArray = [
	"Okonkwo", "Vance", "Ffrench", "Reyes", "Whitlock", "Adeyemi", "Kowalski", "Nakamura", "Singh", "Voss",
	"Delacroix", "Osei", "Marchetti", "Novak", "Abara", "Larsson", "Petrov", "Solis", "Haddad", "Byrne",
	"Falk", "Nkemelu", "Sato", "Reinholt", "Castellano", "Dubois", "Achebe", "Lindqvist", "Moreau", "Kaur",
	"Vasquez", "Winters", "Adebayo", "Horvat", "Takahashi", "Ibrahim", "Sorensen", "Rousseau", "Mbeki", "Callahan",
	"Weiss", "Novikov", "Farah", "Andersson", "Okafor", "Bergstrom", "Cruz", "Nasser", "Dlamini", "Bianchi",
]

static func generate_name() -> String:
	return "%s %s" % [
		FIRST_NAMES[randi() % FIRST_NAMES.size()],
		LAST_NAMES[randi() % LAST_NAMES.size()],
	]
