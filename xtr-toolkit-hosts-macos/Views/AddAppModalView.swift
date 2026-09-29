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

    private var trimmedName: String { appName.trimmingCharacters(in: .whitespaces) }
    private var trimmedLB: String { lb.trimmingCharacters(in: .whitespaces) }
    /// Il LB e' opzionale; se presente deve essere un nome host o un IP (viene risolto via DNS).
    private var lbInvalid: Bool {
        !trimmedLB.isEmpty && !HostsDocument.isValidHostname(trimmedLB) && !HostsDocument.isValidIP(trimmedLB)
    }

    var body: some View {
        ModalScaffold(eyebrow: "Nuovo gruppo", title: "Aggiungi app") {
            LabeledField(label: "Nome app", placeholder: "Portale collaudo", text: $appName)
            LabeledField(label: "Informazioni", placeholder: "facoltativo", text: $appInfo)
            LabeledField(label: "Load balancer", placeholder: "lb.example.internal (facoltativo)",
                         text: $lb, invalid: lbInvalid)
        } actions: {
            Button("Annulla") { isPresented = false }
                .buttonStyle(XtrButtonStyle(kind: .ghost))
                .keyboardShortcut(.cancelAction)
            Button("Aggiungi") {
                let newApp = HostApp(name: trimmedName, info: appInfo, lb: trimmedLB.isEmpty ? nil : trimmedLB)
                viewController.presenter.addApp(newApp)
                isPresented = false
            }
            .buttonStyle(XtrButtonStyle(kind: .primary))
            .keyboardShortcut(.defaultAction)
            .disabled(trimmedName.isEmpty || lbInvalid)
        }
    }
}
