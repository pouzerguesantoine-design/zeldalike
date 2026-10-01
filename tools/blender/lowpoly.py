"""Outils communs pour construire les modèles low-poly du jeu dans Blender (via le MCP).

Conventions (voir CLAUDE.md, jalon 5) :
- 1 unité = 1 mètre, origine aux pieds, Z vers le haut dans Blender (+Y dans Godot après export).
- Le personnage regarde vers +Y dans Blender, ce qui donne -Z dans Godot (l'avant d'un Node3D).
- Pièces rigides : chaque pièce est pondérée à 100 % sur un seul os (style low-poly).
- Couleurs par matériaux simples, ombrage plat, pas de textures.
- Animations : une action par animation, rangée dans sa propre piste NLA (nom exact), puis
  export .glb en mode NLA_TRACKS.
"""

import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 30
PROJECT_DIR = r"C:\Users\psamf\Documents\zeldalike"
MODELS_DIR = os.path.join(PROJECT_DIR, "assets", "models")
BLEND_DIR = os.path.join(PROJECT_DIR, "assets", "blender")


# --------------------------------------------------------------------------- scène

def reset_scene():
    """Vide la scène courante (objets et données) et règle les unités."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures,
                       bpy.data.actions, bpy.data.cameras, bpy.data.lights):
        for block in list(collection):
            collection.remove(block)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.frame_start = 1


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ------------------------------------------------------------------------ matériaux

# Palette commune (sRGB) : couleurs franches et chaudes, harmonisées entre héros,
# ennemis et décor (style Zelda low-poly).
PALETTE = {
    "skin": (1.0, 0.8, 0.66), "hair": (0.98, 0.82, 0.36), "hair_dark": (0.62, 0.42, 0.16),
    "eye": (0.07, 0.14, 0.3), "tunic": (0.26, 0.64, 0.22), "tunic_dark": (0.15, 0.44, 0.16),
    "cream": (0.96, 0.92, 0.8), "leather": (0.5, 0.3, 0.14), "leather_dark": (0.33, 0.19, 0.09),
    "gold": (0.98, 0.78, 0.25), "silver": (0.8, 0.83, 0.88), "royal_blue": (0.2, 0.36, 0.7),
    "goblin_skin": (0.5, 0.7, 0.26), "goblin_skin_dark": (0.36, 0.52, 0.18), "rag": (0.55, 0.36, 0.18),
    "slime": (0.34, 0.85, 0.42), "slime_core": (0.18, 0.58, 0.26),
    "leaves": (0.32, 0.66, 0.24), "leaves_light": (0.5, 0.78, 0.3), "leaves_dark": (0.2, 0.47, 0.2),
    "pine": (0.15, 0.46, 0.27), "pine_light": (0.24, 0.58, 0.33), "bark": (0.46, 0.29, 0.15),
    "bark_dark": (0.32, 0.2, 0.1),
}


def srgb_to_linear(color):
    """Les couleurs des scripts sont données en sRGB (comme un sélecteur de couleur) ;
    Blender (et le glTF) stockent les couleurs de matériau en espace LINÉAIRE."""
    def channel(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(channel(c) for c in color)


def material(name, color, roughness=0.8, metallic=0.0, emission=None, emission_strength=2.0, alpha=1.0):
    """Matériau Principled simple (couleur unie, donnée en sRGB). Réutilisé s'il existe déjà."""
    color = srgb_to_linear(color)
    if emission:
        emission = srgb_to_linear(emission)
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attribute, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(mat, attribute, value)
            except (AttributeError, TypeError):
                pass
    mat.diffuse_color = (*color, alpha)
    return mat


# -------------------------------------------------------------------------- maillages

def transform(location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    """Matrice depuis une position, une rotation en degrés (XYZ) et une échelle."""
    rot = Euler([math.radians(a) for a in rotation], "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(location) @ rot @ Matrix.Diagonal((*scale, 1.0))


class MeshBuilder:
    """Assemble des primitives dans un seul maillage, avec un matériau et un groupe de
    sommets (= os) par pièce. Les coordonnées sont directement celles de l'objet final,
    qui reste à l'origine avec des transformations nulles (« Ctrl+A » inutile)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.materials = []
        self.groups = []

    def _material_index(self, mat):
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def _group_index(self, group):
        if group not in self.groups:
            self.groups.append(group)
        return self.groups.index(group)

    def _finish_part(self, verts, mat, group):
        verts = set(verts)
        index = self._material_index(mat)
        for face in {f for v in verts for f in v.link_faces}:
            face.material_index = index
            face.smooth = False
        if group:
            gi = self._group_index(group)
            for v in verts:
                v[self.deform][gi] = 1.0
        return verts

    def box(self, size, mat, group=None, **tr):
        """Pavé de dimensions `size` (x, y, z) centré sur `location`."""
        m = transform(**tr) @ Matrix.Diagonal((*size, 1.0))
        result = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        return self._finish_part(result["verts"], mat, group)

    def cylinder(self, radius, depth, mat, group=None, segments=8, radius_top=None, **tr):
        """Cylindre (ou cône si radius_top diffère) le long de Z, centré sur `location`."""
        top = radius if radius_top is None else radius_top
        result = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                       radius1=radius, radius2=top, depth=depth, matrix=transform(**tr))
        return self._finish_part(result["verts"], mat, group)

    def sphere(self, radius, mat, group=None, segments=8, rings=6, **tr):
        result = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings,
                                           radius=radius, matrix=transform(**tr))
        return self._finish_part(result["verts"], mat, group)

    def ico(self, radius, mat, group=None, subdivisions=1, **tr):
        result = bmesh.ops.create_icosphere(self.bm, subdivisions=subdivisions, radius=radius,
                                            matrix=transform(**tr))
        return self._finish_part(result["verts"], mat, group)

    def build(self, name):
        mesh = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        obj = link(bpy.data.objects.new(name, mesh))
        for group in self.groups:
            obj.vertex_groups.new(name=group)
        return obj


def simple_mesh(name, parts):
    """Maillage sans os : `parts` est une liste de (méthode, args, kwargs)."""
    builder = MeshBuilder()
    for method, args, kwargs in parts:
        getattr(builder, method)(*args, **kwargs)
    return builder.build(name)


# ---------------------------------------------------------------------------- squelette

def make_armature(name, bones):
    """Crée une armature. `bones` : liste de (nom, tête, queue, parent)."""
    data = bpy.data.armatures.new(name)
    arm = link(bpy.data.objects.new(name, data))
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, head, tail, parent in bones:
        eb = data.edit_bones.new(bone_name)
        eb.head = head
        eb.tail = tail
        eb.roll = 0.0
        if parent:
            eb.parent = data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def skin(mesh_obj, arm):
    """Attache le maillage à l'armature (groupes de sommets = os)."""
    mesh_obj.parent = arm
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm


def attach_to_bone(obj, arm, bone_name):
    """Parente un objet (ex. un Empty « WeaponSocket ») à un os, en gardant sa position
    et son orientation (calculées dans la pose de repos). Un enfant d'os est placé
    relativement à la QUEUE de l'os."""
    desired = obj.matrix_basis.copy()
    bone = arm.data.bones[bone_name]
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_parent_inverse = Matrix.Identity(4)
    tail_frame = arm.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))
    obj.matrix_basis = tail_frame.inverted() @ desired


# ---------------------------------------------------------------------------- animation

class Animation:
    """Une animation = une action rangée dans sa propre piste NLA.

    Poses décrites en repère MONDE (Blender : +X droite, +Y avant, +Z haut) :
      {"os": {"rot": [(axe, degrés), ...], "loc": (x, y, z), "scale": (sx, sy, sz)}}
    Les rotations sont converties dans le repère de repos de l'os et appliquées dans l'ordre.
    Tous les os sont clés à chaque pose : chaque pose est complète et explicite.
    """

    def __init__(self, arm, name):
        self.arm = arm
        self.name = name
        self.action = bpy.data.actions.new(name)
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = self.action
        self.last_frame = 1

    def _local(self, pb, vector):
        return (pb.bone.matrix_local.to_3x3().inverted() @ Vector(vector))

    def pose(self, frame, bones=None):
        bones = bones or {}
        for pb in self.arm.pose.bones:
            spec = bones.get(pb.name, {})
            q = Quaternion()
            for axis, degrees in spec.get("rot", []):
                q = Quaternion(self._local(pb, axis).normalized(), math.radians(degrees)) @ q
            pb.rotation_quaternion = q
            pb.location = self._local(pb, spec.get("loc", (0, 0, 0)))
            pb.scale = Vector(spec.get("scale", (1, 1, 1)))
            for path in ("rotation_quaternion", "location", "scale"):
                pb.keyframe_insert(path, frame=frame)
        self.last_frame = max(self.last_frame, frame)

    def finish(self):
        data = self.arm.animation_data
        track = data.nla_tracks.new()
        track.name = self.name
        strip = track.strips.new(self.name, 1, self.action)
        strip.name = self.name
        data.action = None
        return strip


class ObjectAnimation:
    """Animation d'objets (sans squelette), ex. couvercle de coffre, porte.
    Poses : {objet: {"rot": (x, y, z) degrés, "loc": (x, y, z)}} en valeurs locales."""

    def __init__(self, name, objects):
        self.name = name
        self.objects = objects
        self.actions = {}
        for obj in objects:
            action = bpy.data.actions.new(f"{name}_{obj.name}")
            if obj.animation_data is None:
                obj.animation_data_create()
            obj.animation_data.action = action
            obj.rotation_mode = "XYZ"
            self.actions[obj] = action

    def pose(self, frame, objects):
        for obj, spec in objects.items():
            if "rot" in spec:
                obj.rotation_euler = [math.radians(a) for a in spec["rot"]]
                obj.keyframe_insert("rotation_euler", frame=frame)
            if "loc" in spec:
                obj.location = spec["loc"]
                obj.keyframe_insert("location", frame=frame)

    def finish(self):
        for obj, action in self.actions.items():
            track = obj.animation_data.nla_tracks.new()
            track.name = self.name
            strip = track.strips.new(self.name, 1, action)
            strip.name = self.name
            obj.animation_data.action = None


def frames(seconds):
    """Durée en secondes → numéro de la dernière image (la 1re image est 1)."""
    return 1 + round(seconds * FPS)


# ---------------------------------------------------------------------------- export

def save_blend(name):
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, f"{name}.blend"), copy=True)


def export(name, animations=True, root=None, save=True):
    """Sauvegarde le .blend (assets/blender/) et exporte le .glb (assets/models/).
    Avec `root`, n'exporte que cet objet et ses enfants (plusieurs modèles par .blend)."""
    os.makedirs(MODELS_DIR, exist_ok=True)
    glb_path = os.path.join(MODELS_DIR, f"{name}.glb")
    if save:
        save_blend(name)
    if root is not None:
        for obj in bpy.context.scene.objects:
            obj.select_set(False)
        for obj in [root, *root.children_recursive]:
            obj.select_set(True)
    options = dict(
        filepath=glb_path, export_format="GLB", use_selection=root is not None, export_yup=True,
        export_apply=True, export_animations=animations, export_skins=True,
        export_materials="EXPORT", export_cameras=False, export_lights=False,
    )
    if animations:
        options.update(export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                       export_def_bones=False)
    bpy.ops.export_scene.gltf(**options)
    return glb_path
