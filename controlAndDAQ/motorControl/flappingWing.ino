byte strokeDirectionPin = 8;
byte strokeStepPin = 7;
byte pitchDirectionPin = 9;
byte pitchStepPin = 6;

#define strokeDBIT (1<<22)
#define strokeSBIT (1<<23)
#define pitchDBIT (1<<21)
#define pitchSBIT (1<<24)

#define bothStepMask strokeSBIT | pitchSBIT
#define strokeStepMask strokeSBIT
#define pitchStepMask pitchSBIT
#define controlPort PIOC

double sAmp = 35.5;
double pAmp = 10;
double meanP = 6;
double meanS = 7;
double lag = -90;
double freq_Start = 2;
double freq_End = 6;
double freq_Step = 0.5;
int cyc = 70;


int cycTracker = 0;
int stopper = 0;
double dsAmp = sAmp*4800/90;
double dpAmp = pAmp*1600/90;
double L0 = sqrt(pow(dsAmp/3,2)+pow(dpAmp,2)+2*dsAmp/3*dpAmp*cos(lag*TWO_PI/360));

int posSAmp = round(dsAmp);
int posPAmp = round(L0);
double phi = asin(dpAmp*sin(lag*TWO_PI/360)/L0);
int sArrLen = posSAmp*2+1;
int pArrLen = posPAmp*2+1;
double freq_iter = 0;
bool finished = false;
double freq = 0.0;
int sPosArr[3787];
int pPosArr[1787];
double tStroke[3786];
double tPitch[1786];
double omeg = freq_Start*TWO_PI;
double pStart = round(L0*-cos(phi));

double posFrac1;
double posFrac2;

int sTrack = 0;
int pTrack = 0;

double startTime;
double currTime;

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
  int incr = 1;
  for(int i = 0; i<sArrLen; i++){
  if(i==0){
    sPosArr[i] = -posSAmp;
  }
  else{
    sPosArr[i] = sPosArr[i-1] + incr;
    }
  }

  for(int i = 0; i<pArrLen; i++){
  if(i==0){
    pPosArr[i] = pStart;
  }
  else if (i< posPAmp+pStart+1){
    pPosArr[i] = pPosArr[i-1] - incr;
  }
  else{
    pPosArr[i] = pPosArr[i-1] + incr;
    }
  }
}

void loop() {
  double freq = freq_Start;
  while(freq < freq_End+freq_Step){
    String fileName = "stA"+String(sAmp)+"piA"+String(pAmp)+"stM"+String(meanS)+"piM"+String(meanP)+"phase"+String(lag)+"freq"+String(freq);
    Serial.println(fileName);
    Serial.println(freq);
    while(Serial.available() == 0){};
    char holdChar = Serial.read();
    

    // Setting up the array containing all of the positions of the motor (in order)

    double tDel;
    omeg = freq*TWO_PI;
    for(int i = 0; i<sArrLen-1; i++){
      posFrac1 = double(sPosArr[i])/double(posSAmp);
      posFrac2 = double(sPosArr[i+1])/double(posSAmp);
      tDel = abs((acos(posFrac2)-acos(posFrac1))/omeg*1000000.0);
      if(i==0){
        tStroke[i] = tDel;
      }
      else{
        tStroke[i] = tStroke[i-1]+tDel;
      }
    }

    for(int i = 0; i<pArrLen-1; i++){
      posFrac1 = double(pPosArr[i])/double(posPAmp);
      posFrac2 = double(pPosArr[i+1])/double(posPAmp);
      tDel = abs((acos(posFrac2)-acos(posFrac1))/omeg*1000000.0);
      if(i==0){
        tPitch[i] = tDel;
      }
      else{
        tPitch[i] = tPitch[i-1]+tDel;
      }
    }
    // Serial.println(pStart+round((meanS-meanP)*1600/90));
    startPointMove(strokeDirectionPin, strokeStepPin, posSAmp-round(meanS*4800/90),"stroke");
    startPointMove(pitchDirectionPin, pitchStepPin, pStart+round((meanS-meanP)*1600/90), "pitch");
    delay(1000);
    digitalWrite(strokeDirectionPin, LOW);
    digitalWrite(pitchDirectionPin, HIGH);

    Serial.println("start");
    while(Serial.available() == 0){};
    holdChar = Serial.read();

    if(abs(pStart)!=abs(pPosArr[pArrLen-1])){
      Serial.println("Error: Pitch Position Array Incorrect.");
      while(stopper==1){

      }
    }

    startTime = micros();
    while(cycTracker<cyc*2){
      currTime = micros()-startTime;
      if (currTime>= tStroke[sTrack] && currTime >= tPitch[pTrack]){
        controlPort->PIO_SODR = bothStepMask;
        delayMicroseconds(3);
        controlPort->PIO_CODR = bothStepMask;
        sTrack++;
        pTrack++;
        if(pTrack == posPAmp+pStart){
          controlPort->PIO_ODSR ^= pitchDBIT;
        }
      }
      else if(currTime>= tStroke[sTrack]){
        controlPort->PIO_SODR = strokeStepMask;
        delayMicroseconds(4);
        controlPort->PIO_CODR = strokeStepMask;
        sTrack++;
      }
      else if(currTime>= tPitch[pTrack]){
        controlPort->PIO_SODR = pitchStepMask;
        delayMicroseconds(4);
        controlPort->PIO_CODR = pitchStepMask;
        pTrack ++;
        if(pTrack == posPAmp+pStart){
          controlPort->PIO_ODSR ^= pitchDBIT;
        }
      }
      if(sTrack-posSAmp == posSAmp ){ // || pTrack-posPAmp == posPAmp
        sTrack = 0;
        pTrack = 0;
        controlPort->PIO_ODSR ^= strokeDBIT;
        cycTracker++;
        startTime = micros();
      }
      // Serial.println(pTrack);
    }
    Serial.println("stop");
    endPointMove(strokeDirectionPin, strokeStepPin, posSAmp-round(meanS*4800/90),"stroke");
    endPointMove(pitchDirectionPin, pitchStepPin, pStart+round((meanS-meanP)*1600/90), "pitch");
    delay(1000);
    freq = freq + freq_Step;
    cycTracker = 0;
    while(Serial.available() == 0){};
    holdChar = Serial.read();
    if(freq < freq_End+freq_Step){
      Serial.println("yes");
    }
  }
  Serial.println("no");
  stopper = 1;
  while(stopper==1)
  {

  }
}

void startPointMove(byte direction, byte step, int pos, String motor){
  if(motor == "pitch"){
    digitalWrite(direction, HIGH);
  }
  else if(motor == "stroke"){
    digitalWrite(direction, HIGH);
  }
  for(int i = 0; i<abs(pos); i++){
    digitalWrite(step,HIGH);
    delayMicroseconds(200);
    digitalWrite(step,LOW);
  }
}

void endPointMove(byte direction, byte step, int pos, String motor){
  if(motor == "pitch"){
    digitalWrite(direction, LOW);
  }
  else if(motor == "stroke"){
    digitalWrite(direction, LOW);
  }
  for(int i = 0; i<abs(pos); i++){
    digitalWrite(step,HIGH);
    delayMicroseconds(200);
    digitalWrite(step,LOW);
  }
}

