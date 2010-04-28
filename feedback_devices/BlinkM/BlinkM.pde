#include <BlinkM_funcs.h>
#include <Wire.h>

// hard-coded constants that are user-editable
const char PUBLIC_KEY[] = "abcd";
const char PRIVATE_KEY[] = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef";
byte ADDR = 0x09; // BlinkM's I2C address
const int BUFFER_SIZE = 128;

// hard-coded constants that will never change
const char START_MSG = 2;  // STX
const char END_MSG = 3;    // ETX
const char SEPARATOR = 31; // US
const char PRINTABLE_START_MSG = 123; // {
const char PRINTABLE_END_MSG = 125;   // }
const char PRINTABLE_SEPARATOR = 124; // |

// variables used by the receive parsing
boolean receiveInProgress;
char buffer[3][BUFFER_SIZE];
int activeBuffer;
int bufferPos;

// timekeeping for (re)sending ProjectInfo
unsigned long statusReceivedAt = 0;
const unsigned long TIMEOUT_INTERVAL = 75000; // 75 seconds

void setup() {
  Serial.begin(9600);
  BlinkM_begin();
  
  delay(1000);
  sendProjectInfo();
  
  receiveInProgress = false;
  bufferPos = 0;
  activeBuffer = 0;
}

void loop() {
  // Monitor Serial, wait for START_MSG character to be received
  // When it is, start reading from serial port and copy to buffer.
  // Every time SEPARATOR is received, null-terminate the current row,
  // and write to the next one. Continue until END_MSG is received.
  
  if(Serial.available()) {
    byte val = Serial.read();
    if(receiveInProgress) {
      if(val == SEPARATOR || val == PRINTABLE_SEPARATOR) {
        buffer[activeBuffer][bufferPos] = 0; // null-terminate the current row
        activeBuffer++;
        bufferPos = 0;
      }
      else if(val == END_MSG || val == PRINTABLE_END_MSG) {
        // pass message off to parser
        buffer[activeBuffer][bufferPos] = 0; // null-terminate the string
        receiveInProgress = false;
        parseMessage(buffer[0], buffer[1], buffer[2]);
      }
      else {
        // we're in the middle of receiving a text segment
        buffer[activeBuffer][bufferPos] = val;
        bufferPos++; 
      }
    }
    // no receive in progress
    else {
      if(val == START_MSG || val == PRINTABLE_START_MSG) {
        // start reading in a new message
        receiveInProgress = true;
        bufferPos = 0; 
        activeBuffer = 0;
        buffer[0][0] = 0;
        buffer[1][0] = 0;
        buffer[2][0] = 0;
      }
      else {
        // ignore garbage
      }
    }
  } // end of if(Serial.available())
  
  // check if we need to resend project info
  unsigned long currentTime = millis();
  if(!receiveInProgress && (currentTime - statusReceivedAt > TIMEOUT_INTERVAL)) {
    startup(); // reset BlinkM to initial state
    sendProjectInfo();
    statusReceivedAt = currentTime; // otherwise we'll keep sending it every time through loop()
  }
}

void parseMessage(char* buffer1, char* buffer2, char* buffer3) {
  // The only messages we care about are if buffer1 == "S" and if
  // buffer2 == our public key. Then we treat buffer3 as our new status.
  
  char command = buffer1[0];
  if(command == 'S') {
    // buffer2 = public key. buffer3 = status
    if(strcmp(buffer2, PUBLIC_KEY) == 0) {
      statusReceivedAt = millis(); // record when we got this status message
      switch(buffer3[0]) {
        case 'S':
          success();
          break;
        case 'F':
          failure();
          break;
        case 'R':
          running();
          break;
        case 'E':
          error();
          break;
        case 'N':
          noBuildYet();
          break;
      }
    }
  }
}

void sendProjectInfo() {
  Serial.print(START_MSG);
  Serial.print('R');
  Serial.print(SEPARATOR);
  Serial.print(PUBLIC_KEY);
  Serial.print(SEPARATOR);
  Serial.print(PRIVATE_KEY);
  Serial.print(END_MSG);
}

// BlinkM methods

void success() {
  BlinkM_stopScript(ADDR);
  BlinkM_fadeToRGB(ADDR, 0x00, 0xff, 0x00); // green
}

void failure() {
  BlinkM_stopScript(ADDR);
  BlinkM_fadeToRGB(ADDR, 0xff, 0x00, 0x00); // red
}

void running() {
  BlinkM_stopScript(ADDR);
  BlinkM_fadeToRGB(ADDR, 0xff, 0xff, 0x00); // yellow
}

void error() {
  BlinkM_stopScript(ADDR);
  BlinkM_fadeToRGB(ADDR, 0x00, 0x00, 0xff); // blue
}

void noBuildYet() {
  BlinkM_stopScript(ADDR);
  BlinkM_fadeToRGB(ADDR, 0xff, 0x00, 0xff); // purple
}

void startup() {
  BlinkM_playScript(ADDR, 0, 0, 0); // mini-script 1, blinking white
}
