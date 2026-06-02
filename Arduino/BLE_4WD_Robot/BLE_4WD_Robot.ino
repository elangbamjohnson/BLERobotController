#include <SoftwareSerial.h>
#include <IRremote.hpp>

// HM-10 BLE module
// HM-10 TXD -> Arduino D2
// HM-10 RXD -> Arduino D3 through voltage divider
SoftwareSerial bleSerial(2, 3);

// IR receiver
#define IR_RECEIVE_PIN 4

// L298N pins
#define ENA 5
#define ENB 6
#define IN1 8
#define IN2 9
#define IN3 10
#define IN4 11

int motorSpeed = 120;

void setup() {
  Serial.begin(9600);
  bleSerial.begin(9600);

  IrReceiver.begin(IR_RECEIVE_PIN, ENABLE_LED_FEEDBACK);

  pinMode(ENA, OUTPUT);
  pinMode(ENB, OUTPUT);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);

  stopMotors();

  Serial.println("BLE + IR 4WD Robot Ready");
}

void loop() {
  readBLECommand();
  readIRCommand();
}

void readBLECommand() {
  if (bleSerial.available()) {
    char command = bleSerial.read();
    Serial.print("BLE Command: ");
    Serial.println(command);
    handleCommand(command);
  }
}

void readIRCommand() {
  if (IrReceiver.decode()) {
    uint32_t command = IrReceiver.decodedIRData.command;

    Serial.print("IR Command: ");
    Serial.println(command, HEX);

    // These values may differ depending on your remote.
    // Open Serial Monitor and press remote buttons to map your own codes.
    switch (command) {
      case 0x18: // Up
        handleCommand('F');
        break;

      case 0x52: // Down
        handleCommand('B');
        break;

      case 0x08: // Left
        handleCommand('L');
        break;

      case 0x5A: // Right
        handleCommand('R');
        break;

      case 0x1C: // OK
        handleCommand('S');
        break;

      default:
        break;
    }

    IrReceiver.resume();
  }
}

void handleCommand(char command) {
  switch (command) {
    case 'F':
      forward();
      break;

    case 'B':
      backward();
      break;

    case 'L':
      left();
      break;

    case 'R':
      right();
      break;

    case 'S':
      stopMotors();
      break;

    case '1':
      motorSpeed = 120;
      Serial.println("Speed: Slow");
      break;

    case '2':
      motorSpeed = 160;
      Serial.println("Speed: Medium");
      break;

    case '3':
      motorSpeed = 190;
      Serial.println("Speed: Fast");
      break;

    default:
      stopMotors();
      break;
  }
}

void forward() {
  analogWrite(ENA, motorSpeed);
  analogWrite(ENB, motorSpeed);

  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);

  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
}

void backward() {
  analogWrite(ENA, motorSpeed);
  analogWrite(ENB, motorSpeed);

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);

  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void left() {
  analogWrite(ENA, motorSpeed);
  analogWrite(ENB, motorSpeed);

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);

  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
}

void right() {
  analogWrite(ENA, motorSpeed);
  analogWrite(ENB, motorSpeed);

  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);

  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void stopMotors() {
  analogWrite(ENA, 0);
  analogWrite(ENB, 0);

  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}
