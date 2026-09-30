"""Construit les décors : arbres (feuillu, sapin), rochers, herbe, maisonnette, coffre
(couvercle animé « open »), porte (animation « open »), barrière, pont.

Collisions : objets simplifiés nommés avec les suffixes d'import Godot
  « -convcolonly » (forme convexe seule) ou « -colonly » (forme concave seule) ;
Godot les remplace à l'import par des StaticBody3D + CollisionShape3D (maillage invisible).
Chaque décor a un Empty racine à l'origine (pieds), exporté seul dans assets/models/.
Sorties : assets/blender/props.blend + un .glb par décor.
"""

import importlib
import math
import sys

sys.path.insert(0, r"C:\Users\psamf\Documents\zeldalike\tools\blender")
import lowpoly as lp  # noqa: E402

importlib.reload(lp)
import bpy  # noqa: E402

lp.reset_scene()

bark = lp.material("Ecorce", (0.4, 0.26, 0.14))
leaves = lp.material("Feuillage", (0.3, 0.62, 0.22))
leaves_light = lp.material("FeuillageClair", (0.45, 0.74, 0.28))
pine = lp.material("Sapin", (0.16, 0.45, 0.22))
rock = lp.material("Roche", (0.56, 0.56, 0.6))
rock_dark = lp.material("RocheSombre", (0.44, 0.44, 0.49))
grass = lp.material("Herbe", (0.46, 0.78, 0.3))
wall = lp.material("Crepi", (0.94, 0.88, 0.72))
roof = lp.material("Tuiles", (0.74, 0.22, 0.16))
wood = lp.material("Bois", (0.56, 0.36, 0.18))
wood_dark = lp.material("BoisSombre", (0.34, 0.21, 0.1))
gold = lp.material("OrCoffre", (0.93, 0.74, 0.2), metallic=0.6, roughness=0.35)
glass = lp.material("Vitre", (0.55, 0.78, 0.95), roughness=0.1)
stone = lp.material("Pierre", (0.63, 0.63, 0.66))
collision = lp.material("Collision", (1, 0, 1))


# Nom du décor en cours : préfixe de tous ses objets. Blender ajoute « .001 » aux noms en
# double, ce qui casserait les suffixes de collision (ils doivent terminer le nom).
current_prop = ""


def new_root(name):
    global current_prop
    current_prop = name
    root = lp.link(bpy.data.objects.new(name, None))
    root.empty_display_type = "PLAIN_AXES"
    return root


def child(obj, parent, location=(0, 0, 0)):
    obj.parent = parent
    obj.location = location
    return obj


def mesh(name, parent, parts, location=(0, 0, 0)):
    """Maillage enfant de `parent` (nom préfixé par le décor) ; parts = [(méthode, args, kwargs)]."""
    obj = child(lp.simple_mesh(current_prop + name, parts), parent, location)
    assert obj.name == current_prop + name, f"nom en double : {obj.name}"
    if "colonly" in name:
        obj.display_type = "WIRE"
    return obj


def col_box(name, parent, size, location, rotation=(0, 0, 0), concave=False):
    """Collision simplifiée (pavé) : suffixe -convcolonly (ou -colonly si concave)."""
    suffix = "-colonly" if concave else "-convcolonly"
    return mesh(name + suffix, parent, [("box", (size, collision), dict(location=location, rotation=rotation))])


def col_cylinder(name, parent, radius, depth, location):
    return mesh(name + "-convcolonly", parent, [("cylinder", (radius, depth, collision), dict(location=location))])


roots = {}

# --------------------------------------------------------------------- arbre feuillu
r = roots["tree_round"] = new_root("TreeRound")
mesh("Trunk", r, [("cylinder", (0.22, 1.9, bark), dict(segments=7, radius_top=0.15, location=(0, 0, 0.95)))])
mesh("Foliage", r, [
    ("ico", (1.0, leaves), dict(subdivisions=1, location=(0, 0, 2.4))),
    ("ico", (0.75, leaves_light), dict(subdivisions=1, location=(0.55, 0.2, 2.05))),
    ("ico", (0.7, leaves), dict(subdivisions=1, location=(-0.5, -0.25, 2.15))),
    ("ico", (0.6, leaves_light), dict(subdivisions=1, location=(0.1, -0.3, 2.95))),
])
col_cylinder("TrunkCollision", r, 0.28, 2.0, (0, 0, 1.0))

# --------------------------------------------------------------------------- sapin
r = roots["tree_pine"] = new_root("TreePine")
mesh("Trunk", r, [("cylinder", (0.16, 1.0, bark), dict(segments=6, radius_top=0.12, location=(0, 0, 0.5)))])
mesh("Needles", r, [
    ("cylinder", (1.1, 1.3, pine), dict(segments=7, radius_top=0.0, location=(0, 0, 1.4))),
    ("cylinder", (0.85, 1.1, pine), dict(segments=7, radius_top=0.0, location=(0, 0, 2.1))),
    ("cylinder", (0.6, 0.9, pine), dict(segments=7, radius_top=0.0, location=(0, 0, 2.75))),
])
col_cylinder("TrunkCollision", r, 0.3, 2.0, (0, 0, 1.0))

# ------------------------------------------------------------------------- rochers
r = roots["rock_a"] = new_root("RockA")
mesh("Rock", r, [("ico", (0.9, rock), dict(subdivisions=1, location=(0, 0, 0.45), scale=(1.2, 1.0, 0.7), rotation=(8, 0, 20)))])
mesh("Rock-convcolonly", r, [("ico", (0.9, collision), dict(subdivisions=1, location=(0, 0, 0.45), scale=(1.2, 1.0, 0.7), rotation=(8, 0, 20)))])
r = roots["rock_b"] = new_root("RockB")
mesh("Rock", r, [
    ("ico", (0.7, rock_dark), dict(subdivisions=1, location=(0, 0, 0.5), scale=(1, 0.9, 1.1), rotation=(0, 12, 35))),
    ("ico", (0.45, rock), dict(subdivisions=1, location=(0.6, 0.3, 0.3), rotation=(20, 0, 0))),
])
mesh("Rock-convcolonly", r, [
    ("ico", (0.7, collision), dict(subdivisions=1, location=(0, 0, 0.5), scale=(1, 0.9, 1.1), rotation=(0, 12, 35))),
])

# ---------------------------------------------------------------------------- herbe
r = roots["grass"] = new_root("Grass")
blades = []
for i, (x, y, h, lean) in enumerate([(0, 0, 0.5, 0), (0.12, 0.06, 0.4, 15), (-0.1, 0.08, 0.42, -15),
                                     (0.05, -0.1, 0.35, 10), (-0.06, -0.08, 0.38, -10)]):
    blades.append(("cylinder", (0.05, h, grass), dict(segments=3, radius_top=0.0,
                                                      location=(x, y, h / 2), rotation=(lean, lean * 0.5, i * 40))))
mesh("Blades", r, blades)

# ---------------------------------------------------------------------- maisonnette
r = roots["house"] = new_root("House")
mesh("Walls", r, [
    ("box", ((4.0, 3.4, 2.6), wall), dict(location=(0, 0, 1.3))),
    ("box", ((4.1, 3.5, 0.25), wood_dark), dict(location=(0, 0, 0.12))),
    ("box", ((0.2, 3.5, 2.6), wood_dark), dict(location=(-2.0, 0, 1.3))),
    ("box", ((0.2, 3.5, 2.6), wood_dark), dict(location=(2.0, 0, 1.3))),
])
mesh("Door", r, [("box", ((0.9, 0.08, 1.7), wood), dict(location=(0, 1.72, 0.95))),
                 ("sphere", (0.05, gold), dict(segments=6, rings=4, location=(0.3, 1.78, 0.95)))])
mesh("Windows", r, [
    ("box", ((0.7, 0.06, 0.6), glass), dict(location=(-1.2, 1.72, 1.6))),
    ("box", ((0.7, 0.06, 0.6), glass), dict(location=(1.2, 1.72, 1.6))),
    ("box", ((0.8, 0.08, 0.08), wood_dark), dict(location=(-1.2, 1.74, 1.6))),
    ("box", ((0.8, 0.08, 0.08), wood_dark), dict(location=(1.2, 1.74, 1.6))),
])
# Toit à deux pans (pente de 35°) + cheminée
slope = math.radians(35)
half_depth = 3.9 / 2
pan_len = half_depth / math.cos(slope) + 0.2
ridge_h = 2.6 + half_depth * math.tan(slope)
mesh("Roof", r, [
    ("box", ((4.6, pan_len, 0.18), roof), dict(location=(0, half_depth / 2, 2.6 + (ridge_h - 2.6) / 2), rotation=(-35, 0, 0))),
    ("box", ((4.6, pan_len, 0.18), roof), dict(location=(0, -half_depth / 2, 2.6 + (ridge_h - 2.6) / 2), rotation=(35, 0, 0))),
    ("box", ((0.5, 0.5, 1.2), stone), dict(location=(1.3, -0.6, ridge_h))),
])
# Pignons (triangles) : cylindres à 3 côtés couchés
for x in (-1.95, 1.95):
    mesh(f"Gable{'L' if x < 0 else 'R'}", r, [("cylinder", (half_depth * 1.0, 0.15, wall),
                                               dict(segments=3, location=(x, 0, 2.6 + 0.22), rotation=(0, 90, 0), scale=(0.62, 1.0, 1.0)))])
col_box("WallsCollision", r, (4.1, 3.5, 2.7), (0, 0, 1.35))
col_box("RoofCollision", r, (4.2, 3.6, 1.4), (0, 0, 3.3))

# --------------------------------------------------------------------------- coffre
r = roots["chest"] = new_root("Chest")
mesh("ChestBase", r, [
    ("box", ((0.9, 0.6, 0.5), wood), dict(location=(0, 0, 0.25))),
    ("box", ((0.94, 0.64, 0.07), gold), dict(location=(0, 0, 0.47))),
    ("box", ((0.08, 0.64, 0.5), gold), dict(location=(-0.3, 0, 0.25))),
    ("box", ((0.08, 0.64, 0.5), gold), dict(location=(0.3, 0, 0.25))),
    ("box", ((0.14, 0.04, 0.16), gold), dict(location=(0, 0.32, 0.42))),
])
# Couvercle : origine sur la charnière (arrière, en haut du coffre)
lid = mesh("ChestLid", r, [
    ("box", ((0.92, 0.62, 0.2), wood), dict(location=(0, 0.31, 0.1))),
    ("box", ((0.96, 0.66, 0.06), gold), dict(location=(0, 0.31, 0.21))),
    ("box", ((0.08, 0.66, 0.22), gold), dict(location=(-0.3, 0.31, 0.1))),
    ("box", ((0.08, 0.66, 0.22), gold), dict(location=(0.3, 0.31, 0.1))),
], location=(0, -0.31, 0.5))
col_box("ChestCollision", r, (0.9, 0.6, 0.72), (0, 0, 0.36))
open_chest = lp.ObjectAnimation("open", [lid])
open_chest.pose(1, {lid: {"rot": (0, 0, 0)}})
open_chest.pose(lp.frames(0.35), {lid: {"rot": (120, 0, 0)}})
open_chest.pose(lp.frames(0.5), {lid: {"rot": (105, 0, 0)}})
open_chest.finish()

# --------------------------------------------------------------------------- porte
r = roots["door"] = new_root("Door")
mesh("Frame", r, [
    ("box", ((0.35, 0.5, 2.6), stone), dict(location=(-0.8, 0, 1.3))),
    ("box", ((0.35, 0.5, 2.6), stone), dict(location=(0.8, 0, 1.3))),
    ("box", ((1.95, 0.5, 0.4), stone), dict(location=(0, 0, 2.6))),
])
# Battant : origine sur les gonds (bord gauche) ; il pivote autour de Z
panel = mesh("DoorPanel", r, [
    ("box", ((1.25, 0.14, 2.25), wood), dict(location=(0.625, 0, 1.125))),
    ("box", ((1.25, 0.16, 0.12), wood_dark), dict(location=(0.625, 0, 0.5))),
    ("box", ((1.25, 0.16, 0.12), wood_dark), dict(location=(0.625, 0, 1.75))),
    ("sphere", (0.06, gold), dict(segments=6, rings=4, location=(1.05, 0.1, 1.1))),
], location=(-0.625, 0, 0))
col_box("PanelCollision", panel, (1.25, 0.16, 2.25), (0.625, 0, 1.125))
col_box("PostLeftCollision", r, (0.35, 0.5, 2.6), (-0.8, 0, 1.3))
col_box("PostRightCollision", r, (0.35, 0.5, 2.6), (0.8, 0, 1.3))
col_box("LintelCollision", r, (1.95, 0.5, 0.4), (0, 0, 2.6))
open_door = lp.ObjectAnimation("open", [panel])
open_door.pose(1, {panel: {"rot": (0, 0, 0)}})
open_door.pose(lp.frames(0.7), {panel: {"rot": (0, 0, 100)}})
open_door.finish()

# ------------------------------------------------------------------------- barrière
r = roots["fence"] = new_root("Fence")
mesh("Fence", r, [
    ("box", ((0.14, 0.14, 1.0), wood), dict(location=(-0.95, 0, 0.5))),
    ("box", ((0.14, 0.14, 1.0), wood), dict(location=(0.95, 0, 0.5))),
    ("cylinder", (0.1, 0.12, wood), dict(segments=4, radius_top=0.0, location=(-0.95, 0, 1.06), rotation=(0, 0, 45))),
    ("cylinder", (0.1, 0.12, wood), dict(segments=4, radius_top=0.0, location=(0.95, 0, 1.06), rotation=(0, 0, 45))),
    ("box", ((2.0, 0.08, 0.12), wood_dark), dict(location=(0, 0, 0.75))),
    ("box", ((2.0, 0.08, 0.12), wood_dark), dict(location=(0, 0, 0.4))),
])
col_box("FenceCollision", r, (2.1, 0.2, 1.1), (0, 0, 0.55))

# ----------------------------------------------------------------------------- pont
# Rampes aux deux bouts (pente douce) pour que le joueur et les ennemis puissent monter.
r = roots["bridge"] = new_root("Bridge")
ramp_len, flat_len, height = 1.6, 3.0, 0.4
ramp_angle = math.degrees(math.atan2(height, ramp_len))
ramp_y = flat_len / 2 + ramp_len / 2
planks = [("box", ((2.2, flat_len, 0.12), wood), dict(location=(0, 0, height)))]
for s in (1, -1):
    planks.append(("box", ((2.2, math.hypot(ramp_len, height), 0.12), wood),
                   dict(location=(0, s * ramp_y, height / 2), rotation=(-s * ramp_angle, 0, 0))))
mesh("Deck", r, planks)
rails = []
for x in (-1.05, 1.05):
    rails.append(("box", ((0.1, flat_len + 1.0, 0.1), wood_dark), dict(location=(x, 0, height + 0.8))))
    for y in (-2.0, -0.7, 0.7, 2.0):
        rails.append(("box", ((0.12, 0.12, 0.9), wood_dark), dict(location=(x, y, height + 0.4))))
mesh("Rails", r, rails)
col_box("DeckCollision", r, (2.2, flat_len, 0.12), (0, 0, height), concave=True)
for s in (1, -1):
    col_box(f"Ramp{'Front' if s > 0 else 'Back'}Collision", r, (2.2, math.hypot(ramp_len, height), 0.12),
            (0, s * ramp_y, height / 2), rotation=(-s * ramp_angle, 0, 0))
for x in (-1.05, 1.05):
    col_box(f"Rail{'L' if x < 0 else 'R'}Collision", r, (0.12, flat_len + 1.0, 1.0), (x, 0, height + 0.5))

# ----------------------------------------------------------------- export + rangement
bpy.context.view_layer.update()
for file_name, root in roots.items():
    lp.export(file_name, animations=file_name in ("chest", "door"), root=root, save=False)
    print("Décor exporté :", file_name)
for i, root in enumerate(roots.values()):
    root.location = ((i % 4) * 6.0, (i // 4) * 6.0, 0)
lp.save_blend("props")
