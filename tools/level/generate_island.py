"""Génère scene/world/island.tscn : le niveau de démonstration (Godot : -Z = nord).

ATTENTION : écrase island.tscn. À n'utiliser que pour repartir de la disposition
d'origine ; ensuite, modifier l'île dans l'éditeur Godot. Après tout changement du décor,
recuire la navigation : godot --headless --path . res://tools/godot/bake_navmesh.tscn
Lancer : python tools/level/generate_island.py (depuis la racine du projet).

  Sud     : plage d'arrivée (joueur) puis VILLAGE (3 maisons, coffre, barrières)
  Ouest   : FORÊT (arbres, coffre caché avec l'épée de chevalier, slimes)
  Rivière : bande d'eau est-ouest (z ≈ -2), franchissable uniquement par le PONT
  Nord    : ZONE D'ENNEMIS (gobelins dont un en patrouille, slimes, coffre gardé avec la clé)
  Nord-est: DONJON fermé par une porte à clé (coffre avec la Lame de feu)
"""
import math
import os
import random

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
random.seed(7)


def coast(theta):
    """Même irrégularité de côte que tools/blender/build_island.py."""
    return 1.0 + 0.05 * math.sin(3 * theta + 1.0) + 0.035 * math.sin(7 * theta + 2.0) + 0.02 * math.sin(13 * theta)


def island_radius_at(x, z):
    # Blender (x, y) = Godot (x, -z)
    return 42.0 * coast(math.atan2(-z, x))


def tr(x, y, z, yaw=0.0, scale=1.0):
    c, s = math.cos(math.radians(yaw)) * scale, math.sin(math.radians(yaw)) * scale
    return f"Transform3D({c:.4g}, 0, {s:.4g}, 0, {scale:g}, 0, {-s:.4g}, 0, {c:.4g}, {x:g}, {y:g}, {z:g})"


ext = []
ext_ids = {}


def res(kind, path):
    if path not in ext_ids:
        ext_ids[path] = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
        ext.append(f'[ext_resource type="{kind}" path="{path}" id="{ext_ids[path]}"]')
    return f'ExtResource("{ext_ids[path]}")'


def model(name):
    return res("PackedScene", f"res://assets/models/{name}.glb")


subs = []


def sub(text):
    subs.append(text)


nodes = []


def node(text):
    nodes.append(text)


# ------------------------------------------------------------------ ressources de base
LEVEL = res("Script", "res://scripts/world/level.gd")
NAVMESH = res("NavigationMesh", "res://resources/navigation/island_navmesh.tres")
PLAYER = res("PackedScene", "res://scene/player/player.tscn")
SLIME = res("PackedScene", "res://scene/enemies/slime.tscn")
GOBLIN = res("PackedScene", "res://scene/enemies/goblin.tscn")
CHEST = res("PackedScene", "res://scene/world/chest.tscn")
DOOR = res("PackedScene", "res://scene/world/door.tscn")
GAME_UI = res("PackedScene", "res://scene/ui/game_ui.tscn")
SAVE_POINT = res("PackedScene", "res://scene/world/save_point.tscn")
KEY = res("Resource", "res://resources/items/small_key.tres")

sub("""[sub_resource type="ProceduralSkyMaterial" id="SkyMaterial_island"]
sky_top_color = Color(0.2, 0.46, 0.88, 1)
sky_horizon_color = Color(0.66, 0.82, 0.96, 1)
sky_curve = 0.12
ground_bottom_color = Color(0.13, 0.3, 0.45, 1)
ground_horizon_color = Color(0.66, 0.82, 0.96, 1)
sun_angle_max = 25.0""")
sub("""[sub_resource type="Sky" id="Sky_island"]
sky_material = SubResource("SkyMaterial_island")""")
# Ambiance lumineuse façon Zelda : ciel, brouillard léger, SSAO, léger éclat, couleurs vives.
sub("""[sub_resource type="Environment" id="Environment_island"]
background_mode = 2
sky = SubResource("Sky_island")
ambient_light_source = 3
ambient_light_energy = 0.55
tonemap_mode = 3
tonemap_exposure = 1.1
ssao_enabled = true
ssao_radius = 1.6
ssao_intensity = 1.6
glow_enabled = true
glow_intensity = 0.35
glow_bloom = 0.05
fog_enabled = true
fog_light_color = Color(0.72, 0.84, 0.96, 1)
fog_density = 0.0035
fog_sky_affect = 0.25
adjustment_enabled = true
adjustment_saturation = 1.15""")
sub("""[sub_resource type="StandardMaterial3D" id="Material_sea"]
transparency = 1
albedo_color = Color(0.16, 0.5, 0.78, 0.86)
metallic = 0.2
roughness = 0.08""")
sub("""[sub_resource type="PlaneMesh" id="PlaneMesh_sea"]
material = SubResource("Material_sea")
size = Vector2(3000, 3000)""")
sub("""[sub_resource type="StandardMaterial3D" id="Material_river"]
transparency = 1
albedo_color = Color(0.25, 0.62, 0.9, 0.9)
metallic = 0.2
roughness = 0.05""")
sub("""[sub_resource type="PlaneMesh" id="PlaneMesh_river"]
material = SubResource("Material_river")
size = Vector2(100, 4)""")

# ------------------------------------------------------------------ racine, lumière, eau
node(f"""[node name="Island" type="Node3D"]
script = {LEVEL}
bake_navigation_on_ready = false""")
node("""[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_island")""")
node("""[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.819152, -0.40558, 0.40558, 0, 0.707107, 0.707107, -0.573576, -0.579228, 0.579228, 0, 20, 0)
light_color = Color(1, 0.96, 0.88, 1)
light_energy = 1.25
shadow_enabled = true
directional_shadow_max_distance = 70.0""")
node("""[node name="Sea" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.55, 0)
cast_shadow = 0
mesh = SubResource("PlaneMesh_sea")""")
node("""[node name="River" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.03, -2)
cast_shadow = 0
mesh = SubResource("PlaneMesh_river")""")

NAV = "NavigationRegion3D"
node(f"""[node name="{NAV}" type="NavigationRegion3D" parent="."]
navigation_mesh = {NAVMESH}""")
node(f"""[node name="Terrain" parent="{NAV}" instance={model("island")}]""")

# ------------------------------------------------------------------ murs invisibles
# Rivière : berges infranchissables sauf au pont (x ∈ [-1,25 ; 1,25]).
sub("""[sub_resource type="BoxShape3D" id="Shape_riverbank"]
size = Vector3(47, 4, 0.5)""")
node(f"""[node name="RiverBanks" type="StaticBody3D" parent="{NAV}"]""")
for i, (x, z) in enumerate([(-24.75, 0.25), (24.75, 0.25), (-24.75, -4.25), (24.75, -4.25)]):
    node(f"""[node name="Bank{i + 1}" type="CollisionShape3D" parent="{NAV}/RiverBanks"]
transform = {tr(x, 1.5, z)}
shape = SubResource("Shape_riverbank")""")
# Bord de l'île : anneau de murs au niveau de l'eau.
node(f"""[node name="Shore" type="StaticBody3D" parent="{NAV}"]""")
SEG = 48
points = []
for i in range(SEG):
    theta = 2 * math.pi * i / SEG
    r = 44.5 * coast(theta)
    points.append((r * math.cos(theta), -r * math.sin(theta)))
for i in range(SEG):
    (x1, z1), (x2, z2) = points[i], points[(i + 1) % SEG]
    length = math.hypot(x2 - x1, z2 - z1) + 0.6
    yaw = math.degrees(math.atan2(-(z2 - z1), x2 - x1))
    sub(f"""[sub_resource type="BoxShape3D" id="Shape_shore{i}"]
size = Vector3({length:.3f}, 5, 1)""")
    node(f"""[node name="Wall{i}" type="CollisionShape3D" parent="{NAV}/Shore"]
transform = {tr((x1 + x2) / 2, 1.5, (z1 + z2) / 2, yaw)}
shape = SubResource("Shape_shore{i}")""")


# ------------------------------------------------------------------ décors
def prop(group, name, kind, x, z, yaw=0.0, scale=1.0):
    node(f"""[node name="{name}" parent="{NAV}/{group}" instance={model(kind)}]
transform = {tr(x, 0, z, yaw, scale)}""")


def scatter(group, prefix, count, xmin, xmax, zmin, zmax, kinds, avoid, min_gap=3.2, scale=(0.9, 1.35)):
    placed = []
    tries = 0
    while len(placed) < count and tries < 2000:
        tries += 1
        x, z = random.uniform(xmin, xmax), random.uniform(zmin, zmax)
        if math.hypot(x, z) > island_radius_at(x, z) - 3:
            continue
        if any(math.hypot(x - ax, z - az) < ar for ax, az, ar in avoid):
            continue
        if any(math.hypot(x - px, z - pz) < min_gap for px, pz in placed):
            continue
        placed.append((x, z))
        prop(group, f"{prefix}{len(placed)}", random.choice(kinds), round(x, 2), round(z, 2),
             random.uniform(0, 360), round(random.uniform(*scale), 2))
    return placed


for group in ("Village", "Forest", "North", "Dungeon", "Coast"):
    node(f"""[node name="{group}" type="Node3D" parent="{NAV}"]""")

# Village : 3 maisons autour d'une place, barrières au sud avec un passage.
prop("Village", "HouseWest", "house", -10, 13, -90)
prop("Village", "HouseEast", "house", 10, 13, 90)
prop("Village", "HouseNorth", "house", 0, 5.5, 180)
for i, x in enumerate([-11, -9, -7, -5, 5, 7, 9, 11]):
    prop("Village", f"Fence{i + 1}", "fence", x, 22)
prop("Village", "TreeWest", "tree_round", -15, 20, 30, 1.2)
prop("Village", "TreeEast", "tree_round", 15, 7, 80, 1.1)
prop("Village", "PineNorthWest", "tree_pine", -15, 4, 0, 1.1)
for i, (x, z) in enumerate([(-4, 18), (5, 19), (-6, 9), (6, 8), (-2, 24), (3, 27), (-12, 26), (13, 25)]):
    prop("Village", f"Grass{i + 1}", "grass", x, z, i * 47, 1.1)
# Pont sur la rivière
prop("Village", "Bridge", "bridge", 0, -2)

village_avoid = [(0, 14, 16), (0, -2, 5)]
# Forêt (ouest)
scatter("Forest", "Tree", 22, -40, -17, -1, 32, ["tree_round", "tree_pine", "tree_pine"],
        village_avoid + [(-30, 14, 3.5), (-24, 8, 2.5), (-32, 22, 2.5)])
scatter("Forest", "Grass", 14, -40, -17, -1, 32, ["grass"], village_avoid, min_gap=2.0, scale=(1.0, 1.4))
prop("Forest", "RockA", "rock_a", -20, 27, 40, 1.2)
prop("Forest", "RockB", "rock_b", -37, 5, 120, 1.1)
# Zone nord (ennemis)
north_avoid = [(-18, -21, 6), (-26, -28, 3.5), (22, -26, 9), (0, -2, 5), (6, -20, 3), (-8, -14, 3)]
scatter("North", "Tree", 14, -38, 38, -40, -7, ["tree_pine", "tree_round"], north_avoid, min_gap=5.0)
scatter("North", "Rock", 8, -36, 36, -38, -8, ["rock_a", "rock_b"], north_avoid, min_gap=5.0, scale=(1.0, 1.6))
scatter("North", "Grass", 10, -30, 30, -34, -8, ["grass"], north_avoid, min_gap=3.0)
# Donjon (nord-est) : entrée au sud, à z = -21
prop("Dungeon", "Ruins", "dungeon", 22, -26)
prop("Dungeon", "RockNear1", "rock_b", 15, -22, 30, 1.2)
prop("Dungeon", "RockNear2", "rock_a", 29, -19, 200, 1.0)
# Côte : quelques rochers
for i, angle in enumerate([20, 75, 150, 200, 250, 320]):
    theta = math.radians(angle)
    r = 40.5 * coast(theta)
    prop("Coast", f"Rock{i + 1}", "rock_a" if i % 2 else "rock_b", round(r * math.cos(theta), 2),
         round(-r * math.sin(theta), 2), angle * 3, 1.3)

# ------------------------------------------------------------------ coffres et porte
for name, x, z, yaw, table in [("ChestVillage", 4, 16, 180, "chest_village"),
                               ("ChestForest", -30, 14, -90, "chest_forest"),
                               ("ChestKey", -26, -28, -90, "chest_key"),
                               ("ChestDungeon", 22, -29, 180, "chest_dungeon")]:
    loot = res("Resource", f"res://resources/loot_tables/{table}.tres")
    node(f"""[node name="{name}" parent="{NAV}" instance={CHEST}]
transform = {tr(x, 0, z, yaw)}
chest_id = &"{table.replace('chest_', '')}"
loot_table = {loot}""")
node(f"""[node name="SavePoint" parent="{NAV}" instance={SAVE_POINT}]
transform = {tr(-4, 0, 15)}""")
node(f"""[node name="DungeonDoor" parent="{NAV}" instance={DOOR}]
transform = {tr(22, 0, -21)}
door_id = &"dungeon"
required_key = {KEY}""")
for i, x in enumerate([19, 25]):
    node(f"""[node name="Torch{i + 1}" type="OmniLight3D" parent="{NAV}/Dungeon"]
transform = {tr(x, 2.6, -29)}
light_color = Color(1, 0.62, 0.25, 1)
light_energy = 2.0
omni_range = 7.0""")

# ------------------------------------------------------------------ ennemis
node("""[node name="Enemies" type="Node3D" parent="."]""")
node("""[node name="GoblinPatrol" type="Node3D" parent="Enemies"]""")
for name, x, z in (("A", -22, -16), ("B", -13, -16), ("C", -13, -26), ("D", -22, -26)):
    node(f"""[node name="{name}" type="Marker3D" parent="Enemies/GoblinPatrol"]
transform = {tr(x, 0, z)}""")
for name, x, z in (("SlimeForest1", -24, 8), ("SlimeForest2", -32, 22), ("SlimeNorth1", -8, -14),
                   ("SlimeNorth2", 6, -20), ("SlimeNorth3", 12, -12)):
    node(f"""[node name="{name}" parent="Enemies" instance={SLIME}]
transform = {tr(x, 0, z)}""")
node(f"""[node name="GoblinPatrol1" parent="Enemies" node_paths=PackedStringArray("patrol_points") instance={GOBLIN}]
transform = {tr(-18, 0, -21)}
patrol_points = [NodePath("../GoblinPatrol/A"), NodePath("../GoblinPatrol/B"), NodePath("../GoblinPatrol/C"), NodePath("../GoblinPatrol/D")]""")
node(f"""[node name="GoblinGuard" parent="Enemies" instance={GOBLIN}]
transform = {tr(-22, 0, -31)}
wander_radius = 3.0""")
node(f"""[node name="GoblinNorth" parent="Enemies" instance={GOBLIN}]
transform = {tr(8, 0, -30)}""")

# ------------------------------------------------------------------ joueur et interface
node(f"""[node name="Player" parent="." instance={PLAYER}]
transform = {tr(0, 0.1, 32)}""")
node(f"""[node name="GameUI" parent="." instance={GAME_UI}]""")

text = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n" + "\n\n".join(nodes) + "\n"
with open("scene/world/island.tscn", "w", encoding="utf-8", newline="\n") as f:
    f.write(text)
print("island.tscn :", len(nodes), "nœuds")
