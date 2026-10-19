extends TestCase
## Couverture réelle de l'arbre complet, y compris variantes et améliorations du refuge.


func test_all_78_nodes_resolve_to_a_real_hd_icon() -> void:
	check_eq(GameDB.skill_nodes.size(), 78, "roster de l'arbre du Chasseur")
	for data: SkillNodeData in GameDB.skill_nodes.values():
		var icon: Texture2D = HunterTreeSkin.icon(data)
		check(icon != null, "icône présente pour %s" % data.id)
		if icon:
			check_eq(icon.get_size(), Vector2(512, 512), "définition HD de %s" % data.id)
			check(not icon.resource_path.is_empty(), "texture importée et non repli : %s" % data.id)
