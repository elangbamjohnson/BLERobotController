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
15. [Known Limitations](#known-limitations)
16. [Repository Layout](#repository-layout)
17. [License](#license)

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
- Automatic BLE discovery, connection, and rescanning after disconnect
- Manual D-pad and Forward / Back / Stop quick actions
- Voice mode with English speech transcription (command dispatch is unfinished)
- Firmware speed levels: slow, medium, fast (not exposed in the current app)
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

The robot uses single-character commands. Send exactly the character, without a newline. Unknown BLE characters (including line endings) stop the motors. Unknown IR codes are ignored.

| Command | Action |
|---|---|
| F | Forward |
| B | Backward |
| L | Turn left |
| R | Turn right |
| S | Stop |
| 1 | Set slow speed: PWM 120 (startup default) |
| 2 | Set medium speed: PWM 160 |
| 3 | Set fast speed: PWM 190 |

---

Speed commands update the stored speed; PWM changes on the next movement command. The current iOS interface sends only movement and stop commands, not `1`, `2`, or `3`.

## Arduino Firmware

Open the existing sketch: [BLE_4WD_Robot.ino](Arduino/BLE_4WD_Robot/BLE_4WD_Robot.ino).

1. Install the `IRremote` library using Arduino IDE Library Manager. The sketch uses the `IRremote.hpp` / `IrReceiver` API; no library version is pinned in this repository.
2. Select Arduino Uno and the connected board's port, then upload the sketch.
3. Open Serial Monitor at **9600 baud**. The HM-10 UART is also configured for **9600 baud** in the sketch; its module configuration must match.
4. For optional IR hardware, record your remote's command codes and adjust `readIRCommand()`. The sketch always includes and initializes IRremote, so the library is required even without an IR receiver.

The current IR mapping is:

| Button | IR code | BLE-equivalent command |
|---|---|---|
| Up | `0x18` | `F` |
| Down | `0x52` | `B` |
| Left | `0x08` | `L` |
| Right | `0x5A` | `R` |
| OK | `0x1C` | `S` |

The sketch is the source of truth for firmware behavior and wiring constants.

---

## iOS SwiftUI App

Open the existing [Xcode project](BLERobotController/BLERobotController.xcodeproj); do not create a new project or replace the source with older README examples.

### Project configuration

- The project records Xcode **26.5** as its creation version. Use Xcode with an SDK supporting the configured iOS **26.5** deployment target.
- The app uses SwiftUI, CoreBluetooth, Combine, Speech, and AVFoundation; no external app package dependencies are declared.
- Swift language version is configured as **5.10**.
- The project also lists macOS **26.3** and visionOS **26.5** targets. These settings do not establish working support on those platforms; the implementation uses `AVAudioSession` without platform guards. Use an iPhone destination for the documented workflow.
- Choose your own development team under **Signing & Capabilities** and adjust the bundle identifier if required for provisioning. The checked-in identifier is `com.personal.BLERobotController`.

Xcode generates `Info.plist`. These permission descriptions already exist in both Debug and Release build settings:

| Generated Info.plist key | Purpose |
|---|---|
| `NSBluetoothAlwaysUsageDescription` | Connect to the BLE robot |
| `NSMicrophoneUsageDescription` | Record voice input |
| `NSSpeechRecognitionUsageDescription` | Transcribe voice input |

### Connection and manual control

[BLEManager.swift](BLERobotController/BLERobotController/BLEManager.swift) starts scanning when Bluetooth is powered on, filters for service **FFE0**, and automatically connects to the first discovered matching peripheral. There is no device picker or scan button in the current interface.

The manager discovers characteristic **FFE1**, then marks the robot connected. Commands are written as UTF-8 using **write without response**. The module must support that write mode; the manager does not check characteristic write properties or fall back to writes with response.

After a disconnect, scanning resumes automatically. Failed connections schedule another scan after two seconds. The manager has a `disconnect()` method, but the current UI does not expose it, and the disconnect callback resumes scanning.

[ContentView.swift](BLERobotController/BLERobotController/ContentView.swift) provides:

- A connection status badge and connected device name.
- Manual and Voice mode selection.
- A manual D-pad for `F`, `B`, `L`, `R`, and `S`.
- Forward, Back, and Stop quick actions and transient last-command feedback.

Buttons send a command on tap. Releasing a button does not send Stop. The interface has no speed picker; the firmware starts at PWM **120**.

### Voice mode: current implementation

`SpeechRecognitionManager` is defined in `ContentView.swift`. It requests speech authorization, uses the **en-US** recognizer, and displays partial transcriptions after tapping **TAP TO SPEAK**. Tapping again or switching to Manual stops listening.

**Voice control is incomplete:** changes to recognized text do not invoke `sendCommand()` or send a BLE command. The parser exists, but the voice UI currently only transcribes speech.

The parser also checks the broad substrings `go` and `move` for Forward before checking other directions. Consequently, phrases shown in the UI such as “go left”, “go right”, and “go back” currently parse as Forward if the parser is called. Fix dispatch and parsing before relying on voice operation.

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
9. If using IR control, wire the receiver to Arduino D4.
10. Connect battery holder to L298N motor input.
11. Connect all grounds together.
12. Upload the existing Arduino sketch using the setup above.
13. Open the existing Xcode project, configure signing, select the `BLERobotController` scheme, and build/run on a real iPhone running iOS 26.5 or later.
14. Allow Bluetooth access and wait for automatic discovery and connection to the HM-10.
15. Use Manual mode to test movement and Stop with the wheels raised.
16. If installed, test IR remote buttons. Voice mode can be checked for transcription after granting microphone and speech permissions; it does not yet drive the robot.

---

## Testing Checklist

These are manual verification steps, not recorded test results. The XCTest targets contain template unit tests and app-launch/performance/screenshot tests; there are no functional BLE, voice-parser, or firmware assertions.

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
- Manual buttons send commands; confirm receipt in Serial Monitor rather than relying on the app checkmark.
- Disconnecting the BLE link causes the app to resume scanning.
- Arduino Serial Monitor shows command values.

### Voice interface test

- Grant microphone and speech recognition access.
- Select Voice, tap the microphone, and check the displayed transcription.
- Tap again or switch to Manual to stop listening.
- Voice-to-BLE dispatch remains unimplemented; see [Known Limitations](#known-limitations).

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
- Bluetooth access is allowed; its usage description is already configured in the generated Info.plist.
- The module advertises service FFE0 and exposes characteristic FFE1 with write-without-response support.
- Test on a real iPhone, not simulator.
- Restart the app or robot if discovery stalls; scanning starts automatically when Bluetooth is powered on.

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
- Expose firmware speed commands in the iOS app.
- Add battery voltage monitoring.
- Add LED headlights.
- Add buzzer for horn sound.
- Improve existing automatic rescanning with device selection, discovery error recovery, and write-property validation.
- Complete voice-to-BLE dispatch and fix voice-command parsing.
- Add a firmware command timeout and app lifecycle stop handling.
- Add functional tests for command parsing and connection behavior.
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

## Known Limitations

- **No automatic motor stop on connection loss:** the firmware has no command timeout or BLE link-state handling. Movement continues until a Stop/unknown BLE command, another movement command, reset, or power-off. The app does not send Stop when backgrounded or when listening ends.
- **UI feedback is not robot confirmation:** manual buttons remain enabled while disconnected, and the feedback checkmark can appear even when `BLEManager.send()` fails. Writes use no response and the firmware sends no app-level acknowledgement.
- Voice transcription is implemented, but command dispatch is missing and parser precedence is incorrect for several displayed phrases.
- No speed control is exposed in the app, although the firmware accepts speed commands.
- Discovery errors are largely logged; there is no explicit discovery timeout or complete recovery flow. RSSI is captured at discovery, with no periodic polling or signal indicator in the current UI.
- Automated tests do not verify robot functionality. Physical-device and hardware testing are required to establish operation.

---

## Repository Layout

| Path | Contents |
|---|---|
| [Arduino/BLE_4WD_Robot/BLE_4WD_Robot.ino](Arduino/BLE_4WD_Robot/BLE_4WD_Robot.ino) | BLE/IR command handling and motor control |
| [BLERobotController/BLERobotController.xcodeproj](BLERobotController/BLERobotController.xcodeproj) | Build targets, signing, deployment versions, and permissions |
| [BLERobotControllerApp.swift](BLERobotController/BLERobotController/BLERobotControllerApp.swift) | SwiftUI app entry point |
| [BLEManager.swift](BLERobotController/BLERobotController/BLEManager.swift) | BLE discovery, connection, writes, and debug utilities |
| [ContentView.swift](BLERobotController/BLERobotController/ContentView.swift) | Manual/voice interface and speech recognition manager |
| [BLERobotControllerTests](BLERobotController/BLERobotControllerTests) | Template unit/performance tests |
| [BLERobotControllerUITests](BLERobotController/BLERobotControllerUITests) | Launch, performance, and screenshot tests |

---

## License

This project is intended for learning, robotics practice, and personal DIY use.

You may modify and extend it for your own projects.

