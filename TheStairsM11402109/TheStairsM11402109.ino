// =====================================================
// The Stairs - Arduino Controller
// 接線：
// Joystick: Vx=A1, Vy=A2, SW=D8
// Piezo:    S=D2
// Photo:    A0
//
// 1-byte packet:
// bit7    = 1
// bit6~5  = X state: 00 neutral, 01 left, 10 right
// bit4~3  = Y state: 00 neutral, 01 up,   10 down
// bit2    = Dash pulse (SW)
// bit1    = Pick pulse (Piezo)
// bit0    = Photo dark
// =====================================================

const uint8_t PIN_PHOTO   = A0;
const uint8_t PIN_JOY_X   = A1;
const uint8_t PIN_JOY_Y   = A2;
const uint8_t PIN_JOY_SW  = 8;
const uint8_t PIN_PIEZO   = 2;

// ---------------------------
// Joystick threshold
// ---------------------------
const int JOY_LEFT_TH  = 380;
const int JOY_RIGHT_TH = 640;
const int JOY_UP_TH    = 380;
const int JOY_DOWN_TH  = 640;

// ---------------------------
// Photo threshold
// 平常約500，輕微遮住約100~200 
// 測試後約50比較容易被正確觸發
// ---------------------------
const bool PHOTO_DARK_IS_LOW = true;
const int PHOTO_THRESHOLD = 50;

// ---------------------------
// Piezo logic
// 平常0，敲下去1
// ---------------------------
const bool PIEZO_ACTIVE_HIGH = true;

// ---------------------------
// Timing
// ---------------------------
const unsigned long SEND_INTERVAL_MS  = 15;
const unsigned long SW_DEBOUNCE_MS    = 120;
const unsigned long PIEZO_DEBOUNCE_MS = 180;

// ---------------------------
// States
// ---------------------------
bool prevSwState = HIGH;
bool prevPiezoState = LOW;

unsigned long lastSendTime = 0;
unsigned long lastSwEdgeTime = 0;
unsigned long lastPiezoEdgeTime = 0;

void setup() {
  pinMode(PIN_JOY_SW, INPUT_PULLUP);
  pinMode(PIN_PIEZO, INPUT);
  Serial.begin(115200);
}

void loop() {
  unsigned long now = millis();
  if (now - lastSendTime < SEND_INTERVAL_MS) return;
  lastSendTime = now;

  int joyX = analogRead(PIN_JOY_X);
  int joyY = analogRead(PIN_JOY_Y);

  // X state: 00 neutral, 01 left, 10 right
  uint8_t xState = 0;
  if (joyX < JOY_LEFT_TH) {
    xState = 1;
  } else if (joyX > JOY_RIGHT_TH) {
    xState = 2;
  }

  // Y state: 00 neutral, 01 up, 10 down
  uint8_t yState = 0;
  if (joyY < JOY_UP_TH) {
    yState = 1;
  } else if (joyY > JOY_DOWN_TH) {
    yState = 2;
  }

  // SW: INPUT_PULLUP -> 按下為 LOW
  bool swState = digitalRead(PIN_JOY_SW);
  bool dashPulse = false;

  if (prevSwState == HIGH && swState == LOW) {
    if (now - lastSwEdgeTime >= SW_DEBOUNCE_MS) {
      dashPulse = true;
      lastSwEdgeTime = now;
    }
  }
  prevSwState = swState;

  // Piezo
  bool piezoRaw = digitalRead(PIN_PIEZO);
  bool piezoState = PIEZO_ACTIVE_HIGH ? piezoRaw : !piezoRaw;
  bool pickPulse = false;

  if (prevPiezoState == LOW && piezoState == HIGH) {
    if (now - lastPiezoEdgeTime >= PIEZO_DEBOUNCE_MS) {
      pickPulse = true;
      lastPiezoEdgeTime = now;
    }
  }
  prevPiezoState = piezoState;

  // Photo
  int photoValue = analogRead(PIN_PHOTO);
  bool photoDark = PHOTO_DARK_IS_LOW ? (photoValue < PHOTO_THRESHOLD)
                                     : (photoValue > PHOTO_THRESHOLD);

  // Packet
  uint8_t packet = 0x80;
  packet |= (xState << 5);        // bits6~5
  packet |= (yState << 3);        // bits4~3
  if (dashPulse) packet |= 0x04;  // bit2
  if (pickPulse) packet |= 0x02;  // bit1
  if (photoDark) packet |= 0x01;  // bit0

  Serial.write(packet);
}