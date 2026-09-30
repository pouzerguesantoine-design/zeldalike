"""Construit les 3 armes : épée en bois, épée de chevalier, lame de feu.
Convention : poignée à l'origine, lame vers +Y dans Blender (= -Z dans Godot), comme
l'Empty « WeaponSocket » du joueur. Sorties : assets/blender/weapons.blend et un .glb
par arme dans assets/models/.
"""

import importlib
import sys

sys.path.insert(0, r"C:\Users\psamf\Documents\zeldalike\tools\blender")
import lowpoly as lp  # noqa: E402

importlib.reload(lp)
import bpy  # noqa: E402

lp.reset_scene()


def sword(name, blade_mat, blade_len, blade_w, guard_mat, grip_mat, pommel_mat, guard_w=0.3, fuller=None):
    mb = lp.MeshBuilder()
    # Lame (pavé fin) + pointe (cône aplati à 4 côtés)
    mb.box((blade_w, blade_len, 0.035), blade_mat, location=(0, 0.12 + blade_len / 2, 0))
    mb.cylinder(blade_w * 0.7, 0.18, blade_mat, segments=4, radius_top=0.0,
                location=(0, 0.12 + blade_len + 0.09, 0), rotation=(-90, 45, 0), scale=(1, 0.3, 1))
    if fuller:
        mb.box((blade_w * 0.3, blade_len * 0.8, 0.04), fuller, location=(0, 0.12 + blade_len * 0.45, 0))
    # Garde, poignée, pommeau
    mb.box((guard_w, 0.06, 0.07), guard_mat, location=(0, 0.1, 0))
    mb.cylinder(0.028, 0.2, grip_mat, segments=6, location=(0, -0.02, 0), rotation=(-90, 0, 0))
    mb.sphere(0.045, pommel_mat, segments=6, rings=4, location=(0, -0.14, 0))
    return mb.build(name)


wood = lp.material("BoisClair", (0.69, 0.48, 0.27))
wood_dark = lp.material("BoisFonce", (0.4, 0.25, 0.12))
steel = lp.material("Acier", (0.85, 0.88, 0.94), metallic=0.8, roughness=0.25)
blue = lp.material("CuirBleu", (0.2, 0.22, 0.55))
gold = lp.material("OrGarde", (0.9, 0.72, 0.2), metallic=0.7, roughness=0.35)
fire = lp.material("LameFeu", (1.0, 0.42, 0.1), roughness=0.4, emission=(1.0, 0.35, 0.05), emission_strength=3.0)
fire_core = lp.material("CoeurFeu", (1.0, 0.85, 0.3), emission=(1.0, 0.8, 0.2), emission_strength=4.0)
obsidian = lp.material("Obsidienne", (0.12, 0.05, 0.05), roughness=0.3)

weapons = {
    "wooden_sword": sword("WoodenSword", wood, 0.72, 0.09, wood_dark, wood_dark, wood_dark, guard_w=0.24),
    "knight_sword": sword("KnightSword", steel, 1.0, 0.1, gold, blue, gold, fuller=lp.material("Gorge", (0.6, 0.66, 0.75), metallic=0.8)),
    "fire_blade": sword("FireBlade", fire, 0.95, 0.11, obsidian, obsidian, fire_core, guard_w=0.34, fuller=fire_core),
}

lp.save_blend("weapons")
for file_name, obj in weapons.items():
    lp.export(file_name, animations=False, root=obj, save=False)
    print("Arme exportée :", file_name)
# Rangées côte à côte dans le .blend pour les voir d'un coup d'œil (après l'export).
for i, obj in enumerate(weapons.values()):
    obj.location.x = i * 0.5
lp.save_blend("weapons")
