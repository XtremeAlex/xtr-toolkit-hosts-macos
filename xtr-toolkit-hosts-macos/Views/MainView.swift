//
//  MainView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/MainView.swift
import SwiftUI

struct MainView: View {
    @ObservedObject var viewController: MainViewController

    var body: some View {
        VStack {
            if viewController.isEditing {
                EditingView(viewController: viewController)
            } else {
                ViewingView(viewController: viewController)
            }
            
        }
        .onAppear {
            // Avvia la musica se isMusicOn è true, ho spostato questo nell'init dentro MainViewController
            //if self.viewController.isMusicOn {
            //      AudioManager.shared.playBackgroundMusic()
            //  }
        }
        .alert(isPresented: $viewController.showingError) {
            Alert(
                title: Text("Errore"),
                message: Text(viewController.errorMessage),
                dismissButton: .default(Text("OK")) {
                    viewController.showingError = false
                }
            )
        }
        .alert(isPresented: $viewController.showingInfo) {
            Alert(
                title: Text("Informazione"),
                message: Text(viewController.infoMessage),
                dismissButton: .default(Text("OK")) {
                    viewController.showingInfo = false
                }
            )
        }
    }
}
