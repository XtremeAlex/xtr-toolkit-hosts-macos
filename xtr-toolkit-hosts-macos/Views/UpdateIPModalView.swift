//
//  UpdateIPModalView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/UpdateIPModalView.swift
import SwiftUI

struct UpdateIPModalView: View {
    @ObservedObject var host: Host
    let lb: String
    @Binding var isPresented: Bool
    @ObservedObject var viewController: MainViewController
    @State private var isPinging: Bool = true
    @State private var respondingIP: String?

    var body: some View {
        VStack {
            if isPinging {
                Text("Sto cercando di contattare \(lb)")
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else {
                if let respondingIP = respondingIP {
                    Text("IP aggiornato: \(respondingIP)")
                    Button("Salva") {
                        host.ip = respondingIP
                        isPresented = false
                    }
                } else {
                    Text("Impossibile ottenere l'IP dal Load Balancer.")
                    Button("Chiudi") {
                        isPresented = false
                    }
                }
            }
        }
        .padding()
        .onAppear {
            pingLoadBalancer(lb: lb)
        }
    }

    func pingLoadBalancer(lb: String) {
        DispatchQueue.global(qos: .background).async {
            // Logica per seguire il ping al LB
            // Per semplicità, qui simuliamo il successo
            sleep(2)

            let success = true
            let ip = "192.168.1.1" // si va a sostituire con l'IP reale ottenuto dal ping

            DispatchQueue.main.async {
                self.isPinging = false
                if success {
                    self.respondingIP = ip
                } else {
                    self.respondingIP = nil
                }
            }
        }
    }
}
