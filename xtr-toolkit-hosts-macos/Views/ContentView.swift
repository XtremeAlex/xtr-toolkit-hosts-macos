//
//  ContentView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewController: MainViewController
    @AppStorage(IntroPreference.key) private var showIntro = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introFinished = false

    var body: some View {
        // L'intro si puo' disattivare (Impostazioni) e salta con "Riduci movimento":
        // in uso quotidiano l'utente deve arrivare subito ai dati.
        if introFinished || !showIntro || reduceMotion {
            MainView(viewController: viewController)
                .transition(.opacity)
        } else {
            IntroAnimationView { withAnimation(.easeOut(duration: 0.2)) { introFinished = true } }
        }
    }
}
