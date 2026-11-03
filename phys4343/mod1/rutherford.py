"""Rutherford scattering, Blender 4.0+: horizontal incident beam, seven paths, and visible cloud.

Run: blender --background --python rutherford_v4.py
Optional: blender --background --python rutherford_v4.py -- /path/figure.png

The curves are numerical trajectories in a repulsive Coulomb field. The
nucleus is enlarged, and the electron cloud is a schematic visual guide,
not a historically established or to-scale representation.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

SIZE = (1800, 1100)
SAMPLES = 80
IMPACT_PARAMETERS = [-3.35, -2.10, -0.70, 0.65, 1.25, 2.10, 3.35]
HIGHLIGHT_IMPACT = -0.70
K = 1.0
SPEED = 1.0
DT = 0.018
START_X = -7.0


def output_path():
    argv = sys.argv
    if '--' in argv and len(argv) > argv.index('--') + 1:
        return Path(argv[argv.index('--') + 1]).expanduser().resolve()
    return Path.cwd() / 'rutherford.png'


def mat(name, rgb, roughness=0.45, metallic=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Alpha'].default_value = alpha
    m.diffuse_color = (*rgb, alpha)
    if alpha < 1:
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'DITHERED'
        elif hasattr(m, 'blend_method'):
            m.blend_method = 'BLEND'
        if hasattr(m, 'show_transparent_back'):
            m.show_transparent_back = False
    return m


def sphere(name, center, radius, material, segments=64, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=radius, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return ob


def curve(name, points, radius, material):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    spl = cu.splines.new('POLY')
    spl.points.add(len(points)-1)
    for p, xyz in zip(spl.points, points):
        p.co = (*xyz, 1)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material)
    return ob


def deriv(state):
    x, y, vx, vy = state
    r2 = max(x*x+y*y, 1e-10)
    a = K / (r2 * math.sqrt(r2))
    return vx, vy, a*x, a*y


def rk4(state, dt):
    def plus(s, k, h):
        return tuple(v + h*w for v, w in zip(s, k))
    a = deriv(state)
    b = deriv(plus(state, a, dt/2))
    c = deriv(plus(state, b, dt/2))
    d = deriv(plus(state, c, dt))
    return tuple(v + dt*(aa+2*bb+2*cc+dd)/6
                 for v, aa, bb, cc, dd in zip(state, a, b, c, d))


def trajectory(impact):
    s = (START_X, impact, SPEED, 0.0)
    points = []
    for i in range(4000):
        x, y, vx, vy = s
        if i % 3 == 0:
            points.append((x, y, 0.10))
        # Crop far-field lines to make the illustration less cluttered.
        if i > 100 and (x < -7.1 or x > 7.1 or abs(y) > 5.0):
            break
        s = rk4(s, DT)
    return points


def arrow(name, points, material, fraction=0.80):
    i = min(len(points)-2, max(0, int(fraction*(len(points)-1))))
    p = Vector(points[i])
    direction = (Vector(points[i+1]) - p).normalized()
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.095,
                                    radius2=0, depth=0.29, location=p)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    ob.data.materials.append(material)


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


def area(name, position, power, size):
    bpy.ops.object.light_add(type='AREA', location=position)
    ob = bpy.context.object
    ob.name = name
    ob.data.energy = power
    ob.data.shape = 'DISK'
    ob.data.size = size
    aim(ob, (0,0,0))


def main():
    out = output_path()
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = False
    for layer in scene.view_layers:
        layer.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.filepath = str(out)
    scene.render.film_transparent = False

    # Standard transform + full-strength white world produces a white page,
    # unlike the gray background from the previous AgX setup.
    scene.world.use_nodes = True
    world_bg = scene.world.node_tree.nodes.get('Background')
    world_bg.inputs['Color'].default_value = (1,1,1,1)
    world_bg.inputs['Strength'].default_value = 1.0
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'Medium High Contrast'
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1

    # Camera-facing blue haze with an emphasized silhouette.
    # Using shader nodes instead of BSDF alpha makes it visible in Cycles.
    cloud = bpy.data.materials.new('Visible translucent electron cloud')
    cloud.use_nodes = True
    nodes = cloud.node_tree.nodes
    nodes.clear()
    links = cloud.node_tree.links
    output = nodes.new('ShaderNodeOutputMaterial')
    transparent = nodes.new('ShaderNodeBsdfTransparent')
    tint = nodes.new('ShaderNodeEmission')
    tint.inputs['Color'].default_value = (0.42, 0.72, 0.95, 1.0)
    tint.inputs['Strength'].default_value = 1.0
    mix = nodes.new('ShaderNodeMixShader')
    facing = nodes.new('ShaderNodeLayerWeight')
    ramp = nodes.new('ShaderNodeValToRGB')
    # Facing ~1 at the center and ~0 near the silhouette.
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.48, 0.48, 0.48, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.12, 0.12, 0.12, 1)
    links.new(facing.outputs['Facing'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(tint.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs['Surface'])
    rim = mat('Cloud outline', (0.45, 0.70, 0.88), alpha=0.38)
    gold = mat('Warm gold nucleus', (0.93,0.47,0.045), metallic=0.55, roughness=0.22)
    blue = mat('Blue alpha paths', (0.015,0.29,0.62), roughness=0.32)
    red = mat('Orange-red large-angle scattering', (0.90,0.19,0.075), roughness=0.32)
    particles = mat('Alpha particle spheres', (0.03,0.34,0.72), metallic=0.15)

    sphere('Electron cloud, schematic', (0,0,-0.22), 2.8, cloud, 96, 48)
    # One faint silhouette circle; no orbit-like rings.
    pts = [(2.82*math.cos(2*math.pi*j/240),
            2.82*math.sin(2*math.pi*j/240), -0.15) for j in range(241)]
    curve('Cloud silhouette', pts, 0.012, rim)
    sphere('Gold nucleus - enlarged, NOT TO SCALE', (0,0,0), 0.27, gold)

    for impact in IMPACT_PARAMETERS:
        pts = trajectory(impact)
        highlighted = False # abs(impact - HIGHLIGHT_IMPACT) < 1e-6
        material = red if highlighted else blue
        curve('Coulomb trajectory b=%+.2f' % impact, pts,
              0.042 if highlighted else 0.032, material)
        arrow('Outgoing direction b=%+.2f' % impact, pts, material,
              fraction=0.78 if not highlighted else 0.88)
        if not highlighted:
            sphere('Incoming alpha b=%+.2f' % impact, pts[12], 0.105,
                   particles, 24, 12)

    # View normal to the scattering plane: incident beam is horizontal.
    # Lighting and material shading retain a three-dimensional appearance.
    bpy.ops.object.camera_add(location=(0, 0, 24))
    cam = bpy.context.object
    cam.name = 'Horizontal beam orthographic camera'
    aim(cam, (0,0,0))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 19.0
    scene.camera = cam

    area('Large softbox left', (-5,-5,10), 1050, 8)
    area('Large softbox right', (5,4,9), 650, 7)

    bpy.ops.wm.save_as_mainfile(filepath=str(out.with_suffix('.blend')))
    bpy.ops.render.render(write_still=True)
    print('Wrote:', out)
    print('Wrote:', out.with_suffix('.blend'))

if __name__ == '__main__':
    main()
