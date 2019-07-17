//
//  AudioEngine.swift
//  AVAudioEnginePractice
//
//  Created by Hui Qin Ng on 2019/7/17.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import AVFoundation

class AudioEngine: NSObject {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var pcmBuffer: AVAudioPCMBuffer?
    
    init(audioURL: URL) {
        super.init()
        setupAVAudioSession()
        loadFileIntoAVAudioFile(with: audioURL)
        setupAudioNodes()
        setupNotifications()
    }
    
    private func setupAVAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, policy: .longForm, options: [])
            try audioSession.setActive(true, options: [])
        } catch {
            fatalError("AudioSession setting issue")
        }
    }
    
    
    // Convert with AVAudioFile
    private func loadFileIntoAVAudioFile(with audioURL: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))
            guard let buffer = pcmBuffer else {
                fatalError("Failed to create AVAudioPCMBuffer")
            }
            try audioFile.read(into: buffer)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func setupAudioNodes() {
        engine.attach(playerNode)
        
        let playerFormat = pcmBuffer!.format
        engine.connect(playerNode, to: engine.mainMixerNode, fromBus: 0, toBus: 0, format: playerFormat)
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)
        
        engine.prepare()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: OperationQueue.main) { notification in
            print("AVAudioEngineConfigurationChange")
        }
    }
    
    private func startEngine() {
        guard !engine.isRunning else {
            return
        }
        do {
            try engine.start()
            print("Started Engine")
        } catch {
            print("Engine failed to start with error: \(error.localizedDescription)")
        }
    }
    
    private func pauseEngine() {
        guard !playerIsPlaying else {
            return
        }
        engine.pause()
        engine.reset()
    }
}

// MARK: - Player
extension AudioEngine {
    var playerIsPlaying: Bool {
        return playerNode.isPlaying
    }
    
    func togglePlayer() {
        if !playerIsPlaying {
            guard let buffer = pcmBuffer else {
                return
            }
            startEngine()
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { callbackType in
                print("player node scheduleBuffer callback")
            }
            playerNode.play()
        } else {
            playerNode.stop()
            pauseEngine()
        }
    }
}
