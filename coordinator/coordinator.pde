#include <NewSoftSerial.h>

// hard-coded constants that are user-editable
const int BUFFER_SIZE = 128;
const int MAX_PROJECTS = 10;

// hard-coded constants that will never change
const char START_MSG = 2;  // STX
const char END_MSG = 3;    // ETX
const char SEPARATOR = 31; // US
const char PRINTABLE_START_MSG = 123; // {
const char PRINTABLE_END_MSG = 125;   // }
const char PRINTABLE_SEPARATOR = 124; // |

// other global variables
NewSoftSerial xbee =  NewSoftSerial(2, 3);

// variables used by the receive parsing
boolean receiveInProgress;
char buffer[3][BUFFER_SIZE];
int activeBuffer;
int bufferPos;

// variables used by project list
char publicKeys[MAX_PROJECTS][40];
char privateKeys[MAX_PROJECTS][40];
int numProjects = 0;

void setup() {
  Serial.begin(9600);
  xbee.begin(9600);
  
  receiveInProgress = false;
  bufferPos = 0;
  activeBuffer = 0;
}

void loop() {
  // Monitor xbee, wait for START_MSG character to be received
  // When it is, start reading from serial port and copy to buffer.
  // Every time SEPARATOR is received, null-terminate the current row,
  // and write to the next one. Continue until END_MSG is received.
  
  if(xbee.available()) {
    byte val = xbee.read();
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
  } // end of if(xbee.available())
}

void parseMessage(char* buffer1, char* buffer2, char* buffer3) {
  // Cases we need to handle:
  // R = Add public/private pair to project list
  // Q = Respond with number of projects
  // G = Respond with public/private pair for given index
  // S = Don't do anything. But print debug message to console anyways
  char command = buffer1[0];
  if(command == 'R') {
    Serial.println("command=R");
    // buffer2 = public key. buffer3 = private key
    
    // We need to check if we already have that public key registered.
    // If we do, then ignore the message and do nothing
    for(int i = 0; i < numProjects; i++) {
      int cmpeval = strcmp(publicKeys[i], buffer2);
      if(cmpeval == 0) {
        Serial.print("    matched slot ");
        Serial.println(i);
        return;
      }
    }
    
    // If we're here, then it's a new project and we need to store the keypair
    if(numProjects == MAX_PROJECTS) {
      Serial.println("    Can't add, max projects reached.");
      return;
    }
    
    int slotToUse = numProjects;
    numProjects++;
    strcpy(publicKeys[slotToUse], buffer2);
    strcpy(privateKeys[slotToUse], buffer3);
    
    Serial.print("    slotToUse=");
    Serial.println(slotToUse);
    Serial.print("    publicKey=");
    Serial.println(publicKeys[slotToUse]);
    Serial.print("    privateKey=");
    Serial.println(privateKeys[slotToUse]);
  }
  else if(command == 'Q') {
    Serial.println("command=Q");
    // respond with <START_MSG>N<SEPARATOR>[numProjects]<END_MSG>
    xbee.print(START_MSG);
    xbee.print('N');
    xbee.print(SEPARATOR);
    xbee.print(numProjects);
    xbee.print(END_MSG);
    Serial.print("    numProjects=");
    Serial.println(numProjects);
  }
  else if(command == 'G') {
    Serial.println("command=G");
    // buffer2 is index into publicKeys & privateKeys arrays
    int slotToUse = atoi(buffer2);
    if(slotToUse < 0 || slotToUse >= numProjects) {
      Serial.println("    Can't respond, index out of bounds.");
      return;
    }
    // respond with <START_MSG>I<SEPARATOR>[publicKey]<SEPARATOR>[privateKey]<END_MSG>
    xbee.print(START_MSG);
    xbee.print('I');
    xbee.print(SEPARATOR);
    xbee.print(publicKeys[slotToUse]);
    xbee.print(SEPARATOR);
    xbee.print(privateKeys[slotToUse]);
    xbee.print(END_MSG);
    Serial.print("    slotToUse=");
    Serial.println(slotToUse);
    Serial.print("    publicKey=");
    Serial.println(publicKeys[slotToUse]);
    Serial.print("    privateKey=");
    Serial.println(privateKeys[slotToUse]);
  }
  else if(command == 'S') {
    Serial.println("command=S");
    Serial.print("    publicKey=");
    Serial.println(buffer2);
    Serial.print("    status=");
    Serial.println(buffer3);
  }
}

