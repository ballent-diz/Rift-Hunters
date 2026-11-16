class_name DraftCard
extends UpgradeData
## Carte de récompense de la v2 (docs/design/GAMEPLAY_V2_ARCHITECTURE.md) : sort, mutation, passif technique ou
## altération des règles, avec sa rareté. La rareté dit l'importance mécanique (Commun : décision simple ; Rare :
## changement de comportement ; Épique : mutation structurante ; Légendaire : exceptionnel), pas un multiplicateur.
## Les chances de tirage par rareté sont dans draft3d/tuning.tres.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS: Array[Color] = [Color("c8ccd8"), Color("6fb8ff"), Color("c58cff"), Color("ffc65a")]

@export var rarity: Rarity = Rarity.COMMON


static func rarity_of(data: UpgradeData) -> int:
	var card := data as DraftCard
	return int(card.rarity) if card != null else 0
