//
//  xtr_toolkit_hosts_macosApp.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//
// App/xtr_toolkit_hosts_macosApp
import SwiftUI

@main
struct xtr_toolkit_hosts_macosApp: App {
    /// Un solo controller per la vita dell'app. Perche': prima veniva creato dentro il `body`
    /// dell'animazione iniziale, quindi ogni nuovo rendering rileggeva /etc/hosts, perdeva le
    /// modifiche non salvate e ripartiva con la musica.
    @StateObject private var viewController = MainViewController()
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.dark.rawValue

    var body: some Scene {
        WindowGroup("hosts") {
            ContentView(viewController: viewController)
                .frame(minWidth: 760, minHeight: 520)
                .preferredColorScheme(preference.colorScheme)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .saveItem) {
                Button("Salva in /etc/hosts") { viewController.saveChanges() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!viewController.isEditing || viewController.isSaving)
                Button("Annulla modifiche") { viewController.presenter.cancelChanges() }
                    .disabled(!viewController.isEditing || viewController.isSaving)
            }
            CommandMenu("Aspetto") {
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
            }
        }

        Settings {
            SettingsView(viewController: viewController)
                .preferredColorScheme(preference.colorScheme)
        }
    }

    private var preference: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .dark
    }
}

/// Impostazioni (⌘,): tema, intro, musica e note per chi amministra i Mac.
struct SettingsView: View {
    @ObservedObject var viewController: MainViewController
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.dark.rawValue
    @AppStorage(IntroPreference.key) private var showIntro = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            BrandMark(name: "hosts", size: 18)
            VStack(alignment: .leading, spacing: Theme.s2) {
                MonoLabel("Tema")
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Toggle(isOn: $showIntro) { Text("Animazione iniziale") }
                .toggleStyle(SwitchStyle())
            Toggle(isOn: $viewController.isMusicOn) { Text("Musica di sottofondo") }
                .toggleStyle(SwitchStyle())
            Callout(kind: .info) {
                MonoLabel("Amministrazione", color: Theme.info)
                Text("Ogni salvataggio chiede la password di amministratore, conserva tutto cio' che precede ##start-xtr-toolkit-host e crea /etc/hosts.xtr-toolkit.bak. Log: sottosistema com.xtremealex.toolkit.hosts.")
                    .font(.callout)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.s5)
        .frame(width: 460)
        .background(Theme.bg)
    }
}

/// Preferenza dell'animazione iniziale (chiave UserDefaults gestibile anche via MDM).
enum IntroPreference {
    static let key = "showIntro"
}
