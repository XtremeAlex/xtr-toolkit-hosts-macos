//
//  AudioManager.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Utilities/AudioManager.swift
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var player: AVAudioPlayer?

    func playBackgroundMusic() {
        guard let url = Bundle.main.url(forResource: "background", withExtension: "wav") else {
            print("Errore: File audio non trovato.")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1 // Loop infinito
            player?.volume = 0.1
            player?.play()
        } catch {
            print("Errore nel caricamento dell'audio: \(error)")
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
