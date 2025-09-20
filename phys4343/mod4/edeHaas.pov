#version 3.7;
#include "colors.inc"
#include "textures.inc"

// Global settings for realistic rendering
global_settings {
  assumed_gamma 1.0
  photons {
    count 20000
    media 100 // Corrected syntax for media photons
    jitter 1.0
  }
}

// Camera setup
camera {
  location <2, 3, -10>
  look_at <0, 2.5, 0>
  angle 45
}

// Light source for illumination
light_source {
  <10, 15, -10>
  color White
  shadowless
}

// Background
background { color rgb <0.9, 0.95, 1.0> }


// Define a reusable texture for copper
#declare CopperTexture = texture {
    Copper_Metal
}

// Rod is an elongated cylinder.
#declare Rod = cylinder {
  <0, 0, 0>, <0, 0.7, 0>, 0.2
  pigment { color rgb<0.4, 0.4, 0.4> }
  finish { phong 0.8 }
}

// Rod is suspended from a support by a thin thread.
#declare Thread = cylinder {
  <0, 0.7, 0>, <0, 5.5, 0>, 0.01
  pigment { color Black }
}

// Support for the thread
object {
  box {
    <-1, 5.5, -1>, <1, 6, 1>
    pigment { color Brown }
    finish { phong 0.5 }
  }
}

// Define the solenoid as a series of rings.
#declare SolenoidRing = torus {
  1.5, 0.05
  texture { CopperTexture }
  scale 0.2
  rotate <0, 0, 10>
}

// Loop to place multiple rings to form the solenoid.
#declare I = 0;
#while (I < 9)
  object {
    SolenoidRing
    translate <0, 0.08 * I, 0>
    // Offset the rings slightly to give a layered look
    // rotate <0, 5 * I, 0>
  }
  #declare I = I + 1;
#end

// The small, square mirror is attached to the top of the rod.
#declare Mirror = box {
  <-0.2, 4.8, -0.2>, <0.2, 5.1, 0.2>
  finish {
    reflection { 1.0 } // 100% mirror reflection
    ambient 0
    diffuse 0
  }
}

// // Create a visual indicator for the magnetic field direction.
// #declare FieldLine = cylinder {
//   <0, -0.5, 0>, <0, 5.5, 0>, 0.05
//   pigment { color Blue }
//   finish { emission 0.5 }
// }

// // Use a conditional statement to switch the field direction.
// #if (frame_number > 50)
//   object { FieldLine }
// #else
//   object { FieldLine rotate <0, 180, 0> }
// #end

// // Animate the rod's rotation.
// #declare RodRotationAngle = 0;
// #if (frame_number > 50)
//   // After the magnetic field is reversed, the rod begins to rotate.
//   #declare RodRotationAngle = (frame_number - 50) * 5;
// #end

// Combine all the elements into the scene.
object { Rod }//rotate <0, RodRotationAngle, 0> }
object { Thread }
object { Mirror translate <0,-1,0>}


// The screen where the laser dot will be projected
object {
  plane { z, 10
    pigment { color White }
    finish { phong 0.5 }
  }
}

// Define a laser light source
light_source {
  <5, 4, -8> // Laser's origin
  color rgb<1, 0, 0> // Red laser
  spotlight
  radius 0.2
  falloff 0.2
  tightness 1
  point_at <0, 5, 0> // Aim the laser at the mirror
  photons {  reflection on  } // Enable photons for realistic reflection
}

// Define the scattering medium for the laser beam
#declare LaserBeam = cylinder {
  <5, 4, -8>, <0, 5, 0>, 0.02 // Laser beam path
  pigment { color rgbt <1, 0, 0, 0.9> } // Semi-transparent red
  interior {
    media {
      emission rgb<3, 0, 0> // Emission color (red)
      scattering { 1, rgb<2, 0.2, 0.2> } // Scattering type and color
    }
  }
  photons { pass_through } // Allow photons to pass through the beam
}

object { LaserBeam translate <0,-1,0>}

// The reflected laser beam
#declare ReflectedBeam = object { LaserBeam translate <0,-1,0>}
object { ReflectedBeam rotate <0, 2*12, 0> } // Reflection angle is twice the rotation angle


// text {
//     ttf "timrom.ttf" "current carrying coil" 0.1, 0
//     pigment { color Black }
//     scale 0.18
//     translate <-2, 0.2, 0>
//     rotate <0,-25,0>
// }

text {
    ttf "timrom.ttf" "electric coil" 0.1, 0
    pigment { color Black }
    scale 0.18
    translate <-1.4, 0.2, 0>
    rotate <0,-25,0>
}

cylinder {
  <-0.5, 0.17, 0.07>, <-0.3, 0.2, 0.05>, 0.01
  pigment { color Black }
}


text {
    ttf "timrom.ttf" "ferromagnetic core" 0.1, 0
    pigment { color Black }
    scale 0.18
    translate <0.4, 0.86, 0>
}


cylinder {
  <0.5, 0.82, 0.07>, <0.1, 0.7, 0.05>, 0.01
  pigment { color Black }
}


text {
    ttf "timrom.ttf" "probe light beam" 0.1, 0
    pigment { color Black }
    scale 0.2
    rotate <0,-25,0>
    translate <2, 4, 0>
}


text {
    ttf "timrom.ttf" "Mirror" 0.1, 0
    pigment { color Black }
    scale 0.2
    translate <-0.7, 4.2, 0>
}