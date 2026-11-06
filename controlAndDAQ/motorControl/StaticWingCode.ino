byte strokeDirectionPin = 8;
byte strokeStepPin = 7;
byte pitchDirectionPin = 9;
byte pitchStepPin = 6;

int startPos = -356;
int stepSize = 18;
int endPos = 506;
int measTime = 30;

String baseName = "Check0012,R1,";

int tracker = -1;
int stopper = 0;

void setup() {
  pinMode(strokeDirectionPin, OUTPUT);
  pinMode(strokeStepPin, OUTPUT);
  pinMode(pitchDirectionPin, OUTPUT);
  pinMode(pitchStepPin, OUTPUT);

  Serial.begin(9600);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for native USB port only
  }
  // Serial.println(posPAmp);
  // Serial.println(pStart);
  char startChar;
  while (true){
    Serial.println("Start Motion? y or n");
    delay(10);
    while (Serial.available() ==0){

    }
    startChar = Serial.read();
    if(startChar == 'n'){
      Serial.println("Reset Arduino to Choose Again.");
      stopper = 1;
      while(stopper == 1){
      }
    }
    else if(startChar == 'y'){
      break;
    }
  }
}

void loop() {
  int currPos = startPos+tracker*stepSize;
  String fileName;
  while (currPos < endPos){
    tracker ++;
    currPos = startPos+tracker*stepSize;
    if (abs(currPos)<10){
      if(currPos < 0){
        fileName = baseName+"-00"+String(abs(currPos));
      }
      else{
        fileName = baseName+"00"+String(currPos);
      }
    }
    else if (abs(currPos)<100 && abs(currPos)>=10){
      if(currPos < 0){
        fileName = baseName+"-0"+String(abs(currPos));
      }
      else{
        fileName = baseName+"0"+String(currPos);
      }
    }
    else{
      fileName = baseName+String(currPos);
    }
    
    Serial.println(fileName);
    while(Serial.available() == 0){};
    char holdChar = Serial.read();
    

    // Serial.println(pStart+round((meanS-meanP)*1600/90));
    startPointMove(pitchDirectionPin,pitchStepPin, currPos);

    delay(3000);

    Serial.println("start");
    while(Serial.available() == 0){};
    holdChar = Serial.read();

    delay(measTime*1000);

    Serial.println("stop");
    delay(1000);

    endPointMove(pitchDirectionPin,pitchStepPin, currPos);

    delay(3000);
    while(Serial.available() == 0){};
    holdChar = Serial.read();
    if(currPos < endPos){
      Serial.println("yes");
    }
  }
  Serial.println("no");
  
  stopper = 1;
  while(stopper==1)
  {

  }
}

void startPointMove(byte direction, byte step, int pos){
  if (pos >= 0){
    digitalWrite(direction,HIGH);
  }
  else{
    digitalWrite(direction, LOW);
  }
  for(int i = 0; i<abs(pos); i++){
    digitalWrite(step,HIGH);
    delayMicroseconds(200);
    digitalWrite(step,LOW);
  }
}

void endPointMove(byte direction, byte step, int pos){
  if (pos >= 0){
    digitalWrite(direction,LOW);
  }
  else{
    digitalWrite(direction, HIGH);
  }
  for(int i = 0; i<abs(pos); i++){
    digitalWrite(step,HIGH);
    delayMicroseconds(200);
    digitalWrite(step,LOW);
  }
}

