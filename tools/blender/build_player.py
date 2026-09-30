"""Construit le personnage joueur : maillage low-poly à pièces rigides, squelette simple,
Empty « WeaponSocket » dans la main droite, et 12 animations (pistes NLA) :
idle, walk, run, jump, fall, roll, attack_1, attack_2, attack_3, cast, hurt, death.
Sorties : assets/blender/player.blend et assets/models/player.glb.

Repère Blender : +X = droite du personnage, +Y = avant, +Z = haut.
Rotations (axe monde, degrés) : autour de X, un membre pendant part vers l'avant pour un
angle positif, le buste se penche en arrière ; autour de Z, un angle positif tourne vers la
gauche ; autour de Y, un angle négatif écarte le bras droit (positif pour le gauche).
"""

import importlib
import sys

sys.path.insert(0, r"C:\Users\psamf\Documents\zeldalike\tools\blender")
import lowpoly as lp  # noqa: E402

importlib.reload(lp)
import bpy  # noqa: E402

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)

lp.reset_scene()

# ------------------------------------------------------------------ matériaux
skin = lp.material("Peau", (1.0, 0.78, 0.62))
tunic = lp.material("Tunique", (0.2, 0.56, 0.2))
cap_mat = lp.material("Bonnet", (0.14, 0.45, 0.16))
tights = lp.material("Collant", (0.92, 0.89, 0.78))
leather = lp.material("Cuir", (0.36, 0.21, 0.1))
boots = lp.material("Bottes", (0.3, 0.17, 0.08))
hair = lp.material("Cheveux", (0.96, 0.8, 0.34))
eyes = lp.material("Yeux", (0.05, 0.12, 0.25), roughness=0.3)
gold = lp.material("Or", (0.95, 0.76, 0.2), roughness=0.4, metallic=0.6)

# ------------------------------------------------------------------ squelette
bones = [
    ("hips", (0, 0, 0.85), (0, 0, 1.0), None),
    ("spine", (0, 0, 1.0), (0, 0, 1.32), "hips"),
    ("head", (0, 0, 1.32), (0, 0, 1.75), "spine"),
]
for side, s in (("R", 1), ("L", -1)):
    bones += [
        (f"upper_arm.{side}", (0.27 * s, 0, 1.28), (0.3 * s, 0, 1.02), "spine"),
        (f"forearm.{side}", (0.3 * s, 0, 1.02), (0.31 * s, 0, 0.8), f"upper_arm.{side}"),
        (f"hand.{side}", (0.31 * s, 0, 0.8), (0.31 * s, 0, 0.68), f"forearm.{side}"),
        (f"thigh.{side}", (0.11 * s, 0, 0.85), (0.11 * s, 0, 0.47), "hips"),
        (f"shin.{side}", (0.11 * s, 0, 0.47), (0.11 * s, 0, 0.1), f"thigh.{side}"),
        (f"foot.{side}", (0.11 * s, 0, 0.1), (0.11 * s, 0.15, 0.03), f"shin.{side}"),
    ]
arm = lp.make_armature("PlayerRig", bones)

# ------------------------------------------------------------------ maillage
mb = lp.MeshBuilder()
# Bassin, ceinture et bas de tunique (suivent les hanches)
mb.box((0.34, 0.22, 0.18), tights, "hips", location=(0, 0, 0.88))
mb.cylinder(0.27, 0.24, tunic, "hips", radius_top=0.21, location=(0, 0, 0.9))
mb.box((0.42, 0.28, 0.07), leather, "hips", location=(0, 0, 1.0))
mb.box((0.09, 0.03, 0.07), gold, "hips", location=(0, 0.145, 1.0))
# Buste
mb.cylinder(0.2, 0.34, tunic, "spine", radius_top=0.17, location=(0, 0, 1.18))
mb.cylinder(0.07, 0.08, skin, "spine", location=(0, 0, 1.36))
# Tête : visage, cheveux, yeux, oreilles pointues, bonnet
mb.sphere(0.24, skin, "head", segments=10, rings=8, location=(0, 0, 1.55))
mb.sphere(0.25, hair, "head", segments=10, rings=6, location=(0, -0.03, 1.64), scale=(1, 1, 0.62))
mb.box((0.36, 0.08, 0.1), hair, "head", location=(0, 0.19, 1.68))
for s in (1, -1):
    mb.box((0.05, 0.02, 0.08), eyes, "head", location=(0.085 * s, 0.225, 1.56))
    mb.cylinder(0.05, 0.2, skin, "head", segments=6, radius_top=0.0,
                location=(0.3 * s, -0.02, 1.57), rotation=(0, 78 * s, 0))
mb.cylinder(0.25, 0.6, cap_mat, "head", segments=8, radius_top=0.02,
            location=(0, -0.3, 1.6), rotation=(112, 0, 0))
# Bras : manche, avant-bras, main (gant de cuir)
for side, s in (("R", 1), ("L", -1)):
    mb.cylinder(0.075, 0.28, tunic, f"upper_arm.{side}", segments=6, location=(0.29 * s, 0, 1.15))
    mb.cylinder(0.06, 0.24, skin, f"forearm.{side}", segments=6, location=(0.305 * s, 0, 0.91))
    mb.sphere(0.075, leather, f"hand.{side}", segments=6, rings=4, location=(0.31 * s, 0, 0.74))
    # Jambes : cuisse, botte, pied
    mb.cylinder(0.09, 0.4, tights, f"thigh.{side}", segments=6, location=(0.11 * s, 0, 0.66))
    mb.cylinder(0.095, 0.38, boots, f"shin.{side}", segments=6, location=(0.11 * s, 0, 0.29))
    mb.box((0.14, 0.26, 0.1), boots, f"foot.{side}", location=(0.11 * s, 0.05, 0.05))
body = mb.build("PlayerBody")
lp.skin(body, arm)

# Emplacement de l'arme : l'axe +Y de l'Empty (= -Z dans Godot) est le sens de la lame.
socket = lp.link(bpy.data.objects.new("WeaponSocket", None))
socket.empty_display_type = "ARROWS"
socket.empty_display_size = 0.2
socket.location = (0.31, 0, 0.73)
lp.attach_to_bone(socket, arm, "hand.R")


# ------------------------------------------------------------------ animations
def pose(*parts):
    """Fusionne plusieurs dictionnaires de pose (les rotations s'enchaînent)."""
    result = {}
    for part in parts:
        for bone, spec in part.items():
            target = result.setdefault(bone, {"rot": []})
            target["rot"] = target["rot"] + list(spec.get("rot", []))
            if "loc" in spec:
                target["loc"] = spec["loc"]
            if "scale" in spec:
                target["scale"] = spec["scale"]
    return result


def mirror(p):
    """Échange gauche/droite (rotations autour de Y et Z inversées)."""
    out = {}
    for bone, spec in p.items():
        name = bone.replace(".R", ".TMP").replace(".L", ".R").replace(".TMP", ".L")
        rots = [((ax), -deg if ax != X else deg) for ax, deg in spec.get("rot", [])]
        new = dict(spec)
        new["rot"] = rots
        if "loc" in spec:
            x, y, z = spec["loc"]
            new["loc"] = (-x, y, z)
        out[name] = new
    return out


# Garde : l'épée tenue devant, pointe vers l'avant.
GUARD = {"upper_arm.R": {"rot": [(X, 12)]}, "forearm.R": {"rot": [(X, 35)]},
         "upper_arm.L": {"rot": [(Y, 8)]}}


def anim(name, keys):
    a = lp.Animation(arm, name)
    for frame, p in keys:
        a.pose(frame, p)
    a.finish()


# idle : respiration (1 s, en boucle)
idle_a = pose(GUARD, {"upper_arm.R": {"rot": [(Y, -6)]}})
idle_b = pose(idle_a, {"spine": {"rot": [(X, -3)]}, "hips": {"loc": (0, 0, -0.012)},
                       "upper_arm.L": {"rot": [(Y, 3)]}})
anim("idle", [(1, idle_a), (16, idle_b), (31, idle_a)])

# walk : 0,8 s en boucle
# (seules les jambes, le buste et le bras gauche sont reflétés ; l'épée reste en garde)
walk_contact = {
    "thigh.R": {"rot": [(X, 25)]}, "thigh.L": {"rot": [(X, -22)]}, "shin.L": {"rot": [(X, -15)]},
    "upper_arm.L": {"rot": [(X, 22)]}, "spine": {"rot": [(Z, -5)]}, "hips": {"loc": (0, 0, -0.02)}}
walk_contact_mirror = {
    "thigh.L": {"rot": [(X, 25)]}, "thigh.R": {"rot": [(X, -22)]}, "shin.R": {"rot": [(X, -15)]},
    "upper_arm.L": {"rot": [(X, -18)]}, "spine": {"rot": [(Z, 5)]}, "hips": {"loc": (0, 0, -0.02)}}
walk_pass = {"shin.L": {"rot": [(X, -38)]}, "thigh.L": {"rot": [(X, 8)]}, "hips": {"loc": (0, 0, 0.02)}}
walk_pass_mirror = {"shin.R": {"rot": [(X, -38)]}, "thigh.R": {"rot": [(X, 8)]}, "hips": {"loc": (0, 0, 0.02)}}
anim("walk", [(1, pose(GUARD, walk_contact)), (7, pose(GUARD, walk_pass)),
              (13, pose(GUARD, walk_contact_mirror)), (19, pose(GUARD, walk_pass_mirror)),
              (25, pose(GUARD, walk_contact))])

# run : 0,53 s en boucle, buste penché, grands mouvements
run_contact = {
    "spine": {"rot": [(X, -12), (Z, -8)]}, "hips": {"loc": (0, 0, -0.04)},
    "thigh.R": {"rot": [(X, 45)]}, "shin.R": {"rot": [(X, -15)]},
    "thigh.L": {"rot": [(X, -35)]}, "shin.L": {"rot": [(X, -55)]},
    "upper_arm.L": {"rot": [(X, 40)]}, "forearm.L": {"rot": [(X, 60)]},
    "upper_arm.R": {"rot": [(X, -25)]}, "forearm.R": {"rot": [(X, 55)]}}
run_pass = {
    "spine": {"rot": [(X, -12)]}, "hips": {"loc": (0, 0, 0.04)},
    "thigh.L": {"rot": [(X, 15)]}, "shin.L": {"rot": [(X, -85)]},
    "forearm.L": {"rot": [(X, 60)]}, "forearm.R": {"rot": [(X, 60)]}}
anim("run", [(1, run_contact), (5, run_pass), (9, mirror(run_contact)), (13, mirror(run_pass)), (17, run_contact)])

# jump : impulsion (0,3 s)
crouch = pose(GUARD, {"hips": {"loc": (0, 0, -0.12)}, "spine": {"rot": [(X, -12)]},
                      "thigh.R": {"rot": [(X, 40)]}, "shin.R": {"rot": [(X, -65)]}, "foot.R": {"rot": [(X, 25)]},
                      "thigh.L": {"rot": [(X, 40)]}, "shin.L": {"rot": [(X, -65)]}, "foot.L": {"rot": [(X, 25)]}})
stretch = {"upper_arm.R": {"rot": [(X, 60), (Y, -30)]}, "upper_arm.L": {"rot": [(X, 60), (Y, 30)]},
           "foot.R": {"rot": [(X, -20)]}, "foot.L": {"rot": [(X, -20)]}}
airborne = {"upper_arm.R": {"rot": [(X, 50), (Y, -40)]}, "upper_arm.L": {"rot": [(X, 40), (Y, 40)]},
            "thigh.R": {"rot": [(X, 55)]}, "shin.R": {"rot": [(X, -70)]},
            "thigh.L": {"rot": [(X, -10)]}, "shin.L": {"rot": [(X, -20)]}}
anim("jump", [(1, crouch), (4, stretch), (10, airborne)])

# fall : bras écartés, en boucle (0,5 s)
fall_a = {"upper_arm.R": {"rot": [(X, 30), (Y, -65)]}, "upper_arm.L": {"rot": [(X, 30), (Y, 65)]},
          "thigh.R": {"rot": [(X, 25)]}, "shin.R": {"rot": [(X, -30)]}, "thigh.L": {"rot": [(X, -5)]},
          "spine": {"rot": [(X, 5)]}}
fall_b = pose(fall_a, {"upper_arm.R": {"rot": [(Y, -10)]}, "upper_arm.L": {"rot": [(Y, 10)]},
                       "thigh.R": {"rot": [(X, -10)]}, "thigh.L": {"rot": [(X, 10)]}})
anim("fall", [(1, fall_a), (9, fall_b), (16, fall_a)])

# roll : roulade avant (0,45 s), le corps fait un tour complet en boule
tuck = {"spine": {"rot": [(X, -35)]}, "head": {"rot": [(X, -25)]},
        "thigh.R": {"rot": [(X, 100)]}, "shin.R": {"rot": [(X, -120)]},
        "thigh.L": {"rot": [(X, 100)]}, "shin.L": {"rot": [(X, -120)]},
        "upper_arm.R": {"rot": [(X, 60)]}, "forearm.R": {"rot": [(X, 70)]},
        "upper_arm.L": {"rot": [(X, 60)]}, "forearm.L": {"rot": [(X, 70)]}}
anim("roll", [
    (1, pose(GUARD, {"hips": {"loc": (0, 0, -0.1)}})),
    (4, pose(tuck, {"hips": {"rot": [(X, -90)], "loc": (0, 0.2, -0.45)}})),
    (7, pose(tuck, {"hips": {"rot": [(X, -180)], "loc": (0, 0.3, -0.55)}})),
    (11, pose(tuck, {"hips": {"rot": [(X, -270)], "loc": (0, 0.2, -0.4)}})),
    (14, pose(GUARD, {"hips": {"rot": [(X, -360)], "loc": (0, 0, -0.05)}})),
])

# Attaques. La main tourne de -70° autour de X pour prolonger la lame dans l'axe du bras.
LUNGE = {"thigh.R": {"rot": [(X, 22)]}, "thigh.L": {"rot": [(X, -18)]}, "shin.L": {"rot": [(X, -10)]},
         "hips": {"loc": (0, 0.03, -0.05)}}
slash_right = {"spine": {"rot": [(Z, -35)]}, "upper_arm.R": {"rot": [(X, 80), (Z, -45)]},
               "forearm.R": {"rot": [(X, 10)]}, "hand.R": {"rot": [(X, -70)]}}
slash_left = {"spine": {"rot": [(Z, 35)]}, "upper_arm.R": {"rot": [(X, 80), (Z, 75)]},
              "forearm.R": {"rot": [(X, 10)]}, "hand.R": {"rot": [(X, -70)]}}
recover_left = pose(GUARD, {"spine": {"rot": [(Z, 12)]}})
recover_right = pose(GUARD, {"spine": {"rot": [(Z, -12)]}})
# attack_1 : taille de droite à gauche (0,4 s) — frames actives vers 0,1 à 0,22 s
anim("attack_1", [(1, slash_right), (4, pose(slash_right, LUNGE)), (7, pose(slash_left, LUNGE)),
                  (13, recover_left)])
# attack_2 : revers de gauche à droite (0,4 s)
anim("attack_2", [(1, slash_left), (4, pose(slash_left, LUNGE)), (7, pose(slash_right, LUNGE)),
                  (13, recover_right)])
# attack_3 : coup vertical final (0,6 s) — frames actives vers 0,24 à 0,36 s
overhead = {"spine": {"rot": [(X, 10)]}, "upper_arm.R": {"rot": [(X, 165)]},
            "forearm.R": {"rot": [(X, 15)]}, "hand.R": {"rot": [(X, -40)]},
            "upper_arm.L": {"rot": [(X, 150)]}}
slam = pose(LUNGE, {"spine": {"rot": [(X, -28)]}, "hips": {"loc": (0, 0.08, -0.12)},
                    "upper_arm.R": {"rot": [(X, 60)]}, "hand.R": {"rot": [(X, -55)]},
                    "upper_arm.L": {"rot": [(X, 55)]}})
anim("attack_3", [(1, GUARD), (6, overhead), (8, overhead), (10, slam), (15, slam), (19, pose(GUARD))])

# cast : la main gauche pousse le sort vers l'avant (0,5 s), la boule part à 0,25 s
cast_ready = pose(GUARD, {"upper_arm.L": {"rot": [(X, 35), (Y, 20)]}, "forearm.L": {"rot": [(X, 70)]},
                          "spine": {"rot": [(Z, 10)]}})
cast_push = pose(GUARD, {"upper_arm.L": {"rot": [(X, 88)]}, "forearm.L": {"rot": [(X, 5)]},
                         "hand.L": {"rot": [(X, -60)]}, "spine": {"rot": [(Z, -12)]}})
anim("cast", [(1, GUARD), (5, cast_ready), (8, cast_push), (12, cast_push), (16, GUARD)])

# hurt : recul (0,4 s)
hurt = {"spine": {"rot": [(X, 25)]}, "head": {"rot": [(X, 18)]}, "hips": {"loc": (0, -0.04, -0.03)},
        "upper_arm.R": {"rot": [(X, 25), (Y, -35)]}, "upper_arm.L": {"rot": [(X, 25), (Y, 35)]},
        "thigh.R": {"rot": [(X, 15)]}}
anim("hurt", [(1, hurt), (5, hurt), (13, GUARD)])

# death : s'effondre sur le dos et y reste (0,8 s)
knees = {"hips": {"loc": (0, 0, -0.25)}, "spine": {"rot": [(X, 20)]},
         "thigh.R": {"rot": [(X, 50)]}, "shin.R": {"rot": [(X, -80)]},
         "thigh.L": {"rot": [(X, 45)]}, "shin.L": {"rot": [(X, -75)]},
         "upper_arm.R": {"rot": [(Y, -30)]}, "upper_arm.L": {"rot": [(Y, 30)]}}
lying = {"hips": {"rot": [(X, 88)], "loc": (0, -0.3, -0.62)}, "head": {"rot": [(Y, 25)]},
         "thigh.R": {"rot": [(X, 10)]}, "thigh.L": {"rot": [(X, 20)]}, "shin.L": {"rot": [(X, -30)]},
         "upper_arm.R": {"rot": [(Y, -70)]}, "upper_arm.L": {"rot": [(Y, 70)]}}
anim("death", [(1, GUARD), (8, knees), (16, lying), (25, lying)])

# Pose de repos affichée dans Blender (aucune action active).
bpy.context.scene.frame_set(1)
glb = lp.export("player")
print("Joueur exporté :", glb, "| animations :", [t.name for t in arm.animation_data.nla_tracks])
