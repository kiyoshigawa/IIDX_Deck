/*
IIDX Controller
This code is developed for a Teense 3.1 by kiyoshigawa
It is designed to be a fully functional input device for a beatmania IIDX custom controller.
It is designed to run as a joystick, and as such this options must be selected as part of the board type.
*/

//Uncomment ENCODER_DEBUG to get serial feedback on encoder position.
//#define ENCODER_DEBUG
//Uncomment KEYPRESS_DEBUG to get feedback on key presses and releases sent
//#define KEYPRESS_DEBUG
//Uncomment LIGHTING_DEBUG to get feedback on lighting and LED programs
#define LIGHTING_DEBUG

#include <Encoder.h>
#include <Bounce.h>
#include <Adafruit_NeoPixel.h>

//defines to make the code more readable:
#define POSITIVE 1
#define STOPPED 0
#define NEGATIVE -1

#define BOTH_WIKI 0
#define P1_WIKI 1
#define P2_WIKI 2

#define LEFT 0
#define RIGHT 1

//this is the most numbers a 'rainbow' can have for fades and color selection.
#define MAX_RAINBOW_COLORS 29
#define MAX_NUM_RAINBOWS 50

//set this to a number of milliseconds to wait for a serial connection before continuing with normal setep.
#define SERIAL_WAIT_TIMEOUT 10000

//defines how long to display the rwinbow that was switched to when changing rainbows in various modes before returning to normal operation.
#define RAINBOW_DISPLAY_TIME 300

//number of steps in an encoder revolution. Designed using 600 pips/revolutiuon quadrature encoders, so default is 2400.
//turns out it's skipping pips a fair amount around the rotation, so I just made it go faster than the rotation because I like the look of it.
#define PIPS_PER_REV 1500

//number of ms to ignore changes in button state after a change
#define BOUNCE_TIME 5

//number of bounce objects to iterate through
#define NUM_BUTTONS 18

//number of LED pixels total - half per disk.
#define NUM_LEDS 58

//this is the minimum number of steps before the motion of the encoders registers. Decrease to make the wheel more sensitive, increase to make the wheel less sensitive. If this number is too low, the wheel may register hits when it is not being moved.
#define STEP_THRESHOLD 20

//this is the number of miliseconds from the last movement that will register as still pressing a key for scrolling purposes. If the wheel does not move for MOVE_TIMEOUT ms, it will stop pressing up or down. If the wheel changes direction before MOVE_TIMEOUT, it will still send the alternate direction as soon as the change is detected.
#define MOVE_TIMEOUT 100

//this is how often the lighting can update when being animated.
#define LIGHTING_REFRESH_DELAY 15

//Variables for the number of frames per animation. The lighting runs at approximately 60fps with LIGHTING_REFRESH_DELAY set to 15.
#define LM_SLOW_FADE_FRAMES 100
#define LM_MARQUEE_FADE_FRAMES 150
#define LM_SLOW_ROTATE_FRAMES 300
#define LM_COLOR_PULSE_FRAMES 30

//this is how many frames before the marquee jumps to the next 'node'
#define LM_MARQUEE_FRAMES 15

//this scaling factor allows for smoother transitions around the edges on slow_rotate style animations. The integer math rounding makes abrupt changes otherwise
#define LM_SLOW_ROTATE_SCALING_FACTOR 30000

//a couple defines for marquee automatic generation
#define LM_NUM_ON 1
#define LM_NUM_OFF 4
#define LM_NUM_ITERATIONS 5

//this determines color pulse speed
#define LM_DEGREES_PER_FRAME 15

//Default position for pulses in degrees. They will always count down to 0 (top of the wheel) from here.
#define LM_DEFAULT_PULSE_POSITION 180

//the most active color pulses that can be up at any given time. 
//Currently set to NUM_LEDS, allowing for ~1 color per LED at max refresh speed. The colors will all be smooth-faded around the LEDs regardless.
#define MAX_COLOR_PULSES NUM_LEDS


//lighting mode definitions: Pressing the corresponding button will switch to that mode when in lighting control mode

//the 4 white p1 buttons:
//Solid lighting in a single color. 
#define LM_SOLID 1
//slow_fade - will slowly cycle through solid rainbow colors on both wheels.
#define LM_SLOW_FADE 3
//marquee - will make a repeating on/off pattern that rotates around at fixed time intervals - Direciton changes to match disk last spin direction.
#define LM_MARQUEE 5
//marquee slow_fade - same as marquee, but colors will fade through rainbow over time.
#define LM_MARQUEE_SLOW_FADE 7

//the 3 blue p1 buttons:
//wiki-follower - single color lights will alternate every other LED on the wheel and follow the movement of the wheels.
#define LM_WIKI 2
//slow-fade wiki-follower - slowly transitioning colored lights will alternate every other LED on the wheel and follow the movement of the wheels.
#define LM_WIKI_SLOW_FADE 4
//wiki_rainbow - multi-color rainbow pattern will follow the wiki wheel
#define LM_WIKI_RAINBOW 6

//the 4 white p2 buttons:
//slow_rotate - a rainbow pattern will slowly rotate around the disks
#define LM_SLOW_ROTATE 10
//random_rainbow - this jumps the rainbow to a random position whenever a button is pressed.
#define LM_RANDOM_RAINBOW 12
//Random_Color - this will pick a random rainbow color and set the whole side to it on a button press.
#define LM_RANDOM_COLOR 14
//Off - this will turn off all wiki lighting, but still allow for button lighting if the power is plugged in.
#define LM_OFF 16

//the 3 blue p2 buttons:
//Color Pulse - set off a pulse of color that will rotate around the disk on one a side when a button is pressed on that side
#define LM_COLOR_PULSE 11
//Color Pulse Slow Fade- same as above, but the overall color will slowly fade
#define LM_COLOR_PULSE_SLOW_FADE 13
//Color Pulse Rainbow - same as Color_pulse, but each color is a new color from the rainbow
#define LM_COLOR_PULSE_RAINBOW 15

//rainbow_up - this increments the rainbow to the next rainbow in the array in a negative direction
#define LM_RAINBOW_DOWN 8
//rainbow_up - this increments the rainbow to the next rainbow in the array in a positive direction
#define LM_RAINBOW_UP 9
//number 17 will send the enter key press signal only when in lighting control mode
#define LM_ENTER_KEY 17
//number 18 will send windows-key+5, which should open the LR2 settings window. Then you can press key 17 to start LR2.
#define LM_WIN_5_KEY 18

//the default mode is set here - it must be one of the above lighting modes
#define LM_DEFAULT LM_SLOW_ROTATE

//array of button pins
int p1_buttons[] = {10, 11, 12, 0, 18, 14, 15, 16, 17};
int p2_buttons[] = {1, 2, 3, 4, 5, 6, 7, 8, 9};

//pin definitions for non-button stuff
int lighting_control_pin = 13;
int lighting_mode_pin = 19;

//if encoders are running backwards, swap pin a and b.
int left_knob_pin_a = 21;
int left_knob_pin_b = 20;
int right_knob_pin_a = 23;
int right_knob_pin_b = 22;

//init bounce objects for all buttons;
Bounce p1_b1 = Bounce(p1_buttons[0], BOUNCE_TIME);
Bounce p1_b2 = Bounce(p1_buttons[1], BOUNCE_TIME);
Bounce p1_b3 = Bounce(p1_buttons[2], BOUNCE_TIME);
Bounce p1_b4 = Bounce(p1_buttons[3], BOUNCE_TIME);
Bounce p1_b5 = Bounce(p1_buttons[4], BOUNCE_TIME);
Bounce p1_b6 = Bounce(p1_buttons[5], BOUNCE_TIME);
Bounce p1_b7 = Bounce(p1_buttons[6], BOUNCE_TIME);
Bounce p1_bst = Bounce(p1_buttons[7], BOUNCE_TIME);
Bounce p1_bse = Bounce(p1_buttons[8], BOUNCE_TIME);

Bounce p2_b1 = Bounce(p2_buttons[0], BOUNCE_TIME);
Bounce p2_b2 = Bounce(p2_buttons[1], BOUNCE_TIME);
Bounce p2_b3 = Bounce(p2_buttons[2], BOUNCE_TIME);
Bounce p2_b4 = Bounce(p2_buttons[3], BOUNCE_TIME);
Bounce p2_b5 = Bounce(p2_buttons[4], BOUNCE_TIME);
Bounce p2_b6 = Bounce(p2_buttons[5], BOUNCE_TIME);
Bounce p2_b7 = Bounce(p2_buttons[6], BOUNCE_TIME);
Bounce p2_bst = Bounce(p2_buttons[7], BOUNCE_TIME);
Bounce p2_bse = Bounce(p2_buttons[8], BOUNCE_TIME);

Bounce lighting_mode_button = Bounce(lighting_mode_pin, BOUNCE_TIME);

//array of bounce objects to iterate through
Bounce button_array[] = {p1_b1, p1_b2, p1_b3, p1_b4, p1_b5, p1_b6, p1_b7, p1_bst, p1_bse, p2_b1, p2_b2, p2_b3, p2_b4, p2_b5, p2_b6, p2_b7, p2_bst, p2_bse};

//init encoder objects
Encoder knobLeft(left_knob_pin_a, left_knob_pin_b);
Encoder knobRight(right_knob_pin_a, right_knob_pin_b);

//NeoPixel Object
Adafruit_NeoPixel strip = Adafruit_NeoPixel(58, lighting_control_pin, NEO_GRB + NEO_KHZ800);

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

uint32_t off = strip.Color(0, 0, 0);

//a structure for holding rainbows called rainbow:
struct rainbow {
  uint32_t colors[MAX_RAINBOW_COLORS];
  int num_colors;
};

//a structure for holding color pulses for the color_pulse line of lighting animations
struct cp {
  //color of the pulse
  uint32_t color;
  //position from 0-180 degrees, 0 being top, 180 being bottom
  int position;
  //can be either P1_WIKI, or P2_WIKI
  int player;
  //can be either LEFT or RIGHT
  int side;
};

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

//purplish color scheme
rainbow r9 = {
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
//red and orange and yellow color scheme
rainbow r10 = {
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

//initialize one rainbows array to hold all the rainbows:
rainbow rainbows[MAX_NUM_RAINBOWS] = {r1, r2, r3, r4, r5, r6, r7, r8, r9, r10};
int num_rainbows = 10;
int current_rainbow = 1;

//Initialize the rainbow array to be the same size as the other arrays above. It will be set in the setup function and adjusted in the remaining program.
uint32_t rainbow[MAX_RAINBOW_COLORS];
int num_rainbow_colors = MAX_RAINBOW_COLORS;

uint32_t marquee[(LM_NUM_ON+LM_NUM_OFF)*LM_NUM_ITERATIONS];
int num_marquee_positions = (LM_NUM_ON+LM_NUM_OFF)*LM_NUM_ITERATIONS;

//a color correction table for the neopixel color settings:
const uint8_t PROGMEM gamma8[] = {
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  1,  1,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  2,  2,
  2,  3,  3,  3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,
  5,  6,  6,  6,  6,  7,  7,  7,  7,  8,  8,  8,  9,  9,  9, 10,
  10, 10, 11, 11, 11, 12, 12, 13, 13, 13, 14, 14, 15, 15, 16, 16,
  17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 24, 24, 25,
  25, 26, 27, 27, 28, 29, 29, 30, 31, 32, 32, 33, 34, 35, 35, 36,
  37, 38, 39, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 50,
  51, 52, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 66, 67, 68,
  69, 70, 72, 73, 74, 75, 77, 78, 79, 81, 82, 83, 85, 86, 87, 89,
  90, 92, 93, 95, 96, 98, 99,101,102,104,105,107,109,110,112,114,
  115,117,119,120,122,124,126,127,129,131,133,135,137,138,140,142,
  144,146,148,150,152,154,156,158,160,162,164,167,169,171,173,175,
  177,180,182,184,186,189,191,193,196,198,200,203,205,208,210,213,
  215,218,220,223,225,228,231,233,236,239,241,244,247,249,252,255 
};

//this is a variable for avoiding setting colors to be off based on the start of this table being mostly off. 
//It's still pretty rough near the low end with 8-bit colors. Not much I can do about it currently.
#define FIRST_NON_OFF_COLOR 28

//a new wrapper function to replace the strip.Color I have used previously. Still takes the same arguments and then calls the normal function with the table above as a reference.
void strip_setPixelColor(int led, uint32_t color){
  uint8_t red = (uint8_t)(color >> 16);
  uint8_t green = (uint8_t)(color >> 8);
  uint8_t blue = (uint8_t)(color);
  strip.setPixelColor(led, pgm_read_byte(&gamma8[red]), pgm_read_byte(&gamma8[green]), pgm_read_byte(&gamma8[blue]));
}

//global variables used below
long position_left  = 0;
long position_right = 0;
int direction_left = STOPPED;
int direction_right = STOPPED;
unsigned long last_left_move_time = 0;
unsigned long last_right_move_time = 0;
bool left_encoder_has_stopped = true;
bool right_encoder_has_stopped = true;
//variables to keep track of direction of travel for differing disks in animations like directional marquee
int last_p1_direction = POSITIVE;
int last_p2_direction = POSITIVE;

//global lighting mode variables:
//default lighting_mode when starting up.
int lighting_mode = LM_DEFAULT;
//previous lighting mode variable to make it possible to mod settings without changing modes
int previous_lighting_mode = LM_DEFAULT;
//this is a flag to let the switch function know if it should reset a lighting mode.
int lm_has_changed = true;
//this is for color modes that cycle through colors
int lm_current_color = num_rainbow_colors;
//time variable for limiting lighting refresh rate:
unsigned long last_lighting_update = 0;
//int to keep track of state of fades and rotations
int lm_current_transition_position = 0;
int lm_current_transition_position_2 = 0;
int lm_current_marquee_color_position = 0;
//variables for lighting effects that fire when buttons are pressed during gameplay
bool lm_p1_button_has_been_pressed = false;
bool lm_p2_button_has_been_pressed = false;
//Variables for use with an array of color pulse structures to be used by the LED_color_pulse() function for setting light outputs.
cp pulse_array[MAX_COLOR_PULSES];
int lm_num_active_pulses = 0;
int last_p1_pulse_side = LEFT;
int last_p2_pulse_side = RIGHT;

void setup() {
  Serial.begin(9600);
  while(!Serial){
    if(millis() > SERIAL_WAIT_TIMEOUT){
      break;
    }
  }
  #ifdef ENCODER_DEBUG
    Serial.println("Two Knobs Encoder Test:");
  #endif
  #ifdef KEYPRESS_DEBUG
    Serial.println("Keypress Testing:");
  #endif
  #ifdef LIGHTING_DEBUG
    Serial.println("Lighting Testing:");
  #endif

  //num_buttons over 2 because I have 2 button arrays and each player has half the buttons
  for(int i=0; i<(NUM_BUTTONS/2); i++){
    pinMode(p1_buttons[i], INPUT_PULLUP);
    pinMode(p2_buttons[i], INPUT_PULLUP);
  }

  pinMode(lighting_mode_pin, INPUT);
  pinMode(lighting_control_pin, OUTPUT);
  
  //disable other joystick functions
  Joystick.X(512);
  Joystick.Y(512);
  Joystick.Z(512);
  Joystick.Zrotate(512);
  Joystick.sliderLeft(512);
  Joystick.sliderRight(512);

  //initialize the rainbow array:
  set_rainbow(current_rainbow);

  //LED Strip Setup
  strip.begin();
  //initialize with the default lighting parameters:
  lm_switch();
  populate_marquee(rainbow[lm_current_color]);
}

void loop() {
  if(digitalRead(lighting_mode_pin) == HIGH){
    //Lighting Select Mode is Active - button presses will change lighting control mode
    //normal controller functions are disabled when in lighting control mode
    update_buttons_LM_select();
    lm_switch();
    lighting_control();
  }
  else{
    //normal controller operation - keypresses send joystick commands via USB, lighting control runs based on mode last selected.
    update_encoders();
    update_buttons();
    encoder_key_press();
    lighting_control();
  }
}

//check state of buttons for change (bounced) and update joystick status based on this.
void update_buttons(){
  for(int i=0; i<NUM_BUTTONS; i++){
    //check for updates on each button
    if(button_array[i].update()){
      //if the button was released set it to 0
      if(button_array[i].risingEdge()){
        Joystick.button(i+1, 0); //+1 because joystick buttons are from 1-32, not 0-31.
        #ifdef KEYPRESS_DEBUG
          Serial.print("Released ");
          Serial.println(i+1);
        #endif
      }
      //otherwise set it to pressed
      else if(button_array[i].fallingEdge()){
        Joystick.button(i+1, 1); //+1 because joystick buttons are from 1-32, not 0-31.
        //these variables are for lighting functions. Make sure to reset them in the lighting mode functions once something has been triggered.
        if(i <= 8){
          lm_p1_button_has_been_pressed = true;
        }
        else if(i >= 9){
          lm_p2_button_has_been_pressed = true;
        }
        #ifdef KEYPRESS_DEBUG
          Serial.print("Pressed ");
          Serial.println(i+1);
        #endif
      }
    }
  }
}

//this will use the timing from the update_encoders() function to determine if the joystick should be pressed up, down, or not at all. Note that the joystick mapped buttons for up and down will be NUM_BUTTONS + 1, 2, 3, or 4, as the first NUM_BUTTONS buttons will be used by the keys, start, and select buttons.
void encoder_key_press(){
  if(direction_left == POSITIVE){
    //press left up button and release left down button
    Joystick.button(NUM_BUTTONS+1, 1);
    Joystick.button(NUM_BUTTONS+2, 0);
  }
  else if(direction_left == NEGATIVE){
    //press left down button and release left up button
    Joystick.button(NUM_BUTTONS+1, 0);
    Joystick.button(NUM_BUTTONS+2, 1);
  }
  else if(direction_left == STOPPED){
    //release both left up and left down buttons
    Joystick.button(NUM_BUTTONS+1, 0);
    Joystick.button(NUM_BUTTONS+2, 0);
    if(left_encoder_has_stopped == false){
      position_left = knobLeft.read();
      #ifdef ENCODER_DEBUG
        Serial.print("Stopped at: ");
      #endif
      print_encoder_position();
      left_encoder_has_stopped = true;
    }
  }
  if(direction_right == POSITIVE){
    //press left up button and release left down button
    Joystick.button(NUM_BUTTONS+3, 1);
    Joystick.button(NUM_BUTTONS+4, 0);
  }
  else if(direction_right == NEGATIVE){
    //press left down button and release left up button
    Joystick.button(NUM_BUTTONS+3, 0);
    Joystick.button(NUM_BUTTONS+4, 1);
  }
  else if(direction_right == STOPPED){
    //release both left up and left down buttons
    Joystick.button(NUM_BUTTONS+3, 0);
    Joystick.button(NUM_BUTTONS+4, 0);
    if(right_encoder_has_stopped == false){
      position_right = knobRight.read();
      #ifdef ENCODER_DEBUG
        Serial.print("Stopped at: ");
      #endif
      print_encoder_position();
      right_encoder_has_stopped = true;
    }
  }
}

//this will update the time variables showing when the encoders last changed position.
void update_encoders(){
  long new_left, new_right;
  unsigned long current_time = millis();
  new_left = knobLeft.read();
  new_right = knobRight.read();
  
  //if going positive direction
  if (new_left > (position_left+STEP_THRESHOLD) ) {
    position_left = new_left;
	  direction_left = POSITIVE;
	  last_left_move_time = current_time;
    left_encoder_has_stopped = false;
    print_encoder_position();
  }
  //if going negative direction
  else if (new_left < (position_left-STEP_THRESHOLD) ) {
    position_left = new_left;
    direction_left = NEGATIVE;
    last_left_move_time = current_time;
    left_encoder_has_stopped = false;
    print_encoder_position();
  }
  //if it has not changed position since MOVE_TIMEOUT, stop sending either up or down
  else if ((current_time - last_left_move_time) > MOVE_TIMEOUT){
    direction_left = STOPPED;
  }
  
  //if going positive direction
  if (new_right > (position_right+STEP_THRESHOLD) ) {
    position_right = new_right;
    direction_right = POSITIVE;
    last_right_move_time = current_time;
    right_encoder_has_stopped = false;
    print_encoder_position();
  }
  //if going negative direction
  else if (new_right < (position_right-STEP_THRESHOLD) ) {
    position_right = new_right;
    direction_right = NEGATIVE;
    last_right_move_time = current_time;
    right_encoder_has_stopped = false;
    print_encoder_position();
  }
  //if it has not changed position since MOVE_TIMEOUT, stop sending either up or down
  else if ((current_time - last_right_move_time) > MOVE_TIMEOUT){
    direction_right = STOPPED;
  }
	
  // if the value approaches the max, gracefully reset values to 0.
  if (abs(position_left) > 2000000000 || abs(position_right) > 2000000000) {
    knobLeft.write(0);
    position_left = 0;
    knobRight.write(0);
    position_right = 0;
  }

}

void print_encoder_position(){
	#ifdef ENCODER_DEBUG  
    Serial.print("Left = ");
    Serial.print(position_left);
    Serial.print(", Right = ");
    Serial.print(position_right);
    Serial.println();
  #endif
}

//lighting functions below:

void update_buttons_LM_select(){
  for(int i=0; i<NUM_BUTTONS; i++){
    //check for updates on each button
    if(button_array[i].update()){
      if(button_array[i].fallingEdge()){
        previous_lighting_mode = lighting_mode;
        lighting_mode = i+1;
        #ifdef LIGHTING_DEBUG
          Serial.print("Pressed button and set lighting mode to: ");
          Serial.println(lighting_mode);
        #endif
        lm_has_changed = true;
      }
    }
  }
}

//this is the setup function for lighting. It runs when the control mode button is pressed.
//it will set the default state of any mode when the appropriate button is pressed.
void lm_switch(){
  //still want to have encoders update so effects that use them can be tested while in lighting mode.
  update_encoders();
  //this deals with what happens when buttons are pressed. The cases are defined at the top in the #defines section
  if(lm_has_changed){
    switch(lighting_mode){
      case LM_SOLID:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Solid.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          //finally, set the color here. There is no need for further input in this mode during the main loop function.
          LED_single_color(rainbow[lm_current_color], BOTH_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_SLOW_FADE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Slow-Fade.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //simply set the color to a single current color. All other work occurs in the main loop.
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          //reset the transition step variable to 0 so it will start from the new color:
          lm_current_transition_position = 0;
          //finally, set the color here. There is no need for further input in this mode during the main loop function.
          LED_single_color(rainbow[lm_current_color], BOTH_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_MARQUEE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Marquee.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          //reset the transition step variable to 0 so it will start from the new color:
          populate_marquee(rainbow[lm_current_color]);
          lm_current_transition_position = 0;
          //finally, set the color here. There is no need for further input in this mode during the main loop function.
          LED_marquee(lm_current_transition_position, BOTH_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_MARQUEE_SLOW_FADE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Slow Fading Marquee.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          //reset the transition step variable to 0 so it will start from the new color:
          populate_marquee(rainbow[lm_current_color]);
          lm_current_transition_position = 0;
          //reset color transition to 0.
          lm_current_marquee_color_position = 0;
          //finally, set the color here. There is no need for further input in this mode during the main loop function.
          LED_marquee(lm_current_transition_position, BOTH_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_WIKI:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Wiki.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          //reset the transition step variable to 0 so it will start from the new color:
          populate_marquee(rainbow[lm_current_color]);
          //first map the wiki position to the frame offset of a typical slow rotate (p1_inverted_due_to_hardware)
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
          //then set the wheel to the rainbow color at that offset
          LED_marquee(p1_offset, P1_WIKI);
          LED_marquee(p2_offset, P2_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_WIKI_SLOW_FADE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now slow fading Wiki.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          //reset the transition step variable to 0 so it will start from the new color:
          populate_marquee(rainbow[lm_current_color]);
          //first map the wiki position to the frame offset of a typical slow rotate
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
          //reset color transition to 0.
          lm_current_marquee_color_position = 0;
          //then set the wheel to the rainbow color at that offset
          LED_marquee(p1_offset, P1_WIKI);
          LED_marquee(p2_offset, P2_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_WIKI_RAINBOW:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Wiki-Rainbow.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //first map the wiki position to the frame offset of a typical slow rotate
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
          //then set the wheel to the rainbow color at that offset
          LED_rainbow(p1_offset, P1_WIKI);
          LED_rainbow(p2_offset, P2_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_SLOW_ROTATE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Slow-Rotate.");
          #endif
          //reset the transition step variable to 0 so it will start from the new color:
          lm_current_transition_position = 0;
          lm_current_transition_position_2 = 0;
          LED_rainbow(lm_current_transition_position, P1_WIKI);
          LED_rainbow(lm_current_transition_position_2, P2_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_RANDOM_RAINBOW:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Random Rainbow.");
          #endif
          //reset the transition step variable to 0 so it will start from the new color:
          lm_current_transition_position = random(LM_SLOW_ROTATE_FRAMES);
          lm_current_transition_position_2 = random(LM_SLOW_ROTATE_FRAMES);
          LED_rainbow(lm_current_transition_position, P1_WIKI);
          LED_rainbow(lm_current_transition_position_2, P2_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_RANDOM_COLOR:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Random Color.");
          #endif
          //reset the transition step variable to 0 so it will start from the new color:
          int last_position = lm_current_transition_position;
          int last_position_2 = lm_current_transition_position_2;
          while(rainbow[last_position] == rainbow[lm_current_transition_position] || rainbow[lm_current_transition_position] == off){
            lm_current_transition_position = random(num_rainbow_colors);
          }
          while(rainbow[last_position_2] == rainbow[lm_current_transition_position_2] || rainbow[lm_current_transition_position_2] == off){
            lm_current_transition_position_2 = random(num_rainbow_colors);
          }
          LED_single_color(rainbow[lm_current_transition_position], P1_WIKI);
          LED_single_color(rainbow[lm_current_transition_position_2], P2_WIKI);
          lm_has_changed = false;
        }
        break;

      case LM_COLOR_PULSE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Color-Pulse.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          
          cp test_fire{
            .color = rainbow[lm_current_color],
            //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
            .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
            .player = P1_WIKI,
            .side = RIGHT
          };
          //fire a test pulse with the color change:
          LED_add_color_pulse(test_fire);

          lm_has_changed = false;
        }
        break;

      case LM_COLOR_PULSE_SLOW_FADE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now slow-fade Color-Pulse.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          
          cp test_fire{
            .color = rainbow[lm_current_color],
            //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
            .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
            .player = P1_WIKI,
            .side = RIGHT
          };
          //fire a test pulse with the color change:
          LED_add_color_pulse(test_fire);

          lm_has_changed = false;
        }
        break;

      case LM_COLOR_PULSE_RAINBOW:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Rainbow Color-Pulse.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          //increment the color every time a button is pressed.
          lm_current_color++;
          //if the color is larger than there are colors, reset it.
          if(lm_current_color >= num_rainbow_colors){
            lm_current_color = 0;
          }
          //skip the color if it is 'off' for this mode.
          while(rainbow[lm_current_color] == off){
            lm_current_color++;
            //loop back to the start as required.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
          
          cp test_fire{
            .color = rainbow[lm_current_color],
            //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
            .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
            .player = P1_WIKI,
            .side = RIGHT
          };
          //fire a test pulse with the color change:
          LED_add_color_pulse(test_fire);

          lm_has_changed = false;
        }
        break;

      /* This is a dummy bracket for adding new modes as needed.
      case LM_INSERT_NEW_NAME_HERE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now <New Name Here>.");
          #endif
          //change variables as needed for the default state of this lighting mode:

          lm_has_changed = false;
        }
        break;
        */

      case LM_RAINBOW_UP:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now RAINBOW_UP.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          current_rainbow++;
          if(current_rainbow >= num_rainbows){
            current_rainbow = 0;
          }
          set_rainbow(current_rainbow);
          
          //go back to the old lighting mode
          lighting_mode = previous_lighting_mode;
          lm_has_changed = true;
        }
        break;

      case LM_RAINBOW_DOWN:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now RAINBOW_DOWN.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          current_rainbow--;
          if(current_rainbow < 0){
            current_rainbow = num_rainbows-1;
          }
          set_rainbow(current_rainbow);

          //go back to the old lighting mode
          lighting_mode = previous_lighting_mode;
          lm_has_changed = true;
        }
        break;

      case LM_OFF:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now off.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          LED_single_color(off, BOTH_WIKI);
          lm_has_changed = false;
        }
        break;
      case LM_ENTER_KEY:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Sending enter key press");
          #endif
          //this mode just presses the enter key on the teensy's USB keyboard driver.
          Keyboard.press(KEY_ENTER);
          Keyboard.release(KEY_ENTER);

          //go back to the old lighting mode
          lighting_mode = previous_lighting_mode;
          lm_has_changed = false;
        }
        break;
      case LM_WIN_5_KEY:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Sending windows+5 key press");
          #endif
          //this mode just presses the enter key on the teensy's USB keyboard driver.
          Keyboard.press(MODIFIERKEY_GUI);
          Keyboard.press(KEY_5);
          Keyboard.release(MODIFIERKEY_GUI);
          Keyboard.release(KEY_5);

          //go back to the old lighting mode
          lighting_mode = previous_lighting_mode;
          lm_has_changed = false;
        }
        break;

      default:
        {
          lighting_mode = LM_DEFAULT;
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now the default.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          
          //do not set lm_has_changed to false, as it should go through the default option's setup above.
        }
        break;
    }
  } 
}

//this function runs the lighting updates during normal operation mode.
//some lighting modes are constant, and do not require any action in this function
//it is limited to run once every LIGHTING_REFRESH_DELAY to keep from interfering with the gameplay
void lighting_control(){
  unsigned long current_time = millis();
  if((current_time - last_lighting_update) > LIGHTING_REFRESH_DELAY){
    //reset the lighting refresh timer:
    last_lighting_update = current_time;
    #ifdef LIGHTING_DEBUG
      //uncomment if needed, otherwise really annoying
      //Serial.println("Light_Update!");
    #endif
    //Depending on mode, call a specific function for controlling the lighting.
    switch(lighting_mode){
      case LM_SOLID:
        {
          //set the color every time anyways, in case the lighting power was interrupted.
          LED_single_color(rainbow[lm_current_color], BOTH_WIKI);
        }
        break;

      case LM_SLOW_FADE:
        {
          //set the color to a step between the current color and the next in the loop, based on how far along the LM_SLOW_FADE_FRAMES position.
          //set variable for mapping
          uint32_t current_color = rainbow[lm_current_color];
          uint32_t next_color = 0;
          if(lm_current_color >= (num_rainbow_colors-1)){
            next_color = rainbow[0];
          }
          else{
            next_color = rainbow[lm_current_color+1];
          }
          //assign the colors based on the above.
          uint32_t current_red = (uint8_t)(current_color >> 16);
          uint32_t current_green = (uint8_t)(current_color >> 8);
          uint32_t current_blue = (uint8_t)(current_color);
          uint32_t next_red = (uint8_t)(next_color >> 16);
          uint32_t next_green = (uint8_t)(next_color >> 8);
          uint32_t next_blue = (uint8_t)(next_color);
          //do the map thing to get the color between the two based on LM_SLOW_FADE_FRAMES
          uint32_t mid_red = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_red, next_red);
          uint32_t mid_green = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_green, next_green);
          uint32_t mid_blue = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_blue, next_blue);
          //check to see if the mid color is 'off' and increment until it is no longer off.
          while(is_gc_color_off(strip.Color(mid_red, mid_green, mid_blue))){
            //increment frames, jump to the next color if rollover occurs:
            lm_current_transition_position++;
            if(lm_current_transition_position >= LM_SLOW_FADE_FRAMES){
              lm_current_transition_position = 0;
              lm_current_color++;
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            current_color = rainbow[lm_current_color];
            if(lm_current_color >= (num_rainbow_colors-1)){
              next_color = rainbow[0];
            }
            else{
              next_color = rainbow[lm_current_color+1];
            }
            current_red = (uint8_t)(current_color >> 16);
            current_green = (uint8_t)(current_color >> 8);
            current_blue = (uint8_t)(current_color);
            next_red = (uint8_t)(next_color >> 16);
            next_green = (uint8_t)(next_color >> 8);
            next_blue = (uint8_t)(next_color);
            //do the map thing to get the color between the two based on LM_SLOW_FADE_FRAMES
            mid_red = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_red, next_red);
            mid_green = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_green, next_green);
            mid_blue = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_blue, next_blue);
                        
          }
          //set the color:
          LED_single_color(strip.Color(mid_red, mid_green, mid_blue), BOTH_WIKI);
          #ifdef LIGHTING_DEBUG
            /* only uncomment if needed. Too spammy.
            Serial.print("Red: ");
            Serial.println(mid_red);
            Serial.print("Green: ");
            Serial.println(mid_green);
            Serial.print("Blue: ");
            Serial.println(mid_blue);
            */
          #endif
          //increment frames, jump to the next color if rollover occurs:
          lm_current_transition_position++;
          if(lm_current_transition_position >= LM_SLOW_FADE_FRAMES){
            lm_current_transition_position = 0;
            lm_current_color++;
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
        }
        break;

      case LM_MARQUEE:
        {
          //set p1 directions
          if(direction_left == POSITIVE){
            last_p1_direction = NEGATIVE;
          }
          else if(direction_left == NEGATIVE){
            last_p1_direction = POSITIVE;
          }
          //increment in the correct direction. Will continue even if the disk stops.
          if(last_p1_direction == POSITIVE){
            lm_current_transition_position++;
            LED_marquee(lm_current_transition_position, P1_WIKI);
            if(lm_current_transition_position >= LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position = 0;
            }
          }
          else if(last_p1_direction == NEGATIVE){
            lm_current_transition_position--;
            LED_marquee(lm_current_transition_position, P1_WIKI);
            if(lm_current_transition_position <= -LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position = 0;
            }
          }
          //set p2 directions
          if(direction_right == POSITIVE){
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE){
            last_p2_direction = NEGATIVE;
          }
          //increment in the correct direction. Will continue even if the disk stops.
          if(last_p2_direction == POSITIVE){
            lm_current_transition_position_2++;
            LED_marquee(lm_current_transition_position_2, P2_WIKI);
            if(lm_current_transition_position_2 >= LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position_2 = 0;
            }
          }
          else if(last_p2_direction == NEGATIVE){
            lm_current_transition_position_2--;
            LED_marquee(lm_current_transition_position_2, P2_WIKI);
            if(lm_current_transition_position_2 <= -LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position_2 = 0;
            }
          }
        }
        break;

      case LM_MARQUEE_SLOW_FADE:
        {
          //update colors first:
          //set the color to a step between the current color and the next in the loop, based on how far along the LM_MARQUEE_FADE_FRAMES position.
          //set variable for mapping
          uint32_t current_color = rainbow[lm_current_color];
          uint32_t next_color = 0;
          if(lm_current_color >= (num_rainbow_colors-1)){
            next_color = rainbow[0];
          }
          else{
            next_color = rainbow[lm_current_color+1];
          }
          //assign the colors based on the above.
          uint32_t current_red = (uint8_t)(current_color >> 16);
          uint32_t current_green = (uint8_t)(current_color >> 8);
          uint32_t current_blue = (uint8_t)(current_color);
          uint32_t next_red = (uint8_t)(next_color >> 16);
          uint32_t next_green = (uint8_t)(next_color >> 8);
          uint32_t next_blue = (uint8_t)(next_color);
          //do the map thing to get the color between the two based on LM_MARQUEE_FADE_FRAMES
          uint32_t mid_red = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_red, next_red);
          uint32_t mid_green = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_green, next_green);
          uint32_t mid_blue = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_blue, next_blue);
          //check to see if the mid color is 'off' and increment until it is no longer off.
          while(is_gc_color_off(strip.Color(mid_red, mid_green, mid_blue))){
            //increment frames, jump to the next color if rollover occurs:
            lm_current_marquee_color_position++;
            if(lm_current_marquee_color_position >= LM_MARQUEE_FADE_FRAMES){
              lm_current_marquee_color_position = 0;
              lm_current_color++;
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            current_color = rainbow[lm_current_color];
            if(lm_current_color >= (num_rainbow_colors-1)){
              next_color = rainbow[0];
            }
            else{
              next_color = rainbow[lm_current_color+1];
            }
            current_red = (uint8_t)(current_color >> 16);
            current_green = (uint8_t)(current_color >> 8);
            current_blue = (uint8_t)(current_color);
            next_red = (uint8_t)(next_color >> 16);
            next_green = (uint8_t)(next_color >> 8);
            next_blue = (uint8_t)(next_color);
            //do the map thing to get the color between the two based on LM_MARQUEE_FADE_FRAMES
            mid_red = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_red, next_red);
            mid_green = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_green, next_green);
            mid_blue = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_blue, next_blue);
                        
          }

          //set the marquee to the right color:
          populate_marquee(strip.Color(mid_red, mid_green, mid_blue));

          //set p1 directions - inverted due to hardware for p1
          if(direction_left == POSITIVE){
            last_p1_direction = NEGATIVE;
          }
          else if(direction_left == NEGATIVE){
            last_p1_direction = POSITIVE;
          }
          //increment in the correct direction. Will continue even if the disk stops.
          if(last_p1_direction == POSITIVE){
            lm_current_transition_position++;
            LED_marquee(lm_current_transition_position, P1_WIKI);
            if(lm_current_transition_position >= LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position = 0;
            }
          }
          else if(last_p1_direction == NEGATIVE){
            lm_current_transition_position--;
            LED_marquee(lm_current_transition_position, P1_WIKI);
            if(lm_current_transition_position <= -LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position = 0;
            }
          }
          //set p2 directions
          if(direction_right == POSITIVE){
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE){
            last_p2_direction = NEGATIVE;
          }
          //increment in the correct direction. Will continue even if the disk stops.
          if(last_p2_direction == POSITIVE){
            lm_current_transition_position_2++;
            LED_marquee(lm_current_transition_position_2, P2_WIKI);
            if(lm_current_transition_position_2 >= LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position_2 = 0;
            }
          }
          else if(last_p2_direction == NEGATIVE){
            lm_current_transition_position_2--;
            LED_marquee(lm_current_transition_position_2, P2_WIKI);
            if(lm_current_transition_position_2 <= -LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position_2 = 0;
            }
          }

          //increment frames, jump to the next color if rollover occurs:
          lm_current_marquee_color_position++;
          if(lm_current_marquee_color_position >= LM_MARQUEE_FADE_FRAMES){
            lm_current_marquee_color_position = 0;
            lm_current_color++;
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
        }
        break;

      case LM_WIKI:
        {
          //first map the wiki position to the frame offset of a typical slow rotate
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
          //then set the wheel to the rainbow color at that offset
          LED_marquee(p1_offset, P1_WIKI);
          LED_marquee(p2_offset, P2_WIKI);
        }
        break;

      case LM_WIKI_SLOW_FADE:
        {
          //update colors first:
          //set the color to a step between the current color and the next in the loop, based on how far along the LM_MARQUEE_FADE_FRAMES position.
          //set variable for mapping
          uint32_t current_color = rainbow[lm_current_color];
          uint32_t next_color = 0;
          if(lm_current_color >= (num_rainbow_colors-1)){
            next_color = rainbow[0];
          }
          else{
            next_color = rainbow[lm_current_color+1];
          }
          //assign the colors based on the above.
          uint32_t current_red = (uint8_t)(current_color >> 16);
          uint32_t current_green = (uint8_t)(current_color >> 8);
          uint32_t current_blue = (uint8_t)(current_color);
          uint32_t next_red = (uint8_t)(next_color >> 16);
          uint32_t next_green = (uint8_t)(next_color >> 8);
          uint32_t next_blue = (uint8_t)(next_color);
          //do the map thing to get the color between the two based on LM_MARQUEE_FADE_FRAMES
          uint32_t mid_red = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_red, next_red);
          uint32_t mid_green = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_green, next_green);
          uint32_t mid_blue = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_blue, next_blue);
          //check to see if the mid color is 'off' and increment until it is no longer off.
          while(is_gc_color_off(strip.Color(mid_red, mid_green, mid_blue))){
            //increment frames, jump to the next color if rollover occurs:
            lm_current_marquee_color_position++;
            if(lm_current_marquee_color_position >= LM_MARQUEE_FADE_FRAMES){
              lm_current_marquee_color_position = 0;
              lm_current_color++;
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            current_color = rainbow[lm_current_color];
            if(lm_current_color >= (num_rainbow_colors-1)){
              next_color = rainbow[0];
            }
            else{
              next_color = rainbow[lm_current_color+1];
            }
            current_red = (uint8_t)(current_color >> 16);
            current_green = (uint8_t)(current_color >> 8);
            current_blue = (uint8_t)(current_color);
            next_red = (uint8_t)(next_color >> 16);
            next_green = (uint8_t)(next_color >> 8);
            next_blue = (uint8_t)(next_color);
            //do the map thing to get the color between the two based on LM_MARQUEE_FADE_FRAMES
            mid_red = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_red, next_red);
            mid_green = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_green, next_green);
            mid_blue = map(lm_current_marquee_color_position, 0, LM_MARQUEE_FADE_FRAMES, current_blue, next_blue);
                        
          }

          //set the marquee to the right color:
          populate_marquee(strip.Color(mid_red, mid_green, mid_blue));

          //first map the wiki position to the frame offset of a typical slow rotate
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
          //then set the wheel to the rainbow color at that offset
          LED_marquee(p1_offset, P1_WIKI);
          LED_marquee(p2_offset, P2_WIKI);

          //increment frames, jump to the next color if rollover occurs:
          lm_current_marquee_color_position++;
          if(lm_current_marquee_color_position >= LM_MARQUEE_FADE_FRAMES){
            lm_current_marquee_color_position = 0;
            lm_current_color++;
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
        }
        break;

      case LM_WIKI_RAINBOW:
        {
          //first map the wiki position to the frame offset of a typical slow rotate
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
          //then set the wheel to the rainbow color at that offset
          LED_rainbow(p1_offset, P1_WIKI);
          LED_rainbow(p2_offset, P2_WIKI);
        }
        break;

      case LM_SLOW_ROTATE:
        {
          //set p1 directions
          if(direction_left == POSITIVE){
            last_p1_direction = NEGATIVE;
          }
          else if(direction_left == NEGATIVE){
            last_p1_direction = POSITIVE;
          }
          //increment in the correct direction. Will continue even if the disk stops.
          if(last_p1_direction == POSITIVE){
            lm_current_transition_position++;
            LED_rainbow(lm_current_transition_position, P1_WIKI);
            if(lm_current_transition_position >= LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position = 0;
            }
          }
          else if(last_p1_direction == NEGATIVE){
            lm_current_transition_position--;
            LED_rainbow(lm_current_transition_position, P1_WIKI);
            if(lm_current_transition_position <= -LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position = 0;
            }
          }
          //set p2 directions
          if(direction_right == POSITIVE){
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE){
            last_p2_direction = NEGATIVE;
          }
          //increment in the correct direction. Will continue even if the disk stops.
          if(last_p2_direction == POSITIVE){
            lm_current_transition_position_2++;
            LED_rainbow(lm_current_transition_position_2, P2_WIKI);
            if(lm_current_transition_position_2 >= LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position_2 = 0;
            }
          }
          else if(last_p2_direction == NEGATIVE){
            lm_current_transition_position_2--;
            LED_rainbow(lm_current_transition_position_2, P2_WIKI);
            if(lm_current_transition_position_2 <= -LM_SLOW_ROTATE_FRAMES){
              lm_current_transition_position_2 = 0;
            }
          }
        }
        break;

      case LM_RANDOM_RAINBOW:
        {
          //check of wheels have changed direction to let the thing update one time.
          bool p1_wheel_has_changed = false;
          bool p2_wheel_has_changed = false;
          if(direction_left == POSITIVE && last_p1_direction == NEGATIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = POSITIVE;
          }
          else if(direction_left == NEGATIVE && last_p1_direction == POSITIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = NEGATIVE;
          }
          if(direction_right == POSITIVE && last_p2_direction == NEGATIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE && last_p2_direction == POSITIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = NEGATIVE;
          }

          //increment frames, jump to the next color if rollover occurs:
          if(lm_p1_button_has_been_pressed || p1_wheel_has_changed ){
            lm_current_transition_position = random(LM_SLOW_ROTATE_FRAMES);
            lm_p1_button_has_been_pressed = false;
            p1_wheel_has_changed = false;
          }
          if(lm_p2_button_has_been_pressed || p2_wheel_has_changed ){
            lm_current_transition_position_2 = random(LM_SLOW_ROTATE_FRAMES);
            lm_p2_button_has_been_pressed = false;
            p2_wheel_has_changed = false;
          }

          LED_rainbow(lm_current_transition_position, P1_WIKI);
          LED_rainbow(lm_current_transition_position_2, P2_WIKI);
        }
        break;

      case LM_RANDOM_COLOR:
        {
          //check of wheels have changed direction to let the thing update one time.
          bool p1_wheel_has_changed = false;
          bool p2_wheel_has_changed = false;
          if(direction_left == POSITIVE && last_p1_direction == NEGATIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = POSITIVE;
          }
          else if(direction_left == NEGATIVE && last_p1_direction == POSITIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = NEGATIVE;
          }
          if(direction_right == POSITIVE && last_p2_direction == NEGATIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE && last_p2_direction == POSITIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = NEGATIVE;
          }

          //increment frames, jump to the next color if rollover occurs:
          if(lm_p1_button_has_been_pressed || p1_wheel_has_changed ){
            int last_position = lm_current_transition_position;
            while(rainbow[last_position] == rainbow[lm_current_transition_position] || rainbow[lm_current_transition_position] == off){
              lm_current_transition_position = random(num_rainbow_colors);
            }
            lm_p1_button_has_been_pressed = false;
            p1_wheel_has_changed = false;
          }
          if(lm_p2_button_has_been_pressed || p2_wheel_has_changed ){
            int last_position_2 = lm_current_transition_position_2;
            while(rainbow[last_position_2] == rainbow[lm_current_transition_position_2] || rainbow[lm_current_transition_position_2] == off){
              lm_current_transition_position_2 = random(num_rainbow_colors);
            }
            lm_p2_button_has_been_pressed = false;
            p2_wheel_has_changed = false;
          }

          LED_single_color(rainbow[lm_current_transition_position], P1_WIKI);
          LED_single_color(rainbow[lm_current_transition_position_2], P2_WIKI);
        }
        break;

      case LM_COLOR_PULSE:
        {
          //check of wheels have changed direction to let the thing update one time.
          bool p1_wheel_has_changed = false;
          bool p2_wheel_has_changed = false;
          if(direction_left == POSITIVE && last_p1_direction == NEGATIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = POSITIVE;
          }
          else if(direction_left == NEGATIVE && last_p1_direction == POSITIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = NEGATIVE;
          }
          if(direction_right == POSITIVE && last_p2_direction == NEGATIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE && last_p2_direction == POSITIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = NEGATIVE;
          }

          //increment frames, jump to the next color if rollover occurs:
          if(lm_p1_button_has_been_pressed || p1_wheel_has_changed ){
            //add a color pulse
            cp pulse{
              .color = rainbow[lm_current_color],
              //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
              .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
              .player = P1_WIKI,
              .side = RIGHT
            };
            //alternate sides for the pulses
            if(last_p1_pulse_side == RIGHT){
              pulse.side = LEFT;
              last_p1_pulse_side = LEFT;
            }
            else{
              last_p1_pulse_side = RIGHT;
            }
            //send the pulse to the array for processing.
            LED_add_color_pulse(pulse);
            lm_p1_button_has_been_pressed = false;
            p1_wheel_has_changed = false;
          }
          if(lm_p2_button_has_been_pressed || p2_wheel_has_changed ){
            //add a color pulse
            cp pulse{
              .color = rainbow[lm_current_color],
              //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
              .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
              .player = P2_WIKI,
              .side = RIGHT
            };
            //alternate sides for the pulses
            if(last_p2_pulse_side == RIGHT){
              pulse.side = LEFT;
              last_p2_pulse_side = LEFT;
            }
            else{
              last_p2_pulse_side = RIGHT;
            }
            //send the pulse to the array for processing.
            LED_add_color_pulse(pulse);
            lm_p2_button_has_been_pressed = false;
            p2_wheel_has_changed = false;
          }
          LED_color_pulse_refresh(rainbow[lm_current_color]);
        }
        break;

      case LM_COLOR_PULSE_SLOW_FADE:
        {
          //update colors first:
          //set the color to a step between the current color and the next in the loop, based on how far along the LM_COLOR_PULSE_FRAMES position.
          //set variable for mapping
          uint32_t current_color = rainbow[lm_current_color];
          uint32_t next_color = 0;
          if(lm_current_color >= (num_rainbow_colors-1)){
            next_color = rainbow[0];
          }
          else{
            next_color = rainbow[lm_current_color+1];
          }
          //assign the colors based on the above.
          uint32_t current_red = (uint8_t)(current_color >> 16);
          uint32_t current_green = (uint8_t)(current_color >> 8);
          uint32_t current_blue = (uint8_t)(current_color);
          uint32_t next_red = (uint8_t)(next_color >> 16);
          uint32_t next_green = (uint8_t)(next_color >> 8);
          uint32_t next_blue = (uint8_t)(next_color);
          //do the map thing to get the color between the two based on LM_COLOR_PULSE_FRAMES
          uint32_t mid_red = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_red, next_red);
          uint32_t mid_green = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_green, next_green);
          uint32_t mid_blue = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_blue, next_blue);
          //check to see if the mid color is 'off' and increment until it is no longer off.
          while(is_gc_color_off(strip.Color(mid_red, mid_green, mid_blue))){
            //increment frames, jump to the next color if rollover occurs:
            lm_current_marquee_color_position++;
            if(lm_current_marquee_color_position >= LM_COLOR_PULSE_FRAMES){
              lm_current_marquee_color_position = 0;
              lm_current_color++;
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            current_color = rainbow[lm_current_color];
            if(lm_current_color >= (num_rainbow_colors-1)){
              next_color = rainbow[0];
            }
            else{
              next_color = rainbow[lm_current_color+1];
            }
            current_red = (uint8_t)(current_color >> 16);
            current_green = (uint8_t)(current_color >> 8);
            current_blue = (uint8_t)(current_color);
            next_red = (uint8_t)(next_color >> 16);
            next_green = (uint8_t)(next_color >> 8);
            next_blue = (uint8_t)(next_color);
            //do the map thing to get the color between the two based on LM_COLOR_PULSE_FRAMES
            mid_red = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_red, next_red);
            mid_green = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_green, next_green);
            mid_blue = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_blue, next_blue);                        
          }

          //take the above and make the current color a variable for use below:
          uint32_t mid_color = strip.Color(mid_red, mid_green, mid_blue);

          //check of wheels have changed direction to let the thing update one time.
          bool p1_wheel_has_changed = false;
          bool p2_wheel_has_changed = false;
          if(direction_left == POSITIVE && last_p1_direction == NEGATIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = POSITIVE;
          }
          else if(direction_left == NEGATIVE && last_p1_direction == POSITIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = NEGATIVE;
          }
          if(direction_right == POSITIVE && last_p2_direction == NEGATIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE && last_p2_direction == POSITIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = NEGATIVE;
          }

          //increment frames, jump to the next color if rollover occurs:
          if(lm_p1_button_has_been_pressed || p1_wheel_has_changed ){
            //add a color pulse
            cp pulse{
              .color = mid_color,
              //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
              .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
              .player = P1_WIKI,
              .side = RIGHT
            };
            //alternate sides for the pulses
            if(last_p1_pulse_side == RIGHT){
              pulse.side = LEFT;
              last_p1_pulse_side = LEFT;
            }
            else{
              last_p1_pulse_side = RIGHT;
            }
            //send the pulse to the array for processing.
            LED_add_color_pulse(pulse);
            lm_p1_button_has_been_pressed = false;
            p1_wheel_has_changed = false;
          }
          if(lm_p2_button_has_been_pressed || p2_wheel_has_changed ){
            //add a color pulse
            cp pulse{
              .color = mid_color,
              //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
              .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
              .player = P2_WIKI,
              .side = RIGHT
            };
            //alternate sides for the pulses
            if(last_p2_pulse_side == RIGHT){
              pulse.side = LEFT;
              last_p2_pulse_side = LEFT;
            }
            else{
              last_p2_pulse_side = RIGHT;
            }
            //send the pulse to the array for processing.
            LED_add_color_pulse(pulse);
            lm_p2_button_has_been_pressed = false;
            p2_wheel_has_changed = false;
          }
          //refresh so the animation keeps updating
          LED_color_pulse_refresh(mid_color);

          //increment frames, jump to the next color if rollover occurs:
          lm_current_marquee_color_position++;
          if(lm_current_marquee_color_position >= LM_COLOR_PULSE_FRAMES){
            lm_current_marquee_color_position = 0;
            lm_current_color++;
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
        }
        break;

      case LM_COLOR_PULSE_RAINBOW:
        {
          //update colors first:
          //set the color to a step between the current color and the next in the loop, based on how far along the LM_COLOR_PULSE_FRAMES position.
          //set variable for mapping
          uint32_t current_color = rainbow[lm_current_color];
          uint32_t next_color = 0;
          if(lm_current_color >= (num_rainbow_colors-1)){
            next_color = rainbow[0];
          }
          else{
            next_color = rainbow[lm_current_color+1];
          }
          //assign the colors based on the above.
          uint32_t current_red = (uint8_t)(current_color >> 16);
          uint32_t current_green = (uint8_t)(current_color >> 8);
          uint32_t current_blue = (uint8_t)(current_color);
          uint32_t next_red = (uint8_t)(next_color >> 16);
          uint32_t next_green = (uint8_t)(next_color >> 8);
          uint32_t next_blue = (uint8_t)(next_color);
          //do the map thing to get the color between the two based on LM_COLOR_PULSE_FRAMES
          uint32_t mid_red = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_red, next_red);
          uint32_t mid_green = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_green, next_green);
          uint32_t mid_blue = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_blue, next_blue);
          //check to see if the mid color is 'off' and increment until it is no longer off.
          while(is_gc_color_off(strip.Color(mid_red, mid_green, mid_blue))){
            //increment frames, jump to the next color if rollover occurs:
            lm_current_marquee_color_position++;
            if(lm_current_marquee_color_position >= LM_COLOR_PULSE_FRAMES){
              lm_current_marquee_color_position = 0;
              lm_current_color++;
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            current_color = rainbow[lm_current_color];
            if(lm_current_color >= (num_rainbow_colors-1)){
              next_color = rainbow[0];
            }
            else{
              next_color = rainbow[lm_current_color+1];
            }
            current_red = (uint8_t)(current_color >> 16);
            current_green = (uint8_t)(current_color >> 8);
            current_blue = (uint8_t)(current_color);
            next_red = (uint8_t)(next_color >> 16);
            next_green = (uint8_t)(next_color >> 8);
            next_blue = (uint8_t)(next_color);
            //do the map thing to get the color between the two based on LM_COLOR_PULSE_FRAMES
            mid_red = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_red, next_red);
            mid_green = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_green, next_green);
            mid_blue = map(lm_current_marquee_color_position, 0, LM_COLOR_PULSE_FRAMES, current_blue, next_blue);                        
          }

          //take the above and make the current color a variable for use below:
          uint32_t mid_color = strip.Color(mid_red, mid_green, mid_blue);

          //check of wheels have changed direction to let the thing update one time.
          bool p1_wheel_has_changed = false;
          bool p2_wheel_has_changed = false;
          if(direction_left == POSITIVE && last_p1_direction == NEGATIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = POSITIVE;
          }
          else if(direction_left == NEGATIVE && last_p1_direction == POSITIVE){
            p1_wheel_has_changed = true;
            last_p1_direction = NEGATIVE;
          }
          if(direction_right == POSITIVE && last_p2_direction == NEGATIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = POSITIVE;
          }
          else if(direction_right == NEGATIVE && last_p2_direction == POSITIVE){
            p2_wheel_has_changed = true;
            last_p2_direction = NEGATIVE;
          }

          //increment frames, jump to the next color if rollover occurs:
          if(lm_p1_button_has_been_pressed || p1_wheel_has_changed ){
            //increment the color every time a button is pressed.
            lm_current_color++;
            //if the color is larger than there are colors, reset it.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
            //skip the color if it is 'off' for this mode.
            while(rainbow[lm_current_color] == off){
              lm_current_color++;
              //loop back to the start as required.
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            
            //add a color pulse
            cp pulse{
              .color = mid_color,
              //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
              .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
              .player = P1_WIKI,
              .side = RIGHT
            };
            //alternate sides for the pulses
            if(last_p1_pulse_side == RIGHT){
              pulse.side = LEFT;
              last_p1_pulse_side = LEFT;
            }
            else{
              last_p1_pulse_side = RIGHT;
            }
            //send the pulse to the array for processing.
            LED_add_color_pulse(pulse);
            lm_p1_button_has_been_pressed = false;
            p1_wheel_has_changed = false;
          }
          if(lm_p2_button_has_been_pressed || p2_wheel_has_changed ){
            //increment the color every time a button is pressed.
            lm_current_color++;
            //if the color is larger than there are colors, reset it.
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
            //skip the color if it is 'off' for this mode.
            while(rainbow[lm_current_color] == off){
              lm_current_color++;
              //loop back to the start as required.
              if(lm_current_color >= num_rainbow_colors){
                lm_current_color = 0;
              }
            }
            
            //add a color pulse
            cp pulse{
              .color = mid_color,
              //start it one step ahead of where you actually want it to show, as the refresh function will cause it to step once.
              .position = LM_DEFAULT_PULSE_POSITION+LM_DEGREES_PER_FRAME,
              .player = P2_WIKI,
              .side = RIGHT
            };
            //alternate sides for the pulses
            if(last_p2_pulse_side == RIGHT){
              pulse.side = LEFT;
              last_p2_pulse_side = LEFT;
            }
            else{
              last_p2_pulse_side = RIGHT;
            }
            //send the pulse to the array for processing.
            LED_add_color_pulse(pulse);
            lm_p2_button_has_been_pressed = false;
            p2_wheel_has_changed = false;
          }
          LED_color_pulse_refresh(mid_color);

          //increment frames, jump to the next color if rollover occurs:
          lm_current_marquee_color_position++;
          if(lm_current_marquee_color_position >= LM_COLOR_PULSE_FRAMES){
            lm_current_marquee_color_position = 0;
            lm_current_color++;
            if(lm_current_color >= num_rainbow_colors){
              lm_current_color = 0;
            }
          }
        }
        break;

      /* default template for new modes:
      case LM_INSERT_NEW_NAME_HERE:
        {
          
        }
        break;
        */
      
      case LM_RAINBOW_UP:
        {
        //do nothing
        }
        break;

      case LM_RAINBOW_DOWN:
        {
        //do nothing
        }
        break;

      case LM_OFF:
        {
          //set the color every time anyways, in case the lighting power was interrupted.
          LED_single_color(off, BOTH_WIKI);
        }
        break;
    }
  }
}

//this function switches the rainbow array to a different rainbow, as defined up top.
void set_rainbow(int num){
  num_rainbow_colors = rainbows[num].num_colors;
  for(int i=0; i<num_rainbow_colors; i++){
    rainbow[i] = rainbows[num].colors[i];
  }
  LED_rainbow(0, BOTH_WIKI);
  delay(RAINBOW_DISPLAY_TIME);
}

//this sets an array similar to a rainbow for marquee functions. Call it to update the marquee color.
void populate_marquee(uint32_t color){
  int current_marquee_position = 0;
  for(int i=0; i<LM_NUM_ITERATIONS; i++){
    for(int j=0; j<LM_NUM_ON; j++){
      marquee[current_marquee_position] = color;
      current_marquee_position++;
    }
    for(int j=0; j<LM_NUM_OFF; j++){
      marquee[current_marquee_position] = off;
      current_marquee_position++;
    }
  }
}

//this will test if a color is off after gamma correction
bool is_gc_color_off(uint32_t color){
  uint8_t current_red = (uint8_t)(color >> 16);
  uint8_t current_green = (uint8_t)(color >> 8);
  uint8_t current_blue = (uint8_t)(color);
  uint32_t test_color = strip.Color(pgm_read_byte(&gamma8[current_red]), pgm_read_byte(&gamma8[current_green]), pgm_read_byte(&gamma8[current_blue]));
  if(test_color == off){
    return true;
  }
  else{
    return false;
  }
}

//This one will set all the LEDs to a single color on either or both wikis.
void LED_single_color(uint32_t color, int wiki){
  if(wiki == P1_WIKI){
    for( int i=0; i<NUM_LEDS/2; i++){
      strip_setPixelColor(i, color);
    }
  }
  else if(wiki == P2_WIKI){
    for( int i=0; i<NUM_LEDS/2; i++){
      strip_setPixelColor(i+NUM_LEDS/2, color);
    }
  }
  else if(wiki == BOTH_WIKI){
    for( int i=0; i<NUM_LEDS; i++){
      strip_setPixelColor(i, color);
    }
  }
  strip.show();
}

//this is a function to set a rainbow pattern around the disks with an offset:
void LED_rainbow(int offset, int wiki_select){
  //change variables as needed for the default state of this lighting mode:
  //first need to work out the color of each pixel based on a starting offset of 0.
  //There wil be LM_SLOW_ROTATE_FRAMES states in the animation.
  //the rainbow will need to be spread evenly over these LM_SLOW_ROTATE_FRAMES, and then we will
  //need to offset by offset, which increments by 1 every frame. This will start at position 0.

  //will need to take into account negative offsets for wiki animations. This can be done by inverting the offset at the start:
  if(offset <= 0){
    offset = LM_SLOW_ROTATE_FRAMES+offset;
  }

  //So to start, we will need an offset number which maps which of the positions the num_rainbow_colors 'pure' colors map to.
  int pure_color_offset = LM_SLOW_ROTATE_FRAMES*LM_SLOW_ROTATE_SCALING_FACTOR/num_rainbow_colors;
  //then we will need an offset which notes which NUM_LEDS/2 positions out of the total fall directly on the LEDs
  int led_position_offset = LM_SLOW_ROTATE_FRAMES*LM_SLOW_ROTATE_SCALING_FACTOR/(NUM_LEDS/2);
  //With this number we can make note of the positions where LEDs will always be in an array:
  int led_position_array[NUM_LEDS];
  led_position_array[0] = 0;
  for(int i=1; i<(NUM_LEDS); i++){
    led_position_array[i] = led_position_array[i-1]+led_position_offset;
  }

  uint32_t double_rainbow[num_rainbow_colors*2];
  for(int i=0; i<num_rainbow_colors; i++){
    double_rainbow[i] = rainbow[i];
  }
  for(int i=0; i<num_rainbow_colors; i++){
    double_rainbow[i+num_rainbow_colors] = rainbow[i];
  }
  
  //make an int to track the number of LEDS that have been set.
  int num_leds_set = 0;
  //and another to tell the for loop to break when all have been set
  bool all_leds_set = false;

  //iterate through the colors starting at the starting LED, and looping back when it hits NUM_LEDS/2
  for(int i=0; i<num_rainbow_colors*2; i++){
    //establish the current and next color. the next color will need to be color 0 on the final iteration.
    uint32_t current_color;
    uint32_t next_color;
    if(i != (num_rainbow_colors*2-1)){
      current_color = double_rainbow[i];
      next_color = double_rainbow[i+1];
    }
    else{
      current_color = double_rainbow[i];
      next_color = double_rainbow[0];
    }
    //break out the RGB values from the 32 bit color for mapping purposes.
    uint8_t current_red = (uint8_t)(current_color >> 16);
    uint8_t current_green = (uint8_t)(current_color >> 8);
    uint8_t current_blue = (uint8_t)(current_color);
    uint8_t next_red = (uint8_t)(next_color >> 16);
    uint8_t next_green = (uint8_t)(next_color >> 8);
    uint8_t next_blue = (uint8_t)(next_color);
    
    //set the current and next color positions. If either is greater than LM_SLOW_ROTATE_FRAMES, it will need to be fixed before setting a color.
    int current_color_position = offset*LM_SLOW_ROTATE_SCALING_FACTOR + (i*pure_color_offset);
    int next_color_position = offset*LM_SLOW_ROTATE_SCALING_FACTOR + (i*pure_color_offset) + pure_color_offset;

    //iterate through all LEDs and see which LEDs are between the color positions.
    for(int led = 0; led < NUM_LEDS; led++){
      if(led_position_array[led] >= current_color_position && led_position_array[led] < next_color_position){
        //Should only activate if the LED position is between the current and next LED.
        //set the led number to be set to a number below NUM_LEDS/2
        int corrected_led = led;
        if(led >= (NUM_LEDS/2)){
          corrected_led = led - (NUM_LEDS/2);
        }
        //set the colors once the positions are corrected as needed.
        uint32_t mid_red = map(led_position_array[led], current_color_position, next_color_position, current_red, next_red);
        uint32_t mid_green = map(led_position_array[led], current_color_position, next_color_position, current_green, next_green);
        uint32_t mid_blue = map(led_position_array[led], current_color_position, next_color_position, current_blue, next_blue);
        if(wiki_select == BOTH_WIKI){
          strip_setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
          strip_setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
        }
        else if(wiki_select == P1_WIKI){
          strip_setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
        }
        else if(wiki_select == P2_WIKI){
          strip_setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
        }
        else{
          #ifdef LIGHTING_DEBUG
          Serial.println("Fix your call to LED_rainbow() to use BOTH_WIKI, P1_WIKI, or P2_WIKI plsthx.");
          #endif
        }
        
        num_leds_set++;
        //check to see if it's set all of the LEDS. and if so, break from the function
        if(num_leds_set > NUM_LEDS/2){
          all_leds_set = true;
        }
        #ifdef LIGHTING_DEBUG
        /* only uncomment if needed. Too spammy.
        Serial.print("i is: ");
        Serial.print(i);
        Serial.print(" and led is: ");
        Serial.print(led);
        Serial.print(" and current LED position is ");
        Serial.print(led_position_array[led]);
        Serial.print(" and current color position is ");
        Serial.println(current_color_position);
        */
        #endif
        
      }
      if(all_leds_set){
        break;
      }
    }
  }
  strip.show();
}

//this fills the marquee functions. To change colors, use populate_marquee()
void LED_marquee(int offset, int wiki_select){
  //this started as the wiki rainbow code, but now is changed to step more abruptly.

  //will need to take into account negative offsets for wiki animations. This can be done by inverting the offset at the start:
  if(offset <= 0){
    offset = LM_SLOW_ROTATE_FRAMES+offset;
  }

  //So to start, we will need an offset number which maps which of the positions the num_marquee_positions 'pure' colors map to.
  int pure_color_offset = LM_SLOW_ROTATE_FRAMES*LM_SLOW_ROTATE_SCALING_FACTOR/num_marquee_positions;
  //then we will need an offset which notes which NUM_LEDS/2 positions out of the total fall directly on the LEDs
  int led_position_offset = LM_SLOW_ROTATE_FRAMES*LM_SLOW_ROTATE_SCALING_FACTOR/(NUM_LEDS/2);
  //With this number we can make note of the positions where LEDs will always be in an array:
  int led_position_array[NUM_LEDS];
  led_position_array[0] = 0;
  for(int i=1; i<(NUM_LEDS); i++){
    led_position_array[i] = led_position_array[i-1]+led_position_offset;
  }

  uint32_t double_marquee[num_marquee_positions*2];
  for(int i=0; i<num_marquee_positions; i++){
    double_marquee[i] = marquee[i];
  }
  for(int i=0; i<num_marquee_positions; i++){
    double_marquee[i+num_marquee_positions] = marquee[i];
  }
  
  //make an int to track the number of LEDS that have been set.
  int num_leds_set = 0;
  //and another to tell the for loop to break when all have been set
  bool all_leds_set = false;

  //iterate through the colors starting at the starting LED, and looping back when it hits NUM_LEDS/2
  for(int i=0; i<num_marquee_positions*2; i++){
    //establish the current and next color. the next color will need to be color 0 on the final iteration.
    uint32_t current_color;
    uint32_t next_color;
    if(i != (num_marquee_positions*2-1)){
      current_color = double_marquee[i];
      next_color = double_marquee[i+1];
    }
    else{
      current_color = double_marquee[i];
      next_color = double_marquee[0];
    }
    //break out the RGB values from the 32 bit color for mapping purposes.
    uint8_t current_red = (uint8_t)(current_color >> 16);
    uint8_t current_green = (uint8_t)(current_color >> 8);
    uint8_t current_blue = (uint8_t)(current_color);
    uint8_t next_red = (uint8_t)(next_color >> 16);
    uint8_t next_green = (uint8_t)(next_color >> 8);
    uint8_t next_blue = (uint8_t)(next_color);
    
    //set the current and next color positions. If either is greater than LM_SLOW_ROTATE_FRAMES, it will need to be fixed before setting a color.
    int current_color_position = offset*LM_SLOW_ROTATE_SCALING_FACTOR + (i*pure_color_offset);
    int next_color_position = offset*LM_SLOW_ROTATE_SCALING_FACTOR + (i*pure_color_offset) + pure_color_offset;

    //iterate through all LEDs and see which LEDs are between the color positions.
    for(int led = 0; led < NUM_LEDS; led++){
      if(led_position_array[led] >= current_color_position && led_position_array[led] < next_color_position){
        //Should only activate if the LED position is between the current and next LED.
        //set the led number to be set to a number below NUM_LEDS/2
        int corrected_led = led;
        if(led >= (NUM_LEDS/2)){
          corrected_led = led - (NUM_LEDS/2);
        }
        //set the colors once the positions are corrected only on the LM_MARQUEE_FRAMESth frame
        //using lm_current_transition_position instead of offset in the modulus if statement to get both wheels to move at the same time.
        if((lm_current_transition_position%LM_MARQUEE_FRAMES) == 0 || lighting_mode == LM_WIKI || lighting_mode == LM_WIKI_SLOW_FADE){
          uint32_t mid_red = map(led_position_array[led], current_color_position, next_color_position, current_red, next_red);
          uint32_t mid_green = map(led_position_array[led], current_color_position, next_color_position, current_green, next_green);
          uint32_t mid_blue = map(led_position_array[led], current_color_position, next_color_position, current_blue, next_blue);
          if(wiki_select == BOTH_WIKI){
            strip_setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
            strip_setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
          }
          else if(wiki_select == P1_WIKI){
            strip_setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
          }
          else if(wiki_select == P2_WIKI){
            strip_setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
          }
          else{
            #ifdef LIGHTING_DEBUG
            Serial.println("Fix your call to LED_rainbow() to use BOTH_WIKI, P1_WIKI, or P2_WIKI plsthx.");
            #endif
          }
        }
        
        num_leds_set++;
        //check to see if it's set all of the LEDS. and if so, break from the function
        if(num_leds_set > NUM_LEDS/2){
          all_leds_set = true;
        }
        #ifdef LIGHTING_DEBUG
        /* only uncomment if needed. Too spammy.
        Serial.print("i is: ");
        Serial.print(i);
        Serial.print(" and led is: ");
        Serial.print(led);
        Serial.print(" and current LED position is ");
        Serial.print(led_position_array[led]);
        Serial.print(" and current color position is ");
        Serial.println(current_color_position);
        */
        #endif
        
      }
      if(all_leds_set){
        break;
      }
    }
  }
  strip.show();
}

//this controls the color pulses.
void LED_add_color_pulse(cp pulse){
  //new pulses are added to the active pulses array, and will be removed automatically as they are completed.
  //only add a new pulse if there are less than the max number running currently.
  if(lm_num_active_pulses < MAX_COLOR_PULSES){
    //add the new pulse to the end
    pulse_array[lm_num_active_pulses] = pulse;
    //increment the number of pulses by 1
    lm_num_active_pulses++;
    #ifdef LIGHTING_DEBUG
      /* Spammy, uncomment is needed.
      Serial.print("Added lighting pulse number ");
      Serial.println(lm_num_active_pulses);
      */
    #endif
  }
  //always call a refresh when a new pulse is added
  LED_color_pulse_refresh(pulse.color);
}

//this will clean the array if any color pulses have a position less than 0.
void LED_remove_color_pulses(){
  //a temp variable to keep track of how many items were removed
  int num_pulses_removed = 0;
  //copy the array so it can be trimmed
  cp old_pulse_array[MAX_COLOR_PULSES];
  memcpy(old_pulse_array, pulse_array, sizeof(pulse_array));
  //iterate through pulse_array and remove any pulses with a position less than 0.
  for(int i=0; i<lm_num_active_pulses; i++){
    //check to see if it's hit 0, and mark it for removal.
    if(old_pulse_array[i].position <= 0){
      //don't copy the value to the new array, just increment the number of removed pulses.
      num_pulses_removed++;
    }
    else{
      //set the next element of the pulse array to the current old_pulse_array element.
      pulse_array[i-num_pulses_removed] = old_pulse_array[i];
    }
  }
  //update the total number of active pulses
  lm_num_active_pulses = lm_num_active_pulses - num_pulses_removed;
  #ifdef LIGHTING_DEBUG
    /* Spammy, uncomment is needed.
    if(lm_num_active_pulses >= 0 && num_pulses_removed > 0){
      Serial.print("Removed lighting pulses. Currently active pulses: ");
      Serial.println(lm_num_active_pulses);
    }
    */
  #endif

}

//this will parse through the pulse_array and increment all pulses by LM_DEGREES_PER_FRAME whenever called, pruning those needed, and update the display.
void LED_color_pulse_refresh(uint32_t current_color){
  //always start with a blank array, repopulate it, and then show the strip at the end.
  LED_single_color(off, BOTH_WIKI);
  //iterate through the pulse array and update all the pulses
  for(int i=0; i<lm_num_active_pulses; i++){
    pulse_array[i].position = pulse_array[i].position - LM_DEGREES_PER_FRAME;
  }
  //prune pulses no longer in the array
  LED_remove_color_pulses();
  //arrays for storing colors of pulses currently traveling
  int max_number_of_positions = floor(LM_DEFAULT_PULSE_POSITION/LM_DEGREES_PER_FRAME);
  uint32_t p1_left_colors[max_number_of_positions];
  uint32_t p1_right_colors[max_number_of_positions];
  uint32_t p2_left_colors[max_number_of_positions];
  uint32_t p2_right_colors[max_number_of_positions];

  for(int i=0; i<max_number_of_positions; i++){
    p1_left_colors[i] = off;
    p1_right_colors[i] = off;
    p2_left_colors[i] = off;
    p2_right_colors[i] = off;
  }

  //set LED colors at the correct angle
  for(int i=0; i<lm_num_active_pulses; i++){
    //first do p1_left:
    if(pulse_array[i].player == P1_WIKI && pulse_array[i].side == LEFT){
      //set the color of the closest position to this pulse's position in the p1_* array.
      int array_position = map(pulse_array[i].position, LM_DEFAULT_PULSE_POSITION, 0, max_number_of_positions, 0);
      p1_left_colors[array_position] = pulse_array[i].color;
    }
    else if(pulse_array[i].player == P1_WIKI && pulse_array[i].side == RIGHT){
      //set the color of the closest position to this pulse's position in the p1_* array.
      int array_position = map(pulse_array[i].position, LM_DEFAULT_PULSE_POSITION, 0, max_number_of_positions, 0);
      p1_right_colors[array_position] = pulse_array[i].color;

    }
    else if(pulse_array[i].player == P2_WIKI && pulse_array[i].side == LEFT){
      //set the color of the closest position to this pulse's position in the p1_* array.
      int array_position = map(pulse_array[i].position, LM_DEFAULT_PULSE_POSITION, 0, max_number_of_positions, 0);
      p2_left_colors[array_position] = pulse_array[i].color;

    }
    else if(pulse_array[i].player == P2_WIKI && pulse_array[i].side == RIGHT){
      //set the color of the closest position to this pulse's position in the p1_* array.
      int array_position = map(pulse_array[i].position, LM_DEFAULT_PULSE_POSITION, 0, max_number_of_positions, 0);
      p2_right_colors[array_position] = pulse_array[i].color;

    }
  }
  //the starting position, closest to 180 degrees, should always be lit with the current color.
  p1_left_colors[max_number_of_positions-1] = current_color;
  p1_right_colors[max_number_of_positions-1] = current_color;
  p2_left_colors[max_number_of_positions-1] = current_color;
  p2_right_colors[max_number_of_positions-1] = current_color;

  //next we construct two color arrays, 1 for first player, 1 for second player, similar to the rainbow maps used in slow_fade and rainbow_wiki modes.
  uint32_t p1_colors[max_number_of_positions*2];
  uint32_t p2_colors[max_number_of_positions*2];
  for(int i=0; i<max_number_of_positions; i++){
    //left side is easy, just direct assign
    p1_colors[i] = p1_left_colors[i];
    //right side needs to be assigned in reverse, going from 180 in position max_number_of_positions+0 to 0 in position max_number_of_positions*2
    p1_colors[i+max_number_of_positions] = p1_right_colors[max_number_of_positions-i];
    //p2 is the same formula as p1.
    p2_colors[i] = p2_left_colors[i];
    p2_colors[i+max_number_of_positions] = p2_right_colors[max_number_of_positions-i];
  }

  #ifdef LIGHTING_DEBUG
    /* super spammy, disable unless needed.
    Serial.print("P1 Color Array is: ");
    for(int i=0; i<max_number_of_positions; i++){
      Serial.print(p1_colors[i]);
      Serial.print(":");
    }
    Serial.println();
    Serial.print("P2 Color Array is: ");
    for(int i=0; i<max_number_of_positions; i++){
      Serial.print(p2_colors[i]);
      Serial.print(":");
    }
    Serial.println();
    */
  #endif

  //luckily in this mode, the offset is done by setting the color position in the array, 
  //so we don't need to do global offset calculations for rainbows around the disk. We can just start at LED 0 (the top) and move 
  //through the arrays assigning LED position colors.

  //So to start, we will need an offset number which maps which of the positions the max_number_of_positions 'pure' colors map to.
  int pure_color_offset = LM_COLOR_PULSE_FRAMES*LM_SLOW_ROTATE_SCALING_FACTOR/(max_number_of_positions*2);
  //then we will need an offset which notes which NUM_LEDS/2 positions out of the total fall directly on the LEDs
  int led_position_offset = LM_COLOR_PULSE_FRAMES*LM_SLOW_ROTATE_SCALING_FACTOR/(NUM_LEDS/2);
  //With this number we can make note of the positions where LEDs will always be in an array:
  int led_position_array[NUM_LEDS];
  led_position_array[0] = 0;
  for(int i=1; i<(NUM_LEDS); i++){
    led_position_array[i] = led_position_array[i-1]+led_position_offset;
  }

  //iterate through the colors in p1_colors and p2_colors simultaneously, setting maps for LEDs when they are between them.
  for(int i=0; i<max_number_of_positions*2; i++){
    //establish the current and next color. the next color will need to be color 0 on the final iteration.
    uint32_t current_color_p1;
    uint32_t next_color_p1;
    uint32_t current_color_p2;
    uint32_t next_color_p2;
    if(i != (max_number_of_positions*2-1)){
      current_color_p1 = p1_colors[i];
      next_color_p1 = p1_colors[i+1];
      current_color_p2 = p2_colors[i];
      next_color_p2 = p2_colors[i+1];
    }
    else{
      current_color_p1 = p1_colors[i];
      next_color_p1 = p1_colors[0];
      current_color_p2 = p2_colors[i];
      next_color_p2 = p2_colors[0];
    }

    //break out the RGB values from the 32 bit color for mapping purposes.
    uint8_t current_red_p1 = (uint8_t)(current_color_p1 >> 16);
    uint8_t current_green_p1 = (uint8_t)(current_color_p1 >> 8);
    uint8_t current_blue_p1 = (uint8_t)(current_color_p1);
    uint8_t next_red_p1 = (uint8_t)(next_color_p1 >> 16);
    uint8_t next_green_p1 = (uint8_t)(next_color_p1 >> 8);
    uint8_t next_blue_p1 = (uint8_t)(next_color_p1);
    uint8_t current_red_p2 = (uint8_t)(current_color_p2 >> 16);
    uint8_t current_green_p2 = (uint8_t)(current_color_p2 >> 8);
    uint8_t current_blue_p2 = (uint8_t)(current_color_p2);
    uint8_t next_red_p2 = (uint8_t)(next_color_p2 >> 16);
    uint8_t next_green_p2 = (uint8_t)(next_color_p2 >> 8);
    uint8_t next_blue_p2 = (uint8_t)(next_color_p2);
    
    //set the current and next color positions. If either is greater than LM_COLOR_PULSE_FRAMES, it will need to be fixed before setting a color.
    int current_color_position = i*pure_color_offset;
    int next_color_position = i*pure_color_offset + pure_color_offset;

    //iterate through all LEDs and see which LEDs are between the color positions.
    for(int led = 0; led < NUM_LEDS/2; led++){
      //the p1 if pile
      if(led_position_array[led] >= current_color_position && led_position_array[led] < next_color_position){
        //Should only activate if the LED position is between the current and next LED.
        
        //set the colors once the positions are corrected as needed.
        uint32_t mid_red_p1 = map(led_position_array[led], current_color_position, next_color_position, current_red_p1, next_red_p1);
        uint32_t mid_green_p1 = map(led_position_array[led], current_color_position, next_color_position, current_green_p1, next_green_p1);
        uint32_t mid_blue_p1 = map(led_position_array[led], current_color_position, next_color_position, current_blue_p1, next_blue_p1);
        strip_setPixelColor(led, strip.Color(mid_red_p1, mid_green_p1, mid_blue_p1));
      }
      //the p2 if pile
      if(led_position_array[led] >= current_color_position && led_position_array[led] < next_color_position){
        //Should only activate if the LED position is between the current and next LED.
        
        //set the colors once the positions are corrected as needed.
        uint32_t mid_red_p2 = map(led_position_array[led], current_color_position, next_color_position, current_red_p2, next_red_p2);
        uint32_t mid_green_p2 = map(led_position_array[led], current_color_position, next_color_position, current_green_p2, next_green_p2);
        uint32_t mid_blue_p2 = map(led_position_array[led], current_color_position, next_color_position, current_blue_p2, next_blue_p2);
        strip_setPixelColor(led+NUM_LEDS/2-1, strip.Color(mid_red_p2, mid_green_p2, mid_blue_p2));
      }
    }
  }

  //finally, light it all up.
  strip.show();
}
