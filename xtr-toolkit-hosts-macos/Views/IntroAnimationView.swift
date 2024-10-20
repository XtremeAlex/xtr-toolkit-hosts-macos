//
//  IntroAnimationView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 20/10/24.
//

// Views/IntroAnimationView.swift
import SwiftUI

struct AsciiArtLine: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

struct IntroAnimationView: View {
    @State private var showMainContent: Bool = false
    @State private var animationStarted: Bool = false
    @State private var appleLogoLines: [AsciiArtLine] = []
    @State private var showAsciiArt: Bool = false
    @State private var showCommand: Bool = false
    @State private var commandTextDisplay: String = ""

    let commandText = "./XTREME-TOOLKIT-HOSTS \n. . . . . . . . . . . . . . . . . . . . . . . "
    let prompt = ">"

    var body: some View {
        if showMainContent {
            MainView(viewController: MainViewController())
        } else {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                VStack(alignment: .leading, spacing: 0) {
                    if showAsciiArt {
                        ForEach(appleLogoLines) { line in
                            Text(line.text)
                                .font(.custom("Menlo", size: 14))
                                .foregroundColor(line.color)
                        }
                    }
                    if showCommand {
                        HStack(alignment: .top, spacing: 0) {
                            Text(prompt)
                                .foregroundColor(.green)
                            Text(commandTextDisplay)
                                .foregroundColor(.green)
                        }
                    }
                    Spacer()
                }
                .padding()
                .onAppear {
                    if !self.animationStarted {
                        self.animationStarted = true
                        self.startAnimation()
                    }
                }
            }
        }
    }

    func startAnimation() {
        // Inizializzazione dell'ASCII copiati direttamente dal mio bash, da migliorare ...
        appleLogoLines = [
            AsciiArtLine(text: "", color: .green),
            AsciiArtLine(text: "", color: .green),
            AsciiArtLine(text: "", color: .green),
            AsciiArtLine(text: "", color: .green),
            AsciiArtLine(text: "", color: .green),
            AsciiArtLine(text: "", color: .green),
            AsciiArtLine(text: "                    'c.", color: .green),
            AsciiArtLine(text: "                 ,xNMM.", color: .green),
            AsciiArtLine(text: "               .OMMMMo", color: .green),
            AsciiArtLine(text: "              OMMM0,", color: .green),
            AsciiArtLine(text: "     .;loddo:' loolloddol;.", color: .green),
            AsciiArtLine(text: "   cKMMMMMMMMMMNWMMMMMMMMMM0:", color: .yellow),
            AsciiArtLine(text: " .KMMMMMMMMMMMMMMMMMMMMMMMWd.", color: .yellow),
            AsciiArtLine(text: " XMMMMMMMMMMMMMMMMMMMMMMMX.", color: .red),
            AsciiArtLine(text: ";MMMMMMMMMMMMMMMMMMMMMMMM:", color: .red),
            AsciiArtLine(text: ":MMMMMMMMMMMMMMMMMMMMMMMM:", color: .red),
            AsciiArtLine(text: ".MMMMMMMMMMMMMMMMMMMMMMMMX.", color: .red),
            AsciiArtLine(text: " kMMMMMMMMMMMMMMMMMMMMMMMMWd.", color: .pink),
            AsciiArtLine(text: " .XMMMMMMMMMMMMMMMMMMMMMMMMMMk", color: .pink),
            AsciiArtLine(text: "  .XMMMMMMMMMMMMMMMMMMMMMMMMK.", color: .blue),
            AsciiArtLine(text: "    kMMMMMMMMMMMMMMMMMMMMMMd", color: .blue),
            AsciiArtLine(text: "     ;KMMMMMMMWXXWMMMMMMMk.", color: .blue),
            AsciiArtLine(text: "       .cooc,.    .,coo:.", color: .blue),
            AsciiArtLine(text: "", color: .blue),
            AsciiArtLine(text: "", color: .blue),
            AsciiArtLine(text: "by XtremeAlex", color: .indigo),
            AsciiArtLine(text: "Andrei Alexandru Dabija", color: .purple),
            AsciiArtLine(text: "", color: .purple)
        ]
        // Mostra subito l'ASCII di sopra
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                self.showAsciiArt = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    // Ora parto con l'animazione, fantastico che posso usare quasi infiniti DispatchQueue
                    self.animateCommand()
                }
            }

        }
    }

    func animateCommand() {
        self.showCommand = true
        let commandCharacters = Array(commandText)
        for (index, char) in commandCharacters.enumerated() {
            let delay = Double(index) * 0.03 // Effetto di digitazione
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.commandTextDisplay.append(char)
                if index == commandCharacters.count - 1 {
                    
                    withAnimation {
                        self.showMainContent = true
                    }
                    
                }
            }
        }
    }
}
