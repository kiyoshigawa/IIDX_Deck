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
#define LM_SLOW_FADE_FRAMES 900
#define LM_SLOW_ROTATE_FRAMES 300
#define LM_MARQUEE_FRAMES 15

//this scaling factor allows for smoother transitions around the edges on slow_rotate style animations. The integer math rounding makes abrupt changes otherwise
#define LM_SLOW_ROTATE_SCALING_FACTOR 3000

//a couple defines for marquee automatic generation
#define LM_NUM_ON 1
#define LM_NUM_OFF 4
#define LM_NUM_ITERATIONS 5


//lighting mode definitions: Pressing the corresponding button will switch to that mode when in lighting control mode

//Solid lighting in a single color. 
#define LM_SOLID 1
//marquee - will make a repeating on/off pattern that rotates around at fixed time intervals
#define LM_MARQUEE 2
//slow_fade - will slowly cycle through solid rainbow colors on both wheels
#define LM_SLOW_FADE 3
//wiki-follower - single color lights will alternate every other LED on the wheel and follow the movement of the wheels.
#define LM_WIKI 4
//slow_rotate - a rainbow pattern will slowly rotate around the disks
#define LM_SLOW_ROTATE 5
//#6 will go here

//wiki_rainbow - multi-color rainbow pattern will follow the wiki wheel
#define LM_WIKI_RAINBOW 7
//numbers 8 and 9 will likely be used for speed adjustments in the future

//Color Pulse - set off a pulse of color that will rotate around the disk on one a side when a button is pressed on that side.
#define LM_COLOR_PULSE 10

//Off - this will turn off all wiki lighting, but still allow for button lighting if the power is plugged in.
#define LM_OFF 16

//number 17 will send the enter key press signal only when in lighting control mode
#define LM_ENTER_KEY 17
//number 18 will send windows-key+5, which should open the LR2 settings window. Then you can press key 17 to start LR2.
#define LM_WIN_5_KEY 18

//the default mode is set here - it must be one of the above lighting modes
#define LM_DEFAULT LM_WIKI_RAINBOW

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
uint32_t red =   strip.Color(255,   0,   0);
uint32_t rg1 =   strip.Color(255, 127,   0);
uint32_t rg2 =   strip.Color(255, 255,   0);
uint32_t rg3 =   strip.Color(127, 255,   0);
uint32_t green = strip.Color(  0, 255,   0);
uint32_t gb1 =   strip.Color(  0, 255, 127);
uint32_t gb2 =   strip.Color(  0, 255, 255);
uint32_t gb3 =   strip.Color(  0, 127, 255);
uint32_t blue =  strip.Color(  0,   0, 255);
uint32_t br1 =   strip.Color(127,   0, 255);
uint32_t br2 =   strip.Color(255,   0, 255);
uint32_t br3 =   strip.Color(255,   0, 127);

uint32_t white =        strip.Color(255, 255, 255);
uint32_t warm_white =   strip.Color(187, 127,  70);
uint32_t off =          strip.Color(  0,   0,   0);

uint32_t rainbow[] = {red, rg1, rg2, rg3, green, gb1, gb2, gb3, blue, br1, br2, br3};
uint32_t marquee[(LM_NUM_ON+LM_NUM_OFF)*LM_NUM_ITERATIONS];
int num_rainbow_colors = 12;
int num_marquee_positions = (LM_NUM_ON+LM_NUM_OFF)*LM_NUM_ITERATIONS;

//global variables used below
long position_left  = 0;
long position_right = 0;
int direction_left = STOPPED;
int direction_right = STOPPED;
unsigned long last_left_move_time = 0;
unsigned long last_right_move_time = 0;
bool left_encoder_has_stopped = true;
bool right_encoder_has_stopped = true;

//global lighting mode variables:
//default lighting_mode when starting up.
int lighting_mode = LM_DEFAULT;
//this is a flag to let the switch function know if it should reset a lighting mode.
int lm_has_changed = true;
//this is for color modes that cycle through colors
int lm_current_color = 12;
//time variable for limiting lighting refresh rate:
unsigned long last_lighting_update = 0;
//int to keep track of state of fades and rotations
int lm_current_transition_position = 0;

void setup() {
  Serial.begin(9600);
  while(!Serial){};
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
  //still want to have encoders update in case they are to be used in the future to change settings like speed or something while in lighting mode.
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
          //finally, set the color here. There is no need for further input in this mode during the main loop function.
          LED_single_color(rainbow[lm_current_color]);
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
          //reset the transition step variable to 0 so it will start from the new color:
          lm_current_transition_position = 0;
          //finally, set the color here. There is no need for further input in this mode during the main loop function.
          LED_single_color(rainbow[lm_current_color]);
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
          LED_rainbow(lm_current_transition_position, BOTH_WIKI);
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
          //reset the transition step variable to 0 so it will start from the new color:
          populate_marquee(rainbow[lm_current_color]);
          lm_current_transition_position = 0;
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
          //reset the transition step variable to 0 so it will start from the new color:
          populate_marquee(rainbow[lm_current_color]);
          //first map the wiki position to the frame offset of a typical slow rotate
          int p1_offset = map(position_left % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, LM_SLOW_ROTATE_FRAMES, -LM_SLOW_ROTATE_FRAMES);
          int p2_offset = map(position_right % PIPS_PER_REV, -PIPS_PER_REV, PIPS_PER_REV, -LM_SLOW_ROTATE_FRAMES, LM_SLOW_ROTATE_FRAMES);
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

        /* re-enable these as they get programmed...
      case LM_COLOR_PULSE:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now Color-Pulse.");
          #endif
          //change variables as needed for the default state of this lighting mode:

          lm_has_changed = false;
        }
        break;

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

      case LM_OFF:
        {
          #ifdef LIGHTING_DEBUG
            Serial.println("Lighting Mode is now off.");
          #endif
          //change variables as needed for the default state of this lighting mode:
          LED_single_color(off);
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
          LED_single_color(rainbow[lm_current_color]);
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
          uint8_t current_red = (uint8_t)(current_color >> 16);
          uint8_t current_green = (uint8_t)(current_color >> 8);
          uint8_t current_blue = (uint8_t)(current_color);
          uint8_t next_red = (uint8_t)(next_color >> 16);
          uint8_t next_green = (uint8_t)(next_color >> 8);
          uint8_t next_blue = (uint8_t)(next_color);
          //do the map thing to get the color between the two based on LM_SLOW_FADE_FRAMES
          uint32_t mid_red = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_red, next_red);
          uint32_t mid_green = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_green, next_green);
          uint32_t mid_blue = map(lm_current_transition_position, 0, LM_SLOW_FADE_FRAMES, current_blue, next_blue);
          //set the color:
          LED_single_color(strip.Color(mid_red, mid_green, mid_blue));
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

      case LM_SLOW_ROTATE:
        {
          //increment frames, jump to the next color if rollover occurs:
          lm_current_transition_position++;
          LED_rainbow(lm_current_transition_position, BOTH_WIKI);
          if(lm_current_transition_position >= LM_SLOW_ROTATE_FRAMES){
            lm_current_transition_position = 0;
          }
        }
        break;

      case LM_MARQUEE:
        {
          lm_current_transition_position++;
          LED_marquee(lm_current_transition_position, BOTH_WIKI);
          if(lm_current_transition_position >= LM_SLOW_ROTATE_FRAMES){
            lm_current_transition_position = 0;
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

        /* re-enable these as they get programmed...
      case LM_COLOR_PULSE:
        {
        
        }
        break;

      case LM_INSERT_NEW_NAME_HERE:
        {
          
        }
        break;
        */

      case LM_OFF:
        {
          //set the color every time anyways, in case the lighting power was interrupted.
          LED_single_color(off);
        }
        break;
    }
  }
}

//This one will set all the LEDs to a single color.
void LED_single_color(uint32_t color){
  for( int i=0; i<NUM_LEDS; i++){
    strip.setPixelColor(i, color);
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
          strip.setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
          strip.setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
        }
        else if(wiki_select == P1_WIKI){
          strip.setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
        }
        else if(wiki_select == P2_WIKI){
          strip.setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
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
        if((offset%LM_MARQUEE_FRAMES) == 0 || lighting_mode == LM_WIKI){
          uint32_t mid_red = map(led_position_array[led], current_color_position, next_color_position, current_red, next_red);
          uint32_t mid_green = map(led_position_array[led], current_color_position, next_color_position, current_green, next_green);
          uint32_t mid_blue = map(led_position_array[led], current_color_position, next_color_position, current_blue, next_blue);
          if(wiki_select == BOTH_WIKI){
            strip.setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
            strip.setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
          }
          else if(wiki_select == P1_WIKI){
            strip.setPixelColor(corrected_led, strip.Color(mid_red, mid_green, mid_blue));
          }
          else if(wiki_select == P2_WIKI){
            strip.setPixelColor(corrected_led+(NUM_LEDS/2), strip.Color(mid_red, mid_green, mid_blue));
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
