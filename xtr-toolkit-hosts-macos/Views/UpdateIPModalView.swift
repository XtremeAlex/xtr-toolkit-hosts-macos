//
//  UpdateIPModalView.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 28/09/24.
//

// Views/UpdateIPModalView.swift
import SwiftUI

/// Aggiorna l'IP di un host con l'indirizzo attuale del load balancer.
///
/// Perche': prima la "risoluzione" era simulata (attesa di 2 s e IP fisso 192.168.1.1), quindi
/// salvare avrebbe scritto un indirizzo inventato. Ora il nome del LB viene risolto davvero
/// con il resolver di sistema e l'utente sceglie fra gli indirizzi restituiti.
struct UpdateIPModalView: View {
    @ObservedObject var host: Host
    let lb: String
    @Binding var isPresented: Bool
    @ObservedObject var viewController: MainViewController
    @State private var isResolving: Bool = true
    @State private var addresses: [String] = []
    @State private var selected: String?
    @State private var failure: String?

    var body: some View {
        ModalScaffold(eyebrow: "Load balancer \(lb)", title: "Aggiorna IP") {
            VStack(alignment: .leading, spacing: Theme.s2) {
                MonoLabel("Host")
                Text("\(host.ip)  \(host.fqdn)").font(Theme.mono(12.5)).foregroundStyle(Theme.text)
            }
            if isResolving {
                HStack(spacing: Theme.s3) {
                    ProgressView().controlSize(.small)
                    MonoLabel("Risoluzione DNS di \(lb)")
                }
            } else if let failure {
                Callout(kind: .alert) { Text(failure).font(.callout).foregroundStyle(Theme.text) }
            } else {
                VStack(alignment: .leading, spacing: Theme.s2) {
                    MonoLabel("Indirizzi trovati")
                    Picker("Indirizzo", selection: $selected) {
                        ForEach(addresses, id: \.self) { Text($0).font(Theme.mono(12.5)).tag(Optional($0)) }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                Text("Nota: il resolver di sistema consulta anche /etc/hosts; se \(lb) e' definito li', viene restituito quel valore.")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            Button("Annulla") { isPresented = false }
                .buttonStyle(XtrButtonStyle(kind: .ghost))
                .keyboardShortcut(.cancelAction)
            Button("Usa indirizzo") {
                if let selected { host.ip = selected }
                isPresented = false
            }
            .buttonStyle(XtrButtonStyle(kind: .primary, isLoading: isResolving))
            .keyboardShortcut(.defaultAction)
            .disabled(isResolving || selected == nil)
        }
        .task { await resolve() }
    }

    private func resolve() async {
        let name = lb
        let result = await Task.detached(priority: .userInitiated) { DNSResolver.addresses(for: name) }.value
        isResolving = false
        switch result {
        case .success(let list) where !list.isEmpty:
            addresses = list
            selected = list.first
        case .success:
            failure = "Nessun indirizzo per \(lb)."
        case .failure(let error):
            failure = error.localizedDescription
        }
    }
}

/// Risoluzione con getaddrinfo (IPv4 e IPv6), senza dipendenze esterne.
enum DNSResolver {
    struct ResolveError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func addresses(for name: String) -> Result<[String], Error> {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var info: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(name, nil, &hints, &info)
        guard status == 0 else {
            return .failure(ResolveError(message: "Risoluzione di \(name) non riuscita: \(String(cString: gai_strerror(status)))"))
        }
        defer { freeaddrinfo(info) }

        var out: [String] = []
        var cursor = info
        while let entry = cursor?.pointee {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(entry.ai_addr, entry.ai_addrlen, &buffer, socklen_t(buffer.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let address = String(cString: buffer)
                if !out.contains(address) { out.append(address) }
            }
            cursor = entry.ai_next
        }
        return .success(out)
    }
}
