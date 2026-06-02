import SwiftUI
import CoreBluetooth
import Speech
import AVFoundation
import Combine

// ============================================================
// SPEECH RECOGNITION MANAGER CLASS
// Handles voice command recognition and parsing
// ============================================================

class SpeechRecognitionManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    @Published var lastCommand: String?
    @Published var lastCommandTime = Date()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        requestSpeechAuthorization()
    }
    
    // MARK: - Public Methods
    
    /// Request user authorization for speech recognition
    func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.authorizationStatus = authStatus
                
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    print("❌ Speech recognition denied")
                case .restricted:
                    print("⚠️ Speech recognition restricted")
                case .notDetermined:
                    print("⏳ Speech recognition not determined")
                @unknown default:
                    print("❓ Unknown speech recognition status")
                }
            }
        }
    }
    
    /// Start listening for voice input
    func startListening() {
        // Check if already listening
        if recognitionTask != nil {
            stopListening()
            return
        }
        
        guard authorizationStatus == .authorized else {
            print("❌ Speech not authorized. Current status: \(authorizationStatus)")
            DispatchQueue.main.async { self.recognizedText = "Speech not authorized" }
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("❌ Speech recognizer unavailable for this locale")
            DispatchQueue.main.async { self.recognizedText = "Speech recognizer unavailable" }
            return
        }
        
        if audioEngine.isRunning {
            print("ℹ️ Audio engine already running; stopping then restarting")
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        print("🎤 Starting voice recognition...")
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session error: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create SFSpeechAudioBufferRecognitionRequest")
            return
        }
        
        // Allow partial results so we can show text while user is speaking
        recognitionRequest.shouldReportPartialResults = true
        
        // Optional: Set task hint for better recognition
        recognitionRequest.taskHint = .dictation
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            // Process result
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
                
                print("🎙️ Recognized: \(result.bestTranscription.formattedString)")
            }
            
            // Handle completion or error
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isListening = false
                    print("✅ Voice recognition stopped")
                }
            }
        }
        
        // Setup audio input node
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        // Start audio engine
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.recognizedText = "Listening... speak now"
                print("✅ Audio engine started")
            }
        } catch {
            print("❌ Audio engine error: \(error)")
        }
    }
    
    /// Stop listening for voice input
    func stopListening() {
        print("⏹️ Stopping voice recognition...")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    /// Parse voice command from recognized text
    /// - Parameter text: The recognized text from speech
    /// - Returns: Single character command (F, B, L, R, S) or nil if not recognized
    func parseVoiceCommand(_ text: String) -> String? {
        let lowerText = text.lowercased().trimmingCharacters(in: .whitespaces)
        
        print("🔍 Parsing command: '\(lowerText)'")
        
        // FORWARD commands
        if lowerText.contains("forward") ||
           lowerText.contains("go forward") ||
           lowerText.contains("ahead") ||
           lowerText.contains("move forward") ||
           lowerText.contains("move") ||
           lowerText.contains("go") {
            print("✅ Parsed as: FORWARD")
            return "F"
        }
        
        // BACKWARD commands
        if lowerText.contains("backward") ||
           lowerText.contains("go back") ||
           lowerText.contains("back up") ||
           lowerText.contains("reverse") ||
           lowerText.contains("back") {
            print("✅ Parsed as: BACKWARD")
            return "B"
        }
        
        // LEFT commands
        if lowerText.contains("left") ||
           lowerText.contains("go left") ||
           lowerText.contains("turn left") ||
           lowerText.contains("left turn") {
            print("✅ Parsed as: LEFT")
            return "L"
        }
        
        // RIGHT commands
        if lowerText.contains("right") ||
           lowerText.contains("go right") ||
           lowerText.contains("turn right") ||
           lowerText.contains("right turn") {
            print("✅ Parsed as: RIGHT")
            return "R"
        }
        
        // STOP commands
        if lowerText.contains("stop") ||
           lowerText.contains("halt") ||
           lowerText.contains("pause") ||
           lowerText.contains("freeze") ||
           lowerText.contains("quit") ||
           lowerText.contains("end") {
            print("✅ Parsed as: STOP")
            return "S"
        }
        
        print("❌ No command matched")
        return nil
    }
    
    /// Process recognized text and return command label
    func processRecognizedText() -> String? {
        guard !recognizedText.isEmpty else { return nil }
        
        let command = parseVoiceCommand(recognizedText)
        if let cmd = command {
            DispatchQueue.main.async {
                self.lastCommand = cmd
                self.lastCommandTime = Date()
            }
        }
        return command
    }
}

// ============================================================
// MAIN CONTENT VIEW
// Complete UI with manual and voice control
// ============================================================

struct ContentView: View {
    
    // MARK: - State Variables
    
    @StateObject var bleManager = BLEManager()
    @StateObject var speechManager = SpeechRecognitionManager()
    
    @State private var showVoiceMode = false
    @State private var commandFeedback = ""
    @State private var feedbackOpacity = 0.0
    @State private var lastCommandLabel = ""
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.1, green: 0.12, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ===== HEADER SECTION =====
                headerSection()
                
                // ===== CONTROL MODE SELECTOR =====
                modeSelector()
                
                // ===== SPACER =====
                Spacer()
                
                // ===== MAIN CONTROL SECTION =====
                if showVoiceMode {
                    voiceControlSection()
                } else {
                    manualControlSection()
                }
                
                // ===== COMMAND FEEDBACK =====
                if !commandFeedback.isEmpty {
                    feedbackSection()
                }
                
                // ===== SPACER =====
                Spacer()
                
                // ===== FOOTER =====
                footerSection()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Header with title and connection status
    @ViewBuilder
    func headerSection() -> some View {
        VStack(spacing: 10) {
            Text("🤖 BLE ROBOT CONTROL")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            // Connection Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(bleManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 1), value: bleManager.isConnected)
                
                Text(bleManager.connectionStatus)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                if bleManager.isConnected {
                    Text("\(bleManager.peripheralName)")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(10)
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    /// Mode selector buttons (Manual/Voice)
    @ViewBuilder
    func modeSelector() -> some View {
        VStack(spacing: 12) {
            Text("SELECT MODE")
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                // Manual Mode Button
                Button(action: {
                    showVoiceMode = false
                    speechManager.stopListening()
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Manual")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(showVoiceMode ? .gray : .white)
                    .background(showVoiceMode ? Color.black.opacity(0.2) : Color.cyan.opacity(0.3))
                    .cornerRadius(12)
                }
                
                // Voice Mode Button
                Button(action: {
                    showVoiceMode = true
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "microphone.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Voice")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(!showVoiceMode ? .gray : .white)
                    .background(!showVoiceMode ? Color.black.opacity(0.2) : Color.cyan.opacity(0.3))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    /// Manual control with D-pad
    @ViewBuilder
    func manualControlSection() -> some View {
        VStack(spacing: 20) {
            // D-Pad
            VStack(spacing: 12) {
                // Up Button
                Button(action: { sendCommand("F", label: "FORWARD ⬆️") }) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 65, height: 65)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                                )
                        )
                }
                
                // Left, Stop, Right Row
                HStack(spacing: 12) {
                    Button(action: { sendCommand("L", label: "LEFT ⬅️") }) {
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 22, weight: .bold))
                            .frame(width: 65, height: 65)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.cyan.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                                    )
                            )
                    }
                    
                    Button(action: { sendCommand("S", label: "STOP ⏹️") }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22, weight: .bold))
                            .frame(width: 65, height: 65)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.6), lineWidth: 2)
                                    )
                            )
                    }
                    
                    Button(action: { sendCommand("R", label: "RIGHT ➡️") }) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 22, weight: .bold))
                            .frame(width: 65, height: 65)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.cyan.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                                    )
                            )
                    }
                }
                
                // Down Button
                Button(action: { sendCommand("B", label: "BACKWARD ⬇️") }) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 65, height: 65)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                                )
                        )
                }
            }
            .padding(.horizontal, 20)
            
            // Quick Action Buttons
            VStack(spacing: 10) {
                Text("QUICK ACTIONS")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 8) {
                    Button(action: { sendCommand("F", label: "Go Forward") }) {
                        Text("Forward")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.25))
                            .cornerRadius(8)
                    }
                    
                    Button(action: { sendCommand("B", label: "Go Back") }) {
                        Text("Back")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.cyan.opacity(0.25))
                            .cornerRadius(8)
                    }
                    
                    Button(action: { sendCommand("S", label: "Stop") }) {
                        Text("Stop")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.25))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    /// Voice control section
    @ViewBuilder
    func voiceControlSection() -> some View {
        VStack(spacing: 20) {
            // Microphone Button
            Button(action: {
                if speechManager.isListening {
                    speechManager.stopListening()
                } else {
                    speechManager.startListening()
                }
            }) {
                VStack(spacing: 12) {
                    Image(systemName: speechManager.isListening ? "microphone.fill" : "microphone")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(speechManager.isListening ? .red : .white)
                    
                    Text(speechManager.isListening ? "LISTENING..." : "TAP TO SPEAK")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(speechManager.isListening ? .red : .white)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(speechManager.isListening ? Color.red.opacity(0.2) : Color.cyan.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    speechManager.isListening ? Color.red.opacity(0.6) : Color.cyan.opacity(0.6),
                                    lineWidth: 2
                                )
                        )
                )
                .padding(.horizontal, 20)
            }
            
            // Recognized Text Display
            VStack(spacing: 8) {
                Text("RECOGNIZED TEXT")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundColor(.gray)
                
                ScrollView {
                    Text(speechManager.recognizedText.isEmpty ? "Say a command..." : speechManager.recognizedText)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(height: 70)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            
            // Voice Commands Guide
            VStack(spacing: 10) {
                Text("VOICE COMMANDS")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 5) {
                    voiceCommandRow(emoji: "⬆️", label: "Forward", commands: "\"go forward\", \"ahead\"")
                    voiceCommandRow(emoji: "⬅️", label: "Left", commands: "\"go left\", \"turn left\"")
                    voiceCommandRow(emoji: "➡️", label: "Right", commands: "\"go right\", \"turn right\"")
                    voiceCommandRow(emoji: "⬇️", label: "Back", commands: "\"go back\", \"backward\"")
                    voiceCommandRow(emoji: "⏹", label: "Stop", commands: "\"stop\", \"halt\"")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
        }
    }
    
    /// Voice command guide row
    @ViewBuilder
    func voiceCommandRow(emoji: String, label: String, commands: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 14))
                
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(commands)
                .font(.system(size: 9, weight: .regular, design: .default))
                .foregroundColor(.cyan.opacity(0.7))
                .padding(.leading, 22)
        }
    }
    
    /// Command feedback display
    @ViewBuilder
    func feedbackSection() -> some View {
        VStack(spacing: 8) {
            Text("LAST COMMAND")
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text(commandFeedback)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            .cornerRadius(10)
        }
        .padding(.horizontal, 20)
        .opacity(feedbackOpacity)
    }
    
    /// Footer with instructions
    @ViewBuilder
    func footerSection() -> some View {
        VStack(spacing: 6) {
            Text(showVoiceMode ?
                 "Speak clearly for voice control" :
                 "Tap buttons to send commands")
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundColor(.gray)
            
            Text("Commands: Forward • Left • Right • Back • Stop")
                .font(.system(size: 10, weight: .regular, design: .default))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    
    /// Send command to robot and show feedback
    func sendCommand(_ cmd: String, label: String) {
        // Send via BLE
        bleManager.send(cmd)
        
        // Voice mode: process recognized text
        if showVoiceMode {
            if let voiceCmd = speechManager.processRecognizedText() {
                if voiceCmd == cmd {
                    lastCommandLabel = label
                } else {
                    return // Don't show feedback if command doesn't match
                }
            } else {
                return // No valid command from voice
            }
        } else {
            lastCommandLabel = label
        }
        
        // Show feedback
        commandFeedback = "\(label) ✓"
        feedbackOpacity = 1.0
        
        // Fade out after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                feedbackOpacity = 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    commandFeedback = ""
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

