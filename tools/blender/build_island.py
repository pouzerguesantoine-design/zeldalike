"""Construit le terrain de l'île et le donjon.

- island : disque herbeux plat (y = 0) au contour irrégulier, plage de sable qui descend
  sous l'eau (y = -1,3 au bord). Collision concave « -colonly » (même forme).
- dungeon : salle en ruine de 10 × 10 m à ciel ouvert (la caméra doit pouvoir y entrer),
  murs de 3,5 m, piliers, créneaux, dallage ; ouverture au SUD (−Y Blender = +Z Godot)
  de 1,95 m pile la largeur du cadre de porte (door.glb). Collisions « -convcolonly ».
Sorties : assets/blender/island.blend + island.glb, dungeon.glb.
"""

import importlib
import math
import sys

sys.path.insert(0, r"C:\Users\psamf\Documents\zeldalike\tools\blender")
import lowpoly as lp  # noqa: E402

importlib.reload(lp)
import bmesh  # noqa: E402
import bpy  # noqa: E402

lp.reset_scene()
grass = lp.material("HerbeIle", (0.36, 0.7, 0.26))
sand = lp.material("Sable", (0.93, 0.84, 0.6))
stone = lp.material("PierreDonjon", (0.5, 0.5, 0.55))
stone_dark = lp.material("PierreSombre", (0.36, 0.36, 0.42))
moss = lp.material("Mousse", (0.3, 0.52, 0.25))
floor = lp.material("Dallage", (0.58, 0.55, 0.5))
collision = lp.material("Collision", (1, 0, 1))

# ------------------------------------------------------------------------------ terrain
SEGMENTS = 64
# (rayon, hauteur, matériau des faces entre cet anneau et le précédent)
RINGS = [(12, 0.0, grass), (24, 0.0, grass), (34, 0.0, grass), (42, 0.0, grass),
         (45, -0.6, sand), (49, -1.3, sand)]


def coast(theta):
    """Irrégularité de la côte (même facteur pour tous les anneaux : ordre conservé)."""
    return 1.0 + 0.05 * math.sin(3 * theta + 1.0) + 0.035 * math.sin(7 * theta + 2.0) + 0.02 * math.sin(13 * theta)


def terrain(name, mat_override=None):
    bm = bmesh.new()
    center = bm.verts.new((0, 0, 0))
    previous = None
    materials = []
    for radius, height, mat in RINGS:
        ring = []
        for i in range(SEGMENTS):
            theta = 2 * math.pi * i / SEGMENTS
            r = radius * coast(theta)
            ring.append(bm.verts.new((r * math.cos(theta), r * math.sin(theta), height)))
        material = mat_override or mat
        if material not in materials:
            materials.append(material)
        index = materials.index(material)
        for i in range(SEGMENTS):
            j = (i + 1) % SEGMENTS
            if previous is None:
                face = bm.faces.new((center, ring[i], ring[j]))
            else:
                face = bm.faces.new((previous[i], ring[i], ring[j], previous[j]))
            face.material_index = index
            face.smooth = False
        previous = ring
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    return lp.link(bpy.data.objects.new(name, mesh))


island = lp.link(bpy.data.objects.new("Island", None))
ground = terrain("IslandGround")
ground.parent = island
ground_collision = terrain("IslandGroundCollision-colonly", collision)
ground_collision.parent = island
ground_collision.display_type = "WIRE"

# ------------------------------------------------------------------------------ donjon
dungeon = lp.link(bpy.data.objects.new("Dungeon", None))
HALF, THICK, HEIGHT, GAP = 5.0, 0.8, 3.5, 0.975
walls = [  # (nom, taille, position)
    ("North", (2 * HALF + THICK, THICK, HEIGHT), (0, HALF, HEIGHT / 2)),
    ("West", (THICK, 2 * HALF, HEIGHT), (-HALF, 0, HEIGHT / 2)),
    ("East", (THICK, 2 * HALF, HEIGHT), (HALF, 0, HEIGHT / 2)),
    ("SouthLeft", (HALF - GAP + THICK / 2, THICK, HEIGHT), (-(GAP + HALF + THICK / 2) / 2, -HALF, HEIGHT / 2)),
    ("SouthRight", (HALF - GAP + THICK / 2, THICK, HEIGHT), ((GAP + HALF + THICK / 2) / 2, -HALF, HEIGHT / 2)),
]
parts = []
for name, size, location in walls:
    parts.append(("box", (size, stone), dict(location=location)))
    # Créneaux sur le dessus
    long_axis = 0 if size[0] > size[1] else 1
    count = int(size[long_axis] // 1.2)
    for k in range(count):
        offset = -size[long_axis] / 2 + 0.6 + k * 1.2
        pos = list(location)
        pos[long_axis] += offset
        pos[2] = HEIGHT + 0.25
        parts.append(("box", ((0.55, THICK, 0.5) if long_axis == 0 else (THICK, 0.55, 0.5), stone),
                      dict(location=tuple(pos))))
for sx in (-1, 1):
    for sy in (-1, 1):
        parts.append(("box", ((1.3, 1.3, HEIGHT + 0.8), stone_dark), dict(location=(sx * HALF, sy * HALF, (HEIGHT + 0.8) / 2))))
    # Piliers de l'entrée
    parts.append(("box", ((0.5, 1.0, HEIGHT + 0.4), stone_dark), dict(location=(sx * (GAP + 0.25), -HALF, (HEIGHT + 0.4) / 2))))
# Mousse au pied des murs
for location, size in (((0, HALF - 0.45, 0.12), (9.0, 0.3, 0.24)), ((-HALF + 0.45, 0, 0.12), (0.3, 9.0, 0.24))):
    parts.append(("box", (size, moss), dict(location=location)))
walls_obj = lp.simple_mesh("DungeonWalls", parts)
walls_obj.parent = dungeon
floor_obj = lp.simple_mesh("DungeonFloor", [("box", ((2 * HALF - THICK, 2 * HALF - THICK, 0.02), floor), dict(location=(0, 0, 0.01)))])
floor_obj.parent = dungeon
for name, size, location in walls:
    col = lp.simple_mesh(f"Dungeon{name}Collision-convcolonly", [("box", (size, collision), dict(location=location))])
    col.parent = dungeon
    col.display_type = "WIRE"
for sx in (-1, 1):
    for sy in (-1, 1):
        col = lp.simple_mesh(f"DungeonPillar{'E' if sx > 0 else 'W'}{'N' if sy > 0 else 'S'}Collision-convcolonly",
                             [("box", ((1.3, 1.3, HEIGHT + 0.8), collision), dict(location=(sx * HALF, sy * HALF, (HEIGHT + 0.8) / 2)))])
        col.parent = dungeon
        col.display_type = "WIRE"

lp.save_blend("island")
lp.export("island", animations=False, root=island, save=False)
lp.export("dungeon", animations=False, root=dungeon, save=False)
dungeon.location = (60, 0, 0)
lp.save_blend("island")
print("Île et donjon exportés")
