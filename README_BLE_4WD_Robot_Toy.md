# BLE 4WD Robot Toy Controlled by iPhone

A DIY **4WD Bluetooth Low Energy robot toy** controlled from an **iOS SwiftUI app**, with optional **IR remote control** support.

This project uses an **Arduino Uno**, **HM-10 BLE module**, **L298N motor driver**, and a **4WD smart robot chassis**. The iPhone app sends movement commands over BLE, while the Arduino receives those commands and drives the motors.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Features](#features)
3. [System Architecture](#system-architecture)
4. [Hardware Requirements](#hardware-requirements)
5. [Compatibility Notes](#compatibility-notes)
6. [Wiring Summary](#wiring-summary)
7. [Command Protocol](#command-protocol)
8. [Arduino Firmware](#arduino-firmware)
9. [iOS SwiftUI App](#ios-swiftui-app)
10. [Build Steps](#build-steps)
11. [Testing Checklist](#testing-checklist)
12. [Troubleshooting](#troubleshooting)
13. [Future Improvements](#future-improvements)
14. [Safety Notes](#safety-notes)

---

## Project Overview

The goal of this project is to build a small **4-wheel-drive robot toy** that can be controlled from an iPhone.

The iPhone app is built using **SwiftUI** and **CoreBluetooth**. It scans for the HM-10 BLE module, connects to it, and sends simple movement commands such as `F`, `B`, `L`, `R`, and `S`.

The Arduino reads these commands through serial communication and controls the L298N motor driver. The L298N then drives the left and right motor groups of the 4WD chassis.

The project also supports an optional **IR remote control**, so the robot can be controlled without using the phone.

---

## Features

- iPhone control using Bluetooth Low Energy
- SwiftUI-based control interface
- Arduino Uno firmware
- HM-10 BLE communication
- 4WD chassis support
- L298N motor driver control
- Optional IR remote control
- Simple command protocol
- Speed levels: slow, medium, fast
- Beginner-friendly wiring and testing flow

---

## System Architecture

```text
                 ┌────────────────────┐
                 │   iPhone App        │
                 │   SwiftUI + BLE     │
                 └─────────┬──────────┘
                           │ BLE
                           ▼
                 ┌────────────────────┐
                 │   HM-10 BLE Module  │
                 │   UART Serial       │
                 └─────────┬──────────┘
                           │ Serial
                           ▼
                 ┌────────────────────┐
                 │   Arduino Uno       │
                 │   Control Logic     │
                 └─────────┬──────────┘
                           │ GPIO / PWM
                           ▼
                 ┌────────────────────┐
                 │   L298N Driver      │
                 │   Dual H-Bridge     │
                 └─────────┬──────────┘
                           │
        ┌──────────────────┴──────────────────┐
        ▼                                     ▼
┌────────────────┐                    ┌────────────────┐
│ Left Motors     │                    │ Right Motors    │
│ Front + Rear    │                    │ Front + Rear    │
└────────────────┘                    └────────────────┘
```

Optional IR control:

```text
IR Remote → IR Receiver → Arduino Uno → L298N → Motors
```

---

## Hardware Requirements

| Item | Quantity | Purpose |
|---|---:|---|
| Arduino Uno R3 compatible board | 1 | Main controller |
| HM-10 BLE module | 1 | iPhone BLE communication |
| L298N motor driver module | 1 | Drives the motors |
| 4WD robot chassis kit | 1 | Robot body and motors |
| Solderless breadboard + jumper wire combo | 1 | Prototyping connections |
| Male-to-Female jumper wires, 20cm, 40pcs | 1 pack | Arduino/module wiring |
| Female-to-Female jumper wires, 20cm, 40pcs | 1 pack | Module-to-module wiring |
| 1kΩ resistor pack | 1 pack | HM-10 voltage divider |
| 2.2kΩ resistor pack | 1 pack | HM-10 voltage divider |
| USB A-B cable | 1 | Arduino programming |
| 18650 Li-ion battery | 4 | 2 used, 2 spare/charging |
| Dual 18650 battery holder with switch | 1 | Motor battery pack |
| IR remote + TSOP receiver kit | 1 | Optional physical remote control |

---

## Compatibility Notes

### 4WD chassis with one L298N

A single L298N motor driver can control a 4WD chassis by grouping the motors by side:

```text
Left-front motor  + Left-rear motor  → L298N Motor A
Right-front motor + Right-rear motor → L298N Motor B
```

This gives tank-style steering.

### Battery voltage caution

Two 18650 batteries in series provide:

```text
Nominal voltage: 7.4V
Fully charged voltage: 8.4V
```

Many BO motors are rated around 3V to 6V. The L298N has some voltage drop, but it is still safer to start with a low PWM value.

Recommended starting speed:

```cpp
int motorSpeed = 120;
```

Increase gradually after testing.

### HM-10 RX voltage caution

Arduino Uno uses 5V logic. Many HM-10 modules use 3.3V logic.

Use a voltage divider on Arduino TX → HM-10 RX:

```text
Arduino D3 → 1kΩ resistor → HM-10 RXD
HM-10 RXD → 2.2kΩ resistor → GND
```

HM-10 TXD can usually connect directly to Arduino D2.

---

## Wiring Summary

### HM-10 to Arduino

| HM-10 Pin | Arduino Pin |
|---|---|
| VCC | 5V |
| GND | GND |
| TXD | D2 |
| RXD | D3 through voltage divider |

### L298N to Arduino

| L298N Pin | Arduino Pin |
|---|---|
| ENA | D5 |
| IN1 | D8 |
| IN2 | D9 |
| IN3 | D10 |
| IN4 | D11 |
| ENB | D6 |
| GND | GND |

### Motors to L298N

| Motor Group | L298N Output |
|---|---|
| Left front + left rear motors | OUT1, OUT2 |
| Right front + right rear motors | OUT3, OUT4 |

### Battery to L298N

| Battery Holder | L298N |
|---|---|
| Positive wire | +12V / VMS |
| Negative wire | GND |

Also connect:

```text
L298N GND → Arduino GND
```

Common ground is required.

### IR Receiver to Arduino

| IR Receiver Pin | Arduino Pin |
|---|---|
| VCC | 5V |
| GND | GND |
| Signal | D4 |

---

## Command Protocol

The robot uses single-character commands.

| Command | Action |
|---|---|
| F | Forward |
| B | Backward |
| L | Turn left |
| R | Turn right |
| S | Stop |
| 1 | Slow speed |
| 2 | Medium speed |
| 3 | Fast speed |

---

## Arduino Firmware

Create a new Arduino sketch and upload the following code.

> Install the `IRremote` library from Arduino IDE Library Manager before compiling.

```cpp
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
```

---

## iOS SwiftUI App

Create a new iOS project in Xcode:

```text
Product: iOS App
Interface: SwiftUI
Language: Swift
Minimum target: iOS 16+
```

Add this permission to `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to control the BLE robot toy.</string>
```

### BLEManager.swift

```swift
import Foundation
import CoreBluetooth

final class BLEManager: NSObject, ObservableObject {

    @Published var isBluetoothReady = false
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var statusText = "Bluetooth not ready"
    @Published var discoveredDevices: [CBPeripheral] = []

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writableCharacteristic: CBCharacteristic?

    private let hm10ServiceUUID = CBUUID(string: "FFE0")
    private let hm10CharacteristicUUID = CBUUID(string: "FFE1")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            statusText = "Bluetooth is not powered on"
            return
        }

        discoveredDevices.removeAll()
        writableCharacteristic = nil
        connectedPeripheral = nil
        isConnected = false

        statusText = "Scanning for HM-10..."
        isScanning = true

        centralManager.scanForPeripherals(
            withServices: [hm10ServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self else { return }

            if self.isScanning {
                self.stopScan()

                if self.discoveredDevices.isEmpty {
                    self.statusText = "No HM-10 device found"
                }
            }
        }
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    func connect(to peripheral: CBPeripheral) {
        stopScan()
        statusText = "Connecting to \(peripheral.displayName)"
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func send(_ text: String) {
        guard isConnected else {
            statusText = "Robot is not connected"
            return
        }

        guard let peripheral = connectedPeripheral,
              let characteristic = writableCharacteristic else {
            statusText = "Writable characteristic not found"
            return
        }

        guard let data = text.data(using: .utf8) else { return }

        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse

        peripheral.writeValue(data, for: characteristic, type: writeType)
        statusText = "Sent: \(text)"
    }
}

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothReady = true
            statusText = "Bluetooth ready"

        case .poweredOff:
            isBluetoothReady = false
            isConnected = false
            statusText = "Bluetooth is turned off"

        case .unauthorized:
            isBluetoothReady = false
            statusText = "Bluetooth permission denied"

        case .unsupported:
            isBluetoothReady = false
            statusText = "Bluetooth not supported"

        case .resetting:
            isBluetoothReady = false
            statusText = "Bluetooth resetting"

        case .unknown:
            isBluetoothReady = false
            statusText = "Bluetooth state unknown"

        @unknown default:
            isBluetoothReady = false
            statusText = "Unknown Bluetooth error"
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
        }

        statusText = "Found \(peripheral.displayName)"
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusText = "Connected. Discovering services..."
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices([hm10ServiceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        isConnected = false
        statusText = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        isConnected = false
        writableCharacteristic = nil
        statusText = "Disconnected"
    }
}

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            statusText = "Service discovery failed: \(error.localizedDescription)"
            return
        }

        guard let services = peripheral.services else { return }

        for service in services where service.uuid == hm10ServiceUUID {
            peripheral.discoverCharacteristics([hm10CharacteristicUUID], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            statusText = "Characteristic discovery failed: \(error.localizedDescription)"
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics where characteristic.uuid == hm10CharacteristicUUID {
            writableCharacteristic = characteristic
            statusText = "Robot ready"
            return
        }

        statusText = "HM-10 write characteristic not found"
    }
}

extension CBPeripheral {
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return "Unknown BLE Device"
    }
}
```

### ContentView.swift

```swift
import SwiftUI

struct ContentView: View {

    @StateObject private var bleManager = BLEManager()
    @State private var selectedSpeed = "2"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                statusView
                scanSection
                speedPicker
                Spacer()
                controlPad
                stopButton
                Spacer()
            }
            .padding()
            .navigationTitle("BLE Robot")
            .onChange(of: selectedSpeed) { _, newValue in
                bleManager.send(newValue)
            }
        }
    }

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(bleManager.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)

                Text(bleManager.isConnected ? "Connected" : "Not Connected")
                    .font(.headline)

                Spacer()
            }

            Text(bleManager.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scanSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    bleManager.startScan()
                } label: {
                    Label(
                        bleManager.isScanning ? "Scanning..." : "Scan Robot",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!bleManager.isBluetoothReady || bleManager.isScanning)

                Button {
                    bleManager.disconnect()
                } label: {
                    Image(systemName: "xmark.circle")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(!bleManager.isConnected)
            }

            if !bleManager.discoveredDevices.isEmpty && !bleManager.isConnected {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Devices")
                        .font(.headline)

                    ForEach(bleManager.discoveredDevices, id: \.identifier) { device in
                        Button {
                            bleManager.connect(to: device)
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text(device.displayName)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var speedPicker: some View {
        Picker("Speed", selection: $selectedSpeed) {
            Text("Slow").tag("1")
            Text("Medium").tag("2")
            Text("Fast").tag("3")
        }
        .pickerStyle(.segmented)
        .disabled(!bleManager.isConnected)
    }

    private var controlPad: some View {
        VStack(spacing: 16) {
            controlButton(title: "Forward", icon: "arrow.up", command: "F")

            HStack(spacing: 24) {
                controlButton(title: "Left", icon: "arrow.left", command: "L")
                controlButton(title: "Right", icon: "arrow.right", command: "R")
            }

            controlButton(title: "Backward", icon: "arrow.down", command: "B")
        }
    }

    private var stopButton: some View {
        Button {
            bleManager.send("S")
        } label: {
            Text("STOP")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 150, height: 60)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!bleManager.isConnected)
        .opacity(bleManager.isConnected ? 1 : 0.4)
    }

    private func controlButton(title: String, icon: String, command: String) -> some View {
        Button {
            bleManager.send(command)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(width: 110, height: 90)
            .background(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .disabled(!bleManager.isConnected)
        .opacity(bleManager.isConnected ? 1 : 0.4)
    }
}
```

---

## Build Steps

1. Assemble the 4WD chassis.
2. Mount all four BO motors.
3. Attach all four wheels.
4. Mount Arduino Uno, L298N, breadboard, HM-10, and battery holder.
5. Connect left-side motors together to L298N Motor A.
6. Connect right-side motors together to L298N Motor B.
7. Wire L298N control pins to Arduino.
8. Wire HM-10 to Arduino using the voltage divider.
9. Wire IR receiver to Arduino D4.
10. Connect battery holder to L298N motor input.
11. Connect all grounds together.
12. Upload Arduino firmware.
13. Build and run the iOS app on a real iPhone.
14. Scan for the HM-10 module.
15. Connect and test movement.
16. Test IR remote buttons.

---

## Testing Checklist

### Motor test

- Forward moves all wheels forward.
- Backward moves all wheels backward.
- Left turns the robot left.
- Right turns the robot right.
- Stop immediately stops all motors.

### BLE test

- HM-10 LED is powered.
- iPhone app finds HM-10.
- App connects successfully.
- Buttons send commands.
- Arduino Serial Monitor shows command values.

### IR test

- IR receiver is powered.
- Arduino Serial Monitor prints IR command values.
- Remote buttons trigger movement.
- OK button stops the robot.

---

## Troubleshooting

### Robot does not move

Check:

- Battery is charged.
- L298N motor power is connected.
- Arduino GND and L298N GND are connected.
- ENA and ENB are connected to Arduino PWM pins.
- Motor wires are properly screwed into L298N outputs.

### Robot moves in the wrong direction

Swap the motor wires for the affected side.

Example:

```text
OUT1 ↔ OUT2
```

or

```text
OUT3 ↔ OUT4
```

### iPhone cannot find HM-10

Check:

- HM-10 is powered.
- HM-10 is BLE, not HC-05 classic Bluetooth.
- Bluetooth permission is added in Info.plist.
- Test on a real iPhone, not simulator.
- Try scanning again after restarting Arduino.

### IR remote does not work

Check:

- IR receiver signal pin is connected to D4.
- IR receiver VCC is connected to 5V.
- Install the IRremote library.
- Open Serial Monitor and record actual button codes.
- Replace the example IR codes in the firmware.

---

## Future Improvements

- Add ultrasonic obstacle detection.
- Add speed slider in the iOS app.
- Add battery voltage monitoring.
- Add LED headlights.
- Add buzzer for horn sound.
- Add CoreBluetooth reconnect logic.
- Add joystick-style SwiftUI control.
- Add autonomous driving mode.
- Add encoder-based speed correction.

---

## Safety Notes

- Do not short 18650 batteries.
- Use only a proper external 18650 Li-ion charger.
- Do not leave charging batteries unattended.
- Start motor speed low when using 2x18650 cells.
- Do not power motors directly from Arduino 5V.
- Keep wires away from moving wheels.
- Switch off the battery holder when not in use.

---

## License

This project is intended for learning, robotics practice, and personal DIY use.

You may modify and extend it for your own projects.

