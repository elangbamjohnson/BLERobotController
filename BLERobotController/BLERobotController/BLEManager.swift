//
//  BLEManager.swift
//  BLERobotController
//
//  Created by Johnson Elangbam on 02/06/26.
//

import SwiftUI
import CoreBluetooth
import Combine
// ============================================================
// BLEMANAGER CLASS
// Manages Bluetooth Low Energy connection to HM-10 module
// ============================================================

class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    // Bluetooth Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?
    
    // Service and Characteristic UUIDs
    let serviceUUID = CBUUID(string: "FFE0")
    let charUUID = CBUUID(string: "FFE1")
    
    // Published Properties (UI Updates)
    @Published var isConnected = false
    @Published var connectionStatus = "🔴 Scanning..."
    @Published var peripheralName = "Unknown Device"
    @Published var signalStrength = 0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Initialize the Central Manager on the main thread
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Methods
    
    /// Send a command to the robot via BLE
    /// - Parameter cmd: Single character command (F, B, L, R, S)
    func send(_ cmd: String) {
        // Guard against invalid states
        guard !cmd.isEmpty else {
            print("ERROR: Empty command string")
            return
        }
        
        guard let data = cmd.data(using: .utf8) else {
            print("ERROR: Failed to convert command to data")
            return
        }
        
        guard let peripheral = peripheral else {
            print("ERROR: Peripheral not connected")
            updateStatus("🔴 Not Connected - Cannot Send Command")
            return
        }
        
        guard let txChar = txChar else {
            print("ERROR: TX Characteristic not found")
            updateStatus("🟡 Connected but Characteristic Missing")
            return
        }
        
        // Send the data via write without response (faster, no ACK needed)
        peripheral.writeValue(data, for: txChar, type: .withoutResponse)
        
        print("✅ Command sent: \(cmd)")
    }
    
    /// Disconnect from the current peripheral
    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
            self.txChar = nil
        }
    }
    
    /// Start scanning for BLE devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("ERROR: Bluetooth not powered on")
            return
        }
        
        print("🔍 Starting BLE scan...")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    /// Stop scanning for BLE devices
    func stopScanning() {
        centralManager.stopScan()
        print("⏹️ BLE scan stopped")
    }
    
    // MARK: - Private Methods
    
    /// Update connection status on main thread
    private func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.connectionStatus = status
        }
    }
    
    /// Update connection state
    private func setConnected(_ connected: Bool) {
        DispatchQueue.main.async {
            self.isConnected = connected
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    
    /// Called when the central manager's state changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on")
            updateStatus("🟢 Bluetooth ON - Scanning...")
            startScanning()
            
        case .poweredOff:
            print("⚠️ Bluetooth is powered off")
            updateStatus("⚠️ Bluetooth is OFF")
            setConnected(false)
            
        case .resetting:
            print("🔄 Bluetooth is resetting")
            updateStatus("🔄 Bluetooth Resetting...")
            
        case .unauthorized:
            print("❌ Bluetooth access not authorized")
            updateStatus("❌ Bluetooth Not Authorized")
            setConnected(false)
            
        case .unsupported:
            print("❌ Bluetooth not supported on this device")
            updateStatus("❌ Bluetooth Not Supported")
            setConnected(false)
            
        case .unknown:
            print("❓ Bluetooth state unknown")
            updateStatus("❓ Bluetooth State Unknown")
            
        @unknown default:
            print("⚠️ Unknown Bluetooth state")
        }
    }
    
    /// Called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi: NSNumber) {
        
        let deviceName = peripheral.name ?? "Unknown"
        print("🔍 Discovered device: \(deviceName) (RSSI: \(rssi))")
        
        // Store the peripheral and stop scanning
        self.peripheral = peripheral
        self.peripheralName = deviceName
        self.signalStrength = rssi.intValue
        
        // Update status
        updateStatus("🟡 Connecting to \(deviceName)...")
        
        // Stop scanning to save power
        centralManager.stopScan()
        
        // Attempt to connect
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Called when successfully connected to a peripheral
    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        
        print("✅ Connected to: \(peripheral.name ?? "Unknown")")
        
        // Set the peripheral delegate to receive callbacks
        peripheral.delegate = self
        
        // Update status
        updateStatus("🟡 Connected - Discovering Services...")
        
        // Discover the services we're interested in
        peripheral.discoverServices([serviceUUID])
    }
    
    /// Called when connection fails
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        
        print("❌ Failed to connect to \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("   Error: \(error.localizedDescription)")
        }
        
        updateStatus("❌ Connection Failed - Retrying...")
        
        // Try reconnecting
        setConnected(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startScanning()
        }
    }
    
    /// Called when disconnected from a peripheral
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        
        print("⚠️ Disconnected from: \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("   Error: \(error.localizedDescription)")
        }
        
        setConnected(false)
        updateStatus("🔴 Disconnected - Scanning...")
        
        // Clear stored references
        self.peripheral = nil
        self.txChar = nil
        
        // Resume scanning
        startScanning()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    
    /// Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        
        if let error = error {
            print("❌ Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }
        
        print("✅ Found \(services.count) service(s)")
        
        // Discover characteristics for all services
        for service in services {
            print("   Service: \(service.uuid)")
            peripheral.discoverCharacteristics([charUUID], for: service)
        }
        
        updateStatus("🟡 Connected - Discovering Characteristics...")
    }
    
    /// Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        if let error = error {
            print("❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found for service")
            return
        }
        
        print("✅ Found \(characteristics.count) characteristic(s)")
        
        // Look for our TX characteristic
        for characteristic in characteristics {
            if characteristic.uuid == charUUID {
                self.txChar = characteristic
                print("✅ Found TX characteristic!")
                
                // We're ready to send commands
                setConnected(true)
                updateStatus("🟢 Connected")
                
                return
            }
        }
        
        print("❌ TX characteristic not found")
        updateStatus("❌ Required Characteristic Not Found")
    }
    
    /// Called when a value is updated (for read/notify characteristics)
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if let error = error {
            print("❌ Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("⚠️ No data received")
            return
        }
        
        if let stringValue = String(data: data, encoding: .utf8) {
            print("📨 Received: \(stringValue)")
        }
    }
    
    /// Called when write completes (if write with response)
    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if let error = error {
            print("❌ Error writing to characteristic: \(error.localizedDescription)")
        } else {
            print("✅ Write successful")
        }
    }
    
    /// Called when peripheral signals updated RSSI (signal strength)
    func peripheral(_ peripheral: CBPeripheral,
                    didReadRSSI RSSI: NSNumber,
                    error: Error?) {
        
        if let error = error {
            print("⚠️ Error reading RSSI: \(error.localizedDescription)")
        } else {
            DispatchQueue.main.async {
                self.signalStrength = RSSI.intValue
                print("📶 Signal Strength: \(RSSI) dBm")
            }
        }
    }
}

// MARK: - Debugging/Utility Methods

extension BLEManager {
    
    /// Get human-readable signal strength
    var signalStrengthDescription: String {
        switch signalStrength {
        case 0:
            return "Unknown"
        case -40...0:
            return "Excellent"
        case -67...(-41):
            return "Good"
        case -80...(-68):
            return "Fair"
        default:
            return "Poor"
        }
    }
    
    /// Get connection state summary
    var connectionSummary: String {
        """
        BLE Manager Status:
        - Connected: \(isConnected)
        - Status: \(connectionStatus)
        - Device: \(peripheralName)
        - Signal: \(signalStrength) dBm (\(signalStrengthDescription))
        - TX Ready: \(txChar != nil)
        """
    }
    
    /// Print full debug information
    func printDebugInfo() {
        print("\n========== BLE DEBUG INFO ==========")
        print(connectionSummary)
        print("===================================\n")
    }
}
