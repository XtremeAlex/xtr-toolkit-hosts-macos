//
//  AddLBModalView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/AddLBModalView.swift
import SwiftUI

struct AddLBModalView: View {
    @ObservedObject var app: HostApp
    @Binding var isPresented: Bool
    @State private var lbText: String = ""

    var body: some View {
        VStack {
            Text("Aggiungi Load Balancer")
                .font(.headline)
            TextField("Indirizzo IP del Load Balancer", text: $lbText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            HStack {
                Button("Annulla") {
                    isPresented = false
                }
                Button("Salva") {
                    app.lb = lbText
                    isPresented = false
                }
            }
        }
        .padding()
    }
}
