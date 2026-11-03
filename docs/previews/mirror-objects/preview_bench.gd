extends SceneTree
func _initialize():
    call_deferred("run")
func run():
    var out = OS.get_cmdline_user_args()[0]
    root.size = Vector2i(1280,720)
    var bg = Sprite2D.new()
    var ground = load("res://assets/environments/cascade_ruins/map_1.webp").get_image()
    assert(ground != null and not ground.is_empty())
    bg.texture = ImageTexture.create_from_image(ground.get_region(Rect2i(1200, 700, 1280, 720)))
    bg.position = Vector2(640,360)
    root.add_child(bg)
    var sheet = load("res://assets/sprites/enemies/skitterling/skitterling_sheet.png").get_image()
    assert(sheet != null and not sheet.is_empty())
    var witness = ImageTexture.create_from_image(sheet.get_region(Rect2i(0, 0, 64, 64)))
    for i in range(90):
        var enemy = Sprite2D.new()
        enemy.texture = witness
        enemy.position = Vector2(24+(i%18)*70,48+(i/18)*125)
        enemy.scale = Vector2.ONE * 0.6
        enemy.modulate.a = 0.65
        root.add_child(enemy)
    var crystal_scene = load("res://assets/vfx/objects/mirror_crystal/mirror_crystal.tscn")
    var portal_scene = load("res://assets/vfx/objects/mirror_portal/mirror_portal.tscn")
    assert(crystal_scene != null and portal_scene != null)
    var crystal = crystal_scene.instantiate()
    crystal.position = Vector2(380,420)
    crystal.scale = Vector2.ONE*1.3333
    root.add_child(crystal)
    var portal = portal_scene.instantiate()
    portal.position = Vector2(830,420)
    portal.scale = Vector2.ONE*1.3333
    root.add_child(portal)
    var twin = portal_scene.instantiate()
    twin.position = Vector2(1060,420)
    twin.scale = Vector2.ONE*1.3333
    root.add_child(twin)
    for obj in [crystal,portal,twin]:
        assert(obj.get_child_count()==0)
        obj.release()
        assert(not obj.visible)
    var label = Label.new()
    label.position = Vector2(24,18)
    label.add_theme_color_override("font_color",Color.WHITE)
    label.add_theme_color_override("font_shadow_color",Color.BLACK)
    label.add_theme_font_size_override("font_size",22)
    root.add_child(label)
    var cs = ["idle","charged","burst","debris"]
    var ps = ["active","cooldown","enter","exit"]
    for state in range(4):
        crystal.set_state(StringName(cs[state]))
        portal.set_state(StringName(ps[state]))
        twin.tint = portal.tint
        twin.set_state(StringName(ps[state]))
        for frame in range(12):
            var t = frame/12.0 * 0.64
            crystal.seek_visual(t)
            portal.seek_visual(t)
            twin.seek_visual(t)
            label.text = "Banc visuel Godot - 90 sprites temoins, pas un combat | %s / %s" % [cs[state],ps[state]]
            await process_frame
            await RenderingServer.frame_post_draw
            var err = root.get_texture().get_image().save_png(out+"/frame_%02d.png" % (state*12+frame))
            assert(err==OK)
    var sv = SubViewport.new()
    sv.size = Vector2i(256,256)
    sv.transparent_bg = true
    sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(sv)
    var actor = crystal_scene.instantiate()
    actor.position = Vector2(128,220)
    actor.ray_length=70.0
    actor.scale=Vector2.ONE
    sv.add_child(actor)
    for state in range(4):
        actor.set_state(StringName(cs[state]))
        for f in range(6):
            actor.seek_visual(f/6.0*0.64)
            await process_frame
            await RenderingServer.frame_post_draw
            assert(sv.get_texture().get_image().save_png(out+"/alpha_%d_%d.png" % [state,f])==OK)
    check_finished(crystal, portal)
    print("OK B5/B6 : chargement, 4 etats, seek, release/reuse, 48 frames, 24 poses alpha, 90 sprites temoins")
    quit(0)

# Vérification des signatures existantes, sans modifier les objets.
func check_finished(crystal, portal):
    var count = {"crystal": 0, "portal": 0}
    crystal.finished.connect(func(): count["crystal"] += 1)
    portal.finished.connect(func(_state): count["portal"] += 1)
    for state in ["burst", "debris"]:
        crystal.play(StringName(state))
        var before = count["crystal"]
        crystal.seek_visual(10.0)
        crystal._process(10.0)
        assert(count["crystal"] == before)
        crystal.play(StringName(state))
        crystal._process(10.0)
        crystal._process(10.0)
        assert(count["crystal"] == before + 1)
    for state in ["cooldown", "enter", "exit"]:
        portal.play(StringName(state))
        var before = count["portal"]
        portal.seek_visual(10.0)
        portal._process(10.0)
        assert(count["portal"] == before)
        portal.play(StringName(state))
        portal._process(10.0)
        portal._process(10.0)
        assert(count["portal"] == before + 1)
    for obj in [crystal, portal]:
        obj.release()
        assert(not obj.visible and not obj.is_processing())
    crystal.play(&"idle")
    portal.play(&"active")
    assert(crystal.visible and portal.visible)
    print("OK API B5/B6 : signaux finished, émission unique, seek sans signal, release, play/reuse")
