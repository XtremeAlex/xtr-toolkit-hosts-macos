//
//  AudioManager.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Utilities/AudioManager.swift
import AVFoundation
import OSLog

class AudioManager {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?
    private let log = Logger(subsystem: "com.xtremealex.toolkit.hosts", category: "audio")

    func playBackgroundMusic() {
        guard let url = Bundle.main.url(forResource: "background", withExtension: "wav") else {
            log.error("File audio non trovato nel bundle")
            return
        }

        // Ripresa dal punto di pausa invece di ricreare il player a ogni toggle.
        if let player {
            player.play()
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1 // Loop infinito
            player?.volume = 0.1
            player?.play()
        } catch {
            log.error("Caricamento audio fallito: \(error.localizedDescription, privacy: .public)")
        }
    }

    //Non la uso, forse in futuro
    func stopBackgroundMusic() {
        player?.stop()
    }
    
    func pauseBackgroundMusic() {
        player?.pause()
    }
}
