//
//  HeaderView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Views/HeaderView.swift
import SwiftUI

struct HeaderView: View {
    @Binding var isEditing: Bool
    @Binding var isMusicOn: Bool
    var saveAction: () -> Void = {}
    var cancelAction: () -> Void = {}
    var addAppAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            // Titolo e Autore
            VStack(alignment: .leading) {
                Text("XTR TOOLKIT HOST")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                Text("by XtremeAlex")
                    .font(.system(size: 10))
                    .foregroundColor(Color.gray)
            }

            Spacer()

            // Sezione Musica e Modifica
            VStack(alignment: .trailing, spacing: 10) {
                HStack {
                    Text("MUSICA")
                        .font(.headline)
                    Toggle("", isOn: $isMusicOn)
                        .toggleStyle(CustomToggleStyle())
                        .frame(width: 60)
                        .onChange(of: isMusicOn) { _, newValue in
                            if newValue {
                                AudioManager.shared.playBackgroundMusic()
                            } else {
                                AudioManager.shared.pauseBackgroundMusic()
                            }
                        }
                }

                HStack {
                    if isEditing {
                        Button("Annulla") {
                            cancelAction()
                        }
                        Button("Salva") {
                            saveAction()
                        }
                        if let addAppAction = addAppAction {
                            Button("Aggiungi") {
                                addAppAction()
                            }
                        }
                    } else {
                        Button("Modifica") {
                            isEditing = true
                        }
                    }
                }
            }
        }
        .padding()
    }
}
