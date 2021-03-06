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

#define POSITIVE 1
#define STOPPED 0
#define NEGATIVE -1

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
uint32_t green = strip.Color(  0, 225,   0);
uint32_t gb1 =   strip.Color(  0, 225, 127);
uint32_t gb2 =   strip.Color(  0, 225, 255);
uint32_t gb3 =   strip.Color(  0, 127, 255);
uint32_t blue =  strip.Color(  0,   0, 255);
uint32_t br1 =   strip.Color(127,   0, 255);
uint32_t br2 =   strip.Color(255,   0, 255);
uint32_t br3 =   strip.Color(255,   0, 127);

uint32_t rainbow[] = {red, rg1, rg2, rg3, green, gb1, gb2, gb3, blue, br1, br2, br3};
int num_rainbow_colors = 12;


uint32_t white =          strip.Color(255, 255, 255);
uint32_t mid_warm_white = strip.Color(187, 127,  70);
uint32_t off =            strip.Color(  0,   0,   0);

//lighting mode definitions: Pressing the corresponding button will switch to that mode when in lighting control mode

//Solid lighting in a single color. 
#define LM_SOLID 1
//wiki-follower - single color lights will alternate every other LED on the wheel and follow the movement of the wheels.
#define LM_WIKI 2
//slow_fade - will slowly cycle through solid rainbow colors on both wheels
#define LM_SLOW_FADE 3
//wiki_rainbow - multi-color rainbow pattern will follow the wiki wheel
#define LM_WIKI_RAINBOW 4
//slow_rotate - a rainbow pattern will slowly rotate around the disks
#define LM_SLOW_ROTATE 5

//Off - this will turn off all wiki lighting, but still allow for button lighting of the power is plugged in.
#define LM_OFF 16

//the default mode is set here - it must be one of the above lighting modes
#define LM_DEFAULT LM_SOLID


//global variables used below
long position_left  = 0;
long position_right = 0;
int direction_left = STOPPED;
int direction_right = STOPPED;
unsigned long last_left_move_time = 0;
unsigned long last_right_move_time = 0;

//global lighting mode variables:
//default lighting_mode when starting up.
int lighting_mode = LM_DEFAULT;
//this is a flag to let the switch function know if it should reset a lighting mode.
int lm_has_changed = true;
//this is for color modes that cycle through colors
int lm_current_color = 0;
//time variable for limiting lighting refresh rate:
unsigned long last_lighting_update = 0;

void setup() {
  Serial.begin(9600);
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
  Joystick.X(-1);

  //LED Strip Setup
  strip.begin();
  //initialize with the default lighting parameters:
  lm_switch();
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
    print_encoder_position();
    
  }
  //if going negative direction
  else if (new_left < (position_left-STEP_THRESHOLD) ) {
    position_left = new_left;
    direction_left = NEGATIVE;
    last_left_move_time = current_time;
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
    print_encoder_position();
  }
  //if going negative direction
  else if (new_right < (position_right-STEP_THRESHOLD) ) {
    position_right = new_right;
    direction_right = NEGATIVE;
    last_right_move_time = current_time;
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
        #ifdef LIGHTING_DEBUG
          Serial.print("Pressed ");
          Serial.println(i+1);
        #endif
        lighting_mode = i+1;
        lm_has_changed = true;
      }
    }
  }
}

//this is the setup function for lighting. It runs when the control mode button is pressed.
//it will set the default state of any mode when the appropriate button is pressed.
void lm_switch(){
  if(lm_has_changed){
    switch(lighting_mode){
      case LM_SOLID:
        #ifdef LIGHTING_DEBUG
          Serial.println("Lighting Mode is now Solid.");
        #endif
        //change variables as needed for the default state of this lighting mode:
        //increment the color every time a button is pressed.
        lm_current_color++;
        //if the color is larger than there are colors, reset it.
        if(lm_current_color > num_rainbow_colors){
          lm_current_color = 0;
        }
        //finally, set the color here. There is no need for further input in this mode during the main loop function.
        LED_single_color(rainbow[lm_current_color]);
        lm_has_changed = false;
        break;
        /* re-enable these as they get programmed...
      case LM_WIKI:
        #ifdef LIGHTING_DEBUG
          Serial.println("Lighting Mode is now Wiki.");
        #endif
        //change variables as needed for the default state of this lighting mode:

        lm_has_changed = false;
        break;
      case LM_SLOW_FADE:
        #ifdef LIGHTING_DEBUG
          Serial.println("Lighting Mode is now Slow-Fade.");
        #endif
        //change variables as needed for the default state of this lighting mode:

        lm_has_changed = false;
        break;
      case LM_WIKI_RAINBOW:
        #ifdef LIGHTING_DEBUG
          Serial.println("Lighting Mode is now Wiki-Rainbow.");
        #endif
        //change variables as needed for the default state of this lighting mode:

        lm_has_changed = false;
        break;
      case LM_SLOW_ROTATE:
        #ifdef LIGHTING_DEBUG
          Serial.println("Lighting Mode is now Slow-Rotate.");
        #endif
        //change variables as needed for the default state of this lighting mode:

        lm_has_changed = false;
        break;
        */
      default:
        lighting_mode = LM_DEFAULT;
        #ifdef LIGHTING_DEBUG
          Serial.println("Lighting Mode is now the default.");
        #endif
        //change variables as needed for the default state of this lighting mode:
        
        //do not set lm_has_changed to false, as it should go through the default option's setup above.
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
        //this function is controlled entirely when set up. It does not need to refresh at all.
        break;
        /* re-enable these as they get programmed...
      case LM_WIKI:
        
        break;
      case LM_SLOW_FADE:
        
        break;
      case LM_WIKI_RAINBOW:
        
        break;
      case LM_SLOW_ROTATE:
        
        break;
        */
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
