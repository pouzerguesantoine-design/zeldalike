"""Construit les ennemis : Slime et Gobelin (maillages low-poly, squelettes, animations
idle, walk, attack, hurt, death). Durées identiques aux animations de gameplay de Godot
(télégraphie, frames actives) pour rester synchronisées.
Sorties : assets/blender/slime.blend, slime.glb ; assets/blender/goblin.blend, goblin.glb.
Repère : voir build_player.py (+Y = avant, rotations autour d'axes monde).
"""

import importlib
import sys

sys.path.insert(0, r"C:\Users\psamf\Documents\zeldalike\tools\blender")
import lowpoly as lp  # noqa: E402

importlib.reload(lp)

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def anim(arm, name, keys):
    a = lp.Animation(arm, name)
    for frame, pose in keys:
        a.pose(frame, pose)
    a.finish()


def merge(*parts):
    result = {}
    for part in parts:
        for bone, spec in part.items():
            target = result.setdefault(bone, {"rot": []})
            target["rot"] = target["rot"] + list(spec.get("rot", []))
            for key in ("loc", "scale"):
                if key in spec:
                    target[key] = spec[key]
    return result


# =============================================================================== Slime
lp.reset_scene()
P = lp.PALETTE
jelly = lp.material("Gelee", P["slime"], roughness=0.15, alpha=0.9)
core = lp.material("Coeur", P["slime_core"], roughness=0.3)
bubble = lp.material("Bulle", (0.7, 1.0, 0.75), roughness=0.1)
eye = lp.material("OeilNoir", (0.04, 0.04, 0.06), roughness=0.1)
mouth = lp.material("Bouche", (0.1, 0.25, 0.12))
sprout = lp.material("Pousse", P["leaves_light"])
shine = lp.material("Reflet", (1, 1, 1), roughness=0.1, emission=(1, 1, 1), emission_strength=0.5)

slime_arm = lp.make_armature("SlimeRig", [("body", (0, 0, 0), (0, 0, 0.8), None)])
mb = lp.MeshBuilder()
mb.ico(0.55, jelly, "body", subdivisions=2, location=(0, 0, 0.42), scale=(1, 1, 0.78))
mb.ico(0.22, core, "body", subdivisions=1, location=(0, -0.05, 0.36))
# Bulles à l'intérieur, petite bouche, pousse de feuille sur la tête
mb.ico(0.06, bubble, "body", subdivisions=1, location=(0.2, -0.15, 0.55))
mb.ico(0.04, bubble, "body", subdivisions=1, location=(-0.22, -0.05, 0.3))
mb.box((0.12, 0.02, 0.035), mouth, "body", location=(0, 0.47, 0.38))
mb.cylinder(0.015, 0.14, sprout, "body", segments=4, location=(0, -0.02, 0.88))
mb.sphere(0.07, sprout, "body", segments=6, rings=3, location=(0.05, -0.02, 0.96), scale=(1.4, 0.5, 0.6), rotation=(0, -25, 0))
for s in (1, -1):
    mb.sphere(0.075, eye, "body", segments=8, rings=5, location=(0.17 * s, 0.44, 0.52), scale=(1, 0.6, 1.2))
    mb.sphere(0.022, shine, "body", segments=6, rings=4, location=(0.15 * s + 0.02, 0.485, 0.56))
lp.skin(mb.build("SlimeBody"), slime_arm)


def squash(sx, sy, lift=0.0, lean=0.0):
    """Échelle de l'os « body » (local : X largeur, Y hauteur, Z profondeur)."""
    return {"body": {"scale": (sx, sy, sx), "loc": (0, 0, lift), "rot": [(X, lean)]}}


REST = squash(1, 1)
# idle (1 s) et walk (0,6 s) en boucle
anim(slime_arm, "idle", [(1, REST), (16, squash(1.08, 0.92)), (31, REST)])
anim(slime_arm, "walk", [(1, REST), (6, squash(1.2, 0.8)), (12, squash(0.9, 1.15, 0.05)), (19, REST)])
# attack (1,3 s) : s'écrase en tremblant (télégraphie jusqu'à 0,6 s), s'étire en bondissant.
anim(slime_arm, "attack", [
    (1, REST), (10, squash(1.2, 0.75)), (13, squash(1.26, 0.7, 0, -5)), (16, squash(1.2, 0.75, 0, 5)),
    (19, squash(1.32, 0.64)), (22, squash(0.82, 1.3, 0.05, -15)), (31, squash(1.1, 0.9)), (40, REST)])
anim(slime_arm, "hurt", [(1, squash(1.35, 0.65)), (4, squash(0.9, 1.12)), (11, REST)])
anim(slime_arm, "death", [(1, REST), (10, squash(1.55, 0.25)), (25, squash(0.02, 0.02))])
lp.export("slime")
print("Slime exporté")

# ============================================================================== Gobelin
lp.reset_scene()
P = lp.PALETTE
skin = lp.material("PeauGobelin", P["goblin_skin"])
skin_dark = lp.material("PeauGobelinSombre", P["goblin_skin_dark"])
tunic = lp.material("Haillons", P["rag"])
dark = lp.material("CuirSombre", P["leather_dark"])
gold = lp.material("AnneauOr", P["gold"], metallic=0.6, roughness=0.35)
hair = lp.material("TouffeNoire", (0.12, 0.09, 0.08))
wood = lp.material("BoisMassue", (0.38, 0.24, 0.12))
eyes = lp.material("YeuxJaunes", (1.0, 0.85, 0.1), emission=(1.0, 0.8, 0.1), emission_strength=1.5)
teeth = lp.material("Dents", (0.95, 0.92, 0.8))
metal = lp.material("Clous", (0.55, 0.55, 0.6), metallic=0.8, roughness=0.3)

bones = [
    ("hips", (0, 0, 0.6), (0, 0, 0.75), None),
    ("spine", (0, 0, 0.75), (0, 0, 1.15), "hips"),
    ("head", (0, 0, 1.15), (0, 0, 1.65), "spine"),
]
for side, s in (("R", 1), ("L", -1)):
    bones += [
        (f"upper_arm.{side}", (0.3 * s, 0, 1.08), (0.36 * s, 0, 0.82), "spine"),
        (f"forearm.{side}", (0.36 * s, 0, 0.82), (0.38 * s, 0, 0.6), f"upper_arm.{side}"),
        (f"hand.{side}", (0.38 * s, 0, 0.6), (0.38 * s, 0, 0.5), f"forearm.{side}"),
        (f"thigh.{side}", (0.13 * s, 0, 0.6), (0.13 * s, 0, 0.33), "hips"),
        (f"shin.{side}", (0.13 * s, 0, 0.33), (0.13 * s, 0, 0.08), f"thigh.{side}"),
        (f"foot.{side}", (0.13 * s, 0, 0.08), (0.13 * s, 0.14, 0.02), f"shin.{side}"),
    ]
gob_arm = lp.make_armature("GoblinRig", bones)

mb = lp.MeshBuilder()
mb.box((0.36, 0.26, 0.16), dark, "hips", location=(0, 0, 0.64))
mb.cylinder(0.3, 0.2, tunic, "hips", segments=7, radius_top=0.27, location=(0, 0, 0.62))
mb.cylinder(0.3, 0.46, tunic, "spine", segments=7, radius_top=0.23, location=(0, -0.02, 0.95))
mb.sphere(0.2, skin, "spine", segments=8, rings=5, location=(0, 0.12, 0.88), scale=(1, 0.7, 0.9))
# Tête : grosse, oreilles immenses, yeux jaunes, nez crochu, crocs
mb.sphere(0.31, skin, "head", segments=9, rings=7, location=(0, 0.02, 1.42), scale=(1, 0.95, 0.9))
for s in (1, -1):
    mb.cylinder(0.1, 0.46, skin, "head", segments=5, radius_top=0.0,
                location=(0.42 * s, -0.02, 1.5), rotation=(0, 72 * s, 0))
    mb.sphere(0.055, eyes, "head", segments=6, rings=4, location=(0.12 * s, 0.27, 1.47))
    mb.box((0.035, 0.03, 0.07), teeth, "head", location=(0.07 * s, 0.27, 1.27))
mb.cylinder(0.06, 0.2, skin, "head", segments=5, radius_top=0.0, location=(0, 0.36, 1.38), rotation=(-80, 0, 0))
# Arcade sourcilière, anneau au nez, touffe de cheveux, mâchoire
mb.box((0.36, 0.08, 0.06), skin_dark, "head", location=(0, 0.26, 1.53), rotation=(-15, 0, 0))
mb.cylinder(0.045, 0.015, gold, "head", segments=8, location=(0, 0.41, 1.33), rotation=(0, 90, 0))
for k, (x, tilt) in enumerate(((-0.08, -20), (0.0, 0), (0.08, 20))):
    mb.cylinder(0.05, 0.22, hair, "head", segments=4, radius_top=0.0, location=(x, -0.02, 1.74), rotation=(-25, tilt, 0))
mb.box((0.3, 0.16, 0.08), skin_dark, "head", location=(0, 0.2, 1.24))
# Pagne, ceinture, épaulière de cuir
mb.box((0.22, 0.04, 0.28), tunic, "hips", location=(0, 0.25, 0.5), rotation=(8, 0, 0))
mb.box((0.62, 0.32, 0.06), dark, "hips", location=(0, 0, 0.72))
mb.box((0.2, 0.28, 0.1), dark, "spine", location=(0.3, 0, 1.1), rotation=(0, 25, 0))
# Bras longs, jambes courtes
for side, s in (("R", 1), ("L", -1)):
    mb.cylinder(0.07, 0.3, skin, f"upper_arm.{side}", segments=6, location=(0.33 * s, 0, 0.95))
    mb.cylinder(0.065, 0.24, skin, f"forearm.{side}", segments=6, location=(0.37 * s, 0, 0.71))
    mb.sphere(0.085, skin, f"hand.{side}", segments=6, rings=4, location=(0.38 * s, 0, 0.53))
    mb.cylinder(0.08, 0.28, skin, f"thigh.{side}", segments=6, location=(0.13 * s, 0, 0.46))
    mb.cylinder(0.075, 0.26, skin, f"shin.{side}", segments=6, location=(0.13 * s, 0, 0.2))
    mb.box((0.14, 0.24, 0.08), dark, f"foot.{side}", location=(0.13 * s, 0.05, 0.04))
# Massue dans la main droite, tenue vers l'avant (fait partie du maillage, os hand.R)
mb.cylinder(0.05, 0.85, wood, "hand.R", segments=7, radius_top=0.12, location=(0.38, 0.42, 0.53), rotation=(-90, 0, 0))
for angle in (0, 120, 240):
    import math
    dx, dz = 0.12 * math.cos(math.radians(angle)), 0.12 * math.sin(math.radians(angle))
    mb.cylinder(0.025, 0.08, metal, "hand.R", segments=4, radius_top=0.0,
                location=(0.38 + dx, 0.72, 0.53 + dz), rotation=(0, 90 if angle == 0 else 0, 0))
lp.skin(mb.build("GoblinBody"), gob_arm)

HUNCH = {"spine": {"rot": [(X, -12)]}, "head": {"rot": [(X, 8)]},
         "upper_arm.R": {"rot": [(X, 10), (Y, -8)]}, "upper_arm.L": {"rot": [(X, 5), (Y, 10)]},
         "forearm.R": {"rot": [(X, 20)]}}
# idle (1,2 s) : respiration voûtée
anim(gob_arm, "idle", [(1, HUNCH), (19, merge(HUNCH, {"spine": {"rot": [(X, -4)]}, "hips": {"loc": (0, 0, -0.015)}})),
                       (37, HUNCH)])
# walk (0,5 s) : pas rapides et chaloupés
step = {"thigh.R": {"rot": [(X, 30)]}, "thigh.L": {"rot": [(X, -25)]}, "shin.L": {"rot": [(X, -25)]},
        "upper_arm.L": {"rot": [(X, 25)]}, "spine": {"rot": [(Y, 6)]}, "hips": {"loc": (0, 0, -0.02)}}
step_m = {"thigh.L": {"rot": [(X, 30)]}, "thigh.R": {"rot": [(X, -25)]}, "shin.R": {"rot": [(X, -25)]},
          "upper_arm.L": {"rot": [(X, -20)]}, "spine": {"rot": [(Y, -6)]}, "hips": {"loc": (0, 0, -0.02)}}
passing = {"hips": {"loc": (0, 0, 0.03)}}
anim(gob_arm, "walk", [(1, merge(HUNCH, step)), (5, merge(HUNCH, passing)), (9, merge(HUNCH, step_m)),
                       (12, merge(HUNCH, passing)), (16, merge(HUNCH, step))])
# attack (1,1 s) : massue levée derrière la tête en tremblant (télégraphie → 0,45 s),
# coup vertical vers 0,58 s (frames actives 0,5 à 0,68 s), récupération.
raised = merge(HUNCH, {"upper_arm.R": {"rot": [(X, 150)]}, "forearm.R": {"rot": [(X, 20)]},
                       "hand.R": {"rot": [(X, 30)]}, "spine": {"rot": [(X, 18)]},
                       "upper_arm.L": {"rot": [(Y, 35)]}})
raised_shake = merge(raised, {"upper_arm.R": {"rot": [(X, 8)]}, "spine": {"rot": [(Z, 4)]}})
strike = merge(HUNCH, {"upper_arm.R": {"rot": [(X, 55)]}, "forearm.R": {"rot": [(X, -10)]},
                       "hand.R": {"rot": [(X, -40)]}, "spine": {"rot": [(X, -30)]},
                       "hips": {"loc": (0, 0.06, -0.08)}, "thigh.R": {"rot": [(X, 25)]},
                       "thigh.L": {"rot": [(X, -20)]}})
anim(gob_arm, "attack", [(1, HUNCH), (8, raised), (10, raised_shake), (12, raised), (14, raised_shake),
                         (15, raised), (18, strike), (25, strike), (34, HUNCH)])
anim(gob_arm, "hurt", [(1, merge(HUNCH, {"spine": {"rot": [(X, 30)]}, "head": {"rot": [(X, 15)]}})), (11, HUNCH)])
anim(gob_arm, "death", [
    (1, HUNCH),
    (10, merge(HUNCH, {"hips": {"loc": (0, 0, -0.18)}, "spine": {"rot": [(X, 25)]},
                       "thigh.R": {"rot": [(X, 50)]}, "shin.R": {"rot": [(X, -70)]},
                       "thigh.L": {"rot": [(X, 45)]}, "shin.L": {"rot": [(X, -65)]}})),
    (18, {"hips": {"rot": [(X, 88)], "loc": (0, -0.25, -0.42)}, "upper_arm.R": {"rot": [(Y, -70)]},
          "upper_arm.L": {"rot": [(Y, 70)]}, "head": {"rot": [(Z, 30)]}}),
    (28, {"hips": {"rot": [(X, 88)], "loc": (0, -0.25, -0.42)}, "upper_arm.R": {"rot": [(Y, -70)]},
          "upper_arm.L": {"rot": [(Y, 70)]}, "head": {"rot": [(Z, 30)]}}),
])
lp.export("goblin")
print("Gobelin exporté")
