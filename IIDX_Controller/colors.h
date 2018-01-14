//This is just to offload color definitions to another file so I don't need to scroll so much in the main file.

#include <Adafruit_NeoPixel.h>



//a structure for holding rainbows called rainbow:
struct rainbow {
  uint32_t colors[MAX_RAINBOW_COLORS];
  int num_colors;
};

//named color definitions:
uint32_t red = strip.Color(255, 0, 0);
uint32_t orange = strip.Color(255, 127, 0);
uint32_t yellow = strip.Color(255, 255, 0);
uint32_t yellow_green = strip.Color(127, 255, 0);
uint32_t green = strip.Color(0, 255, 0);
uint32_t green_blue = strip.Color(0, 255, 127);
uint32_t sky_blue = strip.Color(0, 255, 255);
uint32_t deep_blue = strip.Color(0, 127, 255);
uint32_t blue = strip.Color(0, 0, 255);
uint32_t purple_blue = strip.Color(127, 0, 255);
uint32_t purple = strip.Color(255, 0, 255);
uint32_t dark_purple = strip.Color(255, 0, 127);

uint32_t white = strip.Color(255,255,255);
uint32_t off = strip.Color(0, 0, 0);


/* - Default rainbow template to copy.
rainbow rXX = {
  .colors = { 
    strip.Color(), 
    strip.Color(), 
    strip.Color(), 
    strip.Color(), 
    strip.Color(), 
    strip.Color()
  },
  .num_colors = 6
};
*/

//these are the various 'rainbows' that can be swapped between for color selection on rainbow functions
//rainbow1 is the traditional roygbiv rainbow pattern
rainbow r1 = {
  .colors = {
    red,
    yellow,
    green,
    sky_blue,
    blue,
    purple
  },
  .num_colors = 6
};

//rainbow r2 is a double rainbow of r1
rainbow r2 = {
  .colors = { 
    red,
    yellow,
    green,
    sky_blue,
    blue,
    purple,
    red,
    yellow,
    green,
    sky_blue,
    blue,
    purple
  },
  .num_colors = 12
};

//the primary colors red, blue and yellow:
rainbow r3 = {
  .colors = { 
    red,
    off,
    yellow, 
    off,
    blue,
    off
  },
  .num_colors = 6
};

//the secondary colors orange, green and purple:
rainbow r4 = {
  .colors = { 
    off,
    orange,
    off,
    green, 
    off,
    purple
  },
  .num_colors = 6
};

//red green and blue
rainbow r5 = {
  .colors = { 
    off,
    red,
    off,
    green, 
    off,
    blue
  },
  .num_colors = 6
};

//blue and yellow
rainbow r6 = {
  .colors = { 
    off,
    yellow,
    off,
    blue,
    off,
    yellow,
    off,
    blue
  },
  .num_colors = 8
};

//red and sky_blue
rainbow r7 = {
  .colors = { 
    off,
    red,
    off,
    sky_blue,
    off,
    red,
    off,
    sky_blue
  },
  .num_colors = 8
};

//Orange and deep_blue
rainbow r8 = {
  .colors = { 
    off,
    orange,
    off,
    deep_blue,
    off,
    orange,
    off,
    deep_blue
  },
  .num_colors = 8
};

//some colors from color guide below:
//1
rainbow r9 = {
  .colors = { 
    strip.Color(255,255,163), 
    strip.Color(255,180,149), 
    strip.Color(214,98,168), 
    strip.Color(106,45,138), 
    strip.Color(65,42,120), 
    strip.Color(14,13,90),
    strip.Color(255,255,163), 
    strip.Color(255,180,149), 
    strip.Color(214,98,168), 
    strip.Color(106,45,138), 
    strip.Color(65,42,120), 
    strip.Color(14,13,90)
  },
  .num_colors = 12
};

//2
rainbow r10 = {
  .colors = { 
    strip.Color(127,188,255), 
    strip.Color(173,216,217), 
    strip.Color(238,243,196), 
    strip.Color(255,215,127), 
    strip.Color(255,168,112), 
    strip.Color(249,106,74),
    strip.Color(127,188,255), 
    strip.Color(173,216,217), 
    strip.Color(238,243,196), 
    strip.Color(255,215,127), 
    strip.Color(255,168,112), 
    strip.Color(249,106,74)
  },
  .num_colors = 12
};

//Flameo Hotman - 4
rainbow r11 = {
  .colors = { 
    strip.Color(204,0,102), 
    strip.Color(213,37,83), 
    strip.Color(223,74,65), 
    strip.Color(232,111,46), 
    strip.Color(241,148,28), 
    strip.Color(255,204,0),
    strip.Color(204,0,102), 
    strip.Color(213,37,83), 
    strip.Color(223,74,65), 
    strip.Color(232,111,46), 
    strip.Color(241,148,28), 
    strip.Color(255,204,0)
  },
  .num_colors = 12
};

//purplish color scheme - 15
rainbow r12 = {
  .colors = { 
    strip.Color(255,1,252), 
    strip.Color(202, 1, 255), 
    strip.Color(127,1,231), 
    strip.Color(89,18,208), 
    strip.Color(52,34,176), 
    strip.Color(44,50,135),
    strip.Color(255,1,252), 
    strip.Color(202, 1, 255), 
    strip.Color(127,1,231), 
    strip.Color(89,18,208), 
    strip.Color(52,34,176), 
    strip.Color(44,50,135)
  },
  .num_colors = 12
};

//8
rainbow r13 = {
  .colors = { 
    strip.Color(44,174,172), 
    strip.Color(15,121,107), 
    strip.Color(0,88,83), 
    strip.Color(239,31,207), 
    strip.Color(135,16,109), 
    strip.Color(89,2,82),
    strip.Color(44,174,172), 
    strip.Color(15,121,107), 
    strip.Color(0,88,83), 
    strip.Color(239,31,207), 
    strip.Color(135,16,109), 
    strip.Color(89,2,82)
  },
  .num_colors = 12
};

//19
rainbow r14 = {
  .colors = { 
    strip.Color(233,180,69), 
    strip.Color(232,211,70), 
    strip.Color(184,165,73), 
    strip.Color(114,136,74), 
    strip.Color(48,101,85), 
    strip.Color(45,55,54),
    strip.Color(233,180,69), 
    strip.Color(232,211,70), 
    strip.Color(184,165,73), 
    strip.Color(114,136,74), 
    strip.Color(48,101,85), 
    strip.Color(45,55,54)
  },
  .num_colors = 12
};

//25
rainbow r15 = {
  .colors = { 
    strip.Color(159,40,76), 
    strip.Color(144,60,75), 
    strip.Color(97,26,38), 
    strip.Color(92,31,60), 
    strip.Color(69,20,54), 
    strip.Color(36,6,29),
    strip.Color(159,40,76), 
    strip.Color(144,60,75), 
    strip.Color(97,26,38), 
    strip.Color(92,31,60), 
    strip.Color(69,20,54), 
    strip.Color(36,6,29)
  },
  .num_colors = 12
};

//33
rainbow r16 = {
  .colors = { 
    strip.Color(167,255,255), 
    strip.Color(82,136,242), 
    strip.Color(72,54,191), 
    strip.Color(33,10,64), 
    strip.Color(21,8,38), 
    strip.Color(167,255,255),
    strip.Color(82,136,242), 
    strip.Color(72,54,191), 
    strip.Color(33,10,64), 
    strip.Color(21,8,38)
  },
  .num_colors = 10
};

//37
rainbow r17 = {
  .colors = { 
    strip.Color(125,208,214), 
    strip.Color(40,162,183), 
    strip.Color(0,73,103), 
    strip.Color(191,168,212), 
    strip.Color(123,97,170), 
    strip.Color(125,208,214),
    strip.Color(40,162,183), 
    strip.Color(0,73,103), 
    strip.Color(191,168,212), 
    strip.Color(123,97,170)
  },
  .num_colors = 10
};

//60
rainbow r18 = {
  .colors = { 
    strip.Color(34,170,255), 
    strip.Color(254,253,73), 
    strip.Color(255,219,65), 
    strip.Color(255,136,0), 
    strip.Color(214,110,4),
    strip.Color(34,170,255), 
    strip.Color(254,253,73), 
    strip.Color(255,219,65), 
    strip.Color(255,136,0), 
    strip.Color(214,110,4)
  },
  .num_colors = 10
};

//64
rainbow r19 = {
  .colors = { 
    strip.Color(45,5,0), 
    strip.Color(120,0,19), 
    strip.Color(161,2,30), 
    strip.Color(217,23,109),
    strip.Color(252,246,198), 
    strip.Color(45,5,0), 
    strip.Color(120,0,19), 
    strip.Color(161,2,30), 
    strip.Color(217,23,109), 
    strip.Color(252,246,198)
  },
  .num_colors = 10
};

//65
rainbow r20 = {
  .colors = { 
    strip.Color(1,142,96), 
    strip.Color(3,182,89), 
    strip.Color(1,219,115), 
    strip.Color(7,233,175),
    strip.Color(8,240,205), 
    strip.Color(1,142,96), 
    strip.Color(3,182,89), 
    strip.Color(1,219,115), 
    strip.Color(7,233,175), 
    strip.Color(8,240,205)
  },
  .num_colors = 10
};

//75
rainbow r21 = {
  .colors = { 
    strip.Color(176,228,242), 
    strip.Color(88,199,252), 
    strip.Color(36,91,112), 
    strip.Color(79,120,0),
    strip.Color(178,254,57), 
    strip.Color(176,228,242), 
    strip.Color(88,199,252), 
    strip.Color(36,91,112), 
    strip.Color(79,120,0), 
    strip.Color(178,254,57)
  },
  .num_colors = 10
};

//80
rainbow r22 = {
  .colors = { 
    strip.Color(40,23,14), 
    strip.Color(114,21,33), 
    strip.Color(138,55,43), 
    strip.Color(184,123,63), 
    strip.Color(255,226,94), 
    strip.Color(40,23,14), 
    strip.Color(114,21,33), 
    strip.Color(138,55,43), 
    strip.Color(184,123,63), 
    strip.Color(255,226,94)
  },
  .num_colors = 10
};

//97
rainbow r23 = {
  .colors = { 
    strip.Color(189,219,83), 
    strip.Color(105,140,61), 
    strip.Color(66,100,30), 
    strip.Color(24,42,16), 
    strip.Color(3,7,0), 
    strip.Color(189,219,83),
    strip.Color(105,140,61), 
    strip.Color(66,100,30), 
    strip.Color(24,42,16), 
    strip.Color(3,7,0)
  },
  .num_colors = 10
};

//46
rainbow r24 = {
  .colors = { 
    strip.Color(82,231,163), 
    strip.Color(44,196,207), 
    strip.Color(111,200,255), 
    strip.Color(88,113,239), 
    strip.Color(169,136,215), 
    strip.Color(82,231,163), 
    strip.Color(44,196,207), 
    strip.Color(111,200,255), 
    strip.Color(88,113,239), 
    strip.Color(169,136,215)
  },
  .num_colors = 10
};

//blue and white pattern
rainbow r25 = {
  .colors = { 
    white,
    sky_blue,
    blue,
    deep_blue,
    white,
    sky_blue,
    blue,
    deep_blue
  },
  .num_colors = 8
};

//red and white pattern
rainbow r26 = {
  .colors = { 
    white,
    strip.Color(127,0,0),
    red,
    strip.Color(127,0,0),
    white,
    strip.Color(127,0,0),
    red,
    strip.Color(127,0,0)
  },
  .num_colors = 8
};

//green and white pattern
rainbow r27 = {
  .colors = { 
    white,
    strip.Color(0,127,0),
    green,
    strip.Color(0,127,0),
    white,
    strip.Color(0,127,0),
    green,
    strip.Color(0,127,0)
  },
  .num_colors = 8
};
