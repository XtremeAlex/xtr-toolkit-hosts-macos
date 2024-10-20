//
//  AddAppModalView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/AddAppModalView.swift
import SwiftUI

struct AddAppModalView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewController: MainViewController
    @State private var appName: String = ""
    @State private var appInfo: String = ""
    @State private var lb: String = ""

    var body: some View {
        VStack {
            Text("Aggiungi una nuova App")
                .font(.headline)
            TextField("Nome App", text: $appName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("Informazioni App", text: $appInfo)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("Load Balancer (opzionale)", text: $lb)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            HStack {
                Button("Annulla") {
                    isPresented = false
                }
                Button("Salva") {
                    let newApp = HostApp(name: appName, info: appInfo, lb: lb.isEmpty ? nil : lb)
                    viewController.presenter.addApp(newApp)
                    isPresented = false
                }
            }
        }
        .padding()
    }
}
