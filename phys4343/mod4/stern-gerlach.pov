// Stern-Gerlach Experiment POV-Ray Scene
// Recreates the classic quantum mechanics experiment setup
#version 3.7;
// Include standard colors and textures
#include "colors.inc"
#include "textures.inc"
#include "metals.inc"
// Camera setup
camera {
    location <-8, 6, -12>
    look_at <0, 0, 0>
    angle 35
}
// Lighting
light_source {
    <-10, 15, -10>
    color White * 1.2
    shadowless
}
light_source {
    <10, 10, -5>
    color White * 0.8
    shadowless
}
// Background
background { color rgb <0.9, 0.95, 1.0> }
// Source (oven) - brown box
box {
    <-6, -0.5, -0.5>, <-4.5, 0.5, 0.5>
    pigment { color rgb <0.6, 0.4, 0.2> }
    finish { ambient 0.3 diffuse 0.7 }
}
// Source label
text {
    ttf "timrom.ttf" "Source" 0.1, 0
    pigment { color Black }
    scale 0.25
    translate <-5.8, -0.8, 0>
}
// Upper magnet (North pole) - red with knife-edge pole piece
//union {
    // Main magnet body
//    box {
//        <-2.5, 0.8, -1>, <1, 1.5, 1>
//        pigment { color rgb <0.8, 0.2, 0.2> }
//        finish { ambient 0.3 diffuse 0.7 }
//    }
    // Sharp knife-edge pole piece pointing down
//    box {
//        <-2, 0.3, -1>, <1, 0.8, 1>
//        pigment { color rgb <0.8, 0.2, 0.2> }
//        finish { ambient 0.3 diffuse 0.7 }
//    }
    // Tapered edge (wedge shape)
//    prism {
//        -1, 1, 3
//        <-2, 0.3>, <1, 0.3>, <1, 0.35>
//        pigment { color rgb <0.8, 0.2, 0.2> }
//        finish { ambient 0.3 diffuse 0.7 }
//    }
//}
// Lower magnet (South pole) - blue with flat pole piece
//union {
    // Main magnet body  
//    box {
//        <-2.5, -1.5, -1>, <1, -0.8, 1>
//       pigment { color rgb <0.2, 0.2, 0.8> }
//        finish { ambient 0.3 diffuse 0.7 }
//    }
    // Flat pole piece pointing up
//    box {
//        <-2, -0.8, -1>, <1, -0.3, 1>
//        pigment { color rgb <0.2, 0.2, 0.8> }
//        finish { ambient 0.3 diffuse 0.7 }
//    }
//}
// Magnet pole labels
//text {
///    ttf "timrom.ttf" "N" 0.1, 0
//    pigment { color White }
//    scale 0.4
//    translate <-0.5, 1.1, 0>
//}
//text {
//    ttf "timrom.ttf" "S" 0.1, 0
//    pigment { color White }
//    scale 0.4
//    translate <-0.5, -1.1, 0>
//}
// Screen - light gray
box {
    <4, -2, -2>, <4.2, 2, 2>
    pigment { color rgb <0.9, 0.9, 0.9> }
    finish { ambient 0.4 diffuse 0.6 }
}
// Screen label
text {
    ttf "timrom.ttf" "Screen" 0.1, 0
    pigment { color Black }
    scale 0.3
    rotate <0,90,0>
    translate <3.5, -1.2, -1.4>
}
// Initial atomic jet (before splitting)
cylinder {
    <-4.5, 0, 0>, <-1.5, 0, 0>, 0.05
    pigment { color rgb <0.2, 0.8, 0.2> }
    finish { ambient 0.4 diffuse 0.6 }
}
// Atomic jet label
text {
    ttf "timrom.ttf" "Atomic Ag jet" 0.1, 0
    pigment { color Black }
    scale 0.25
    translate <-4, 0.2, 0>
}
// Upper deflected beam (spin up) - green
cylinder {
    <-1.5, 0, 0>, <4, 0.8, 0>, 0.04
    pigment { color rgb <0.2, 0.8, 0.2> }
    finish { ambient 0.4 diffuse 0.6 }
}
// Lower deflected beam (spin down) - green  
cylinder {
    <-1.5, 0, 0>, <4, -0.8, 0>, 0.04
    pigment { color rgb <0.2, 0.8, 0.2> }
    finish { ambient 0.4 diffuse 0.6 }
}
// Spheres at the end of beams to show impact points
sphere {
    <4, 0.8, 0>, 0.08
    pigment { color rgb <0.2, 0.8, 0.2> }
    finish { ambient 0.4 diffuse 0.6 }
}
sphere {
    <4, -0.8, 0>, 0.08
    pigment { color rgb <0.2, 0.8, 0.2> }
    finish { ambient 0.4 diffuse 0.6 }
}
// Ground plane for reference
plane {
    y, -3
    pigment { color rgb <0.8, 0.8, 0.8> }
    finish { ambient 0.2 diffuse 0.6 }
}


// Magnet pole
union {
  prism {
    linear_spline
    0,  // Start height (y-coordinate)
    2,  // End height (y-coordinate)
    6, // Number of points, including the one to close the shape
    <-1, 0>, <-1, 1>, <0,1.5>, <1,1>, <1, 0>, <-1,0>
    pigment { color rgb <0.8, 0.2, 0.2> }
    finish { ambient 0.3 diffuse 0.7 }
    scale 0.5
    rotate <0,180,0>
  }


  prism {
    linear_spline
    0,  // Start height (y-coordinate)
    2,  // End height (y-coordinate)
    9, // Number of points, including the one to close the shape
    <-1, -0.5>, <-1, 1>, <-0.5,1>,<-0.5,0.5>,<0.5,0.5>, <0.5,1>, <1,1>, <1, -0.5>, <-1,-0.5>
    pigment { color rgb <0.2, 0.2, 0.8> }
    finish { ambient 0.3 diffuse 0.7 }
    scale 0.5
    translate <0,0,-1.3>
  }

  // Magnet pole labels
  text {
    ttf "timrom.ttf" "N" 0.1, 0
    pigment { color White }
    scale 0.4
    rotate <90,0,0>
    translate <0, 1.02, -0.5>
  }
  text {
    ttf "timrom.ttf" "S" 0.1, 0
    pigment { color White }
    scale 0.4
    rotate <90,0,0>
    translate <0, 1.02, -1.4>
  }
  rotate <-90,90,0>
  translate <-1,0.83,0>
}