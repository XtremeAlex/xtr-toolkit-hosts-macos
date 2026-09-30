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
    /// Default "sistema" come openmail: in azienda l'app rispetta l'aspetto gestito del Mac.
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue

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
                    .disabled(!viewController.isEditing || viewController.isSaving || viewController.isReadOnly)
                Button("Annulla modifiche") { viewController.presenter.cancelChanges() }
                    .disabled(!viewController.isEditing || viewController.isSaving)
            }
            CommandMenu("Aspetto") {
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
                .disabled(AppearancePreference.isManaged)
            }
        }

        Settings {
            SettingsView(viewController: viewController)
                .preferredColorScheme(preference.colorScheme)
        }
    }

    private var preference: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .system
    }
}

/// Impostazioni (⌘,): tema, intro, musica e note per chi amministra i Mac.
struct SettingsView: View {
    @ObservedObject var viewController: MainViewController
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(IntroPreference.key) private var showIntro = true
    private let policy = HostsPolicy.current()

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
                .disabled(AppearancePreference.isManaged)
                if AppearancePreference.isManaged {
                    Text("Impostato dall'amministratore (profilo di configurazione).")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                }
            }
            Toggle(isOn: $showIntro) { Text("Animazione iniziale") }
                .toggleStyle(SwitchStyle())
            Toggle(isOn: $viewController.isMusicOn) { Text("Musica di sottofondo") }
                .toggleStyle(SwitchStyle())
            HStack(spacing: Theme.s2) {
                Pill(text: policy.readOnly ? "Sola lettura" : "Modifica consentita")
                Pill(text: "Backup: \(policy.backupRetention)")
                Pill(text: policy.flushDNS ? "Cache DNS: svuotata" : "Cache DNS: invariata")
            }
            Callout(kind: .info) {
                MonoLabel("Amministrazione", color: Theme.info)
                Text("Ogni salvataggio chiede la password di amministratore, verifica che /etc/hosts non sia cambiato nel frattempo, conserva tutto cio' che precede ##start-xtr-toolkit-host e crea un backup datato /etc/hosts.xtr-toolkit.<data>.bak (ultimi \(policy.backupRetention)). Audit: ~/Library/Logs/xtr-toolkit-hosts/audit.log. Log: sottosistema com.xtremealex.toolkit.hosts.")
                    .font(.callout)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BackupRestoreSection(viewController: viewController, policy: policy)
        }
        .padding(Theme.s5)
        .frame(width: 460)
        .background(Theme.bg)
    }
}

/// Elenco dei backup datati con ripristino della sola sezione dell'app.
///
/// Perche' qui: in azienda il rollback di una modifica sbagliata non deve richiedere il
/// Terminale; il ripristino passa comunque da password di amministratore, verifica dell'hash,
/// nuovo backup e audit, come un salvataggio.
struct BackupRestoreSection: View {
    @ObservedObject var viewController: MainViewController
    let policy: HostsPolicy
    @State private var backups: [HostsBackup] = []
    @State private var pending: HostsBackup?

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s2) {
            MonoLabel("Backup")
            if backups.isEmpty {
                Text("Nessun backup accanto a /etc/hosts.").font(.callout).foregroundStyle(Theme.textMuted)
            }
            ForEach(backups.prefix(policy.backupRetention)) { backup in
                HStack(spacing: Theme.s2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dateFormat.string(from: backup.date)).font(.callout).foregroundStyle(Theme.text)
                        Text(previewText(backup)).font(.caption.monospaced()).foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    Button("Ripristina") { pending = backup }
                        .buttonStyle(XtrButtonStyle(kind: .ghost, small: true))
                        .disabled(!canRestore)
                        .help(policy.readOnly ? HostsWriteError.readOnly.localizedDescription
                              : viewController.isEditing ? "Salva o annulla prima le modifiche in corso" : "")
                        .accessibilityLabel("Ripristina il backup del \(Self.dateFormat.string(from: backup.date))")
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: viewController.isSaving) { _, saving in if !saving { reload() } }
        .confirmationDialog("Ripristinare la sezione dell'app da questo backup?",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            presenting: pending) { backup in
            Button("Ripristina", role: .destructive) { viewController.presenter.restoreFromBackupAsync(backup) }
            Button("Annulla", role: .cancel) {}
        } message: { _ in
            Text("Le righe prima di ##start-xtr-toolkit-host restano quelle attuali. Lo stato di adesso viene salvato in un nuovo backup.")
        }
    }

    private var canRestore: Bool { !policy.readOnly && !viewController.isSaving && !viewController.isEditing }

    private func previewText(_ backup: HostsBackup) -> String {
        guard let d = viewController.presenter.restorePreview(backup) else { return "senza sezione dell'app" }
        return d.added == 0 && d.removed == 0 ? "uguale al file attuale" : "+\(d.added) −\(d.removed) righe"
    }

    private func reload() { backups = HostsBackups.list(hostsPath: IOHostParser.hostsFilePath) }
}

/// Preferenza dell'animazione iniziale (chiave UserDefaults gestibile anche via MDM).
enum IntroPreference {
    static let key = "showIntro"
}
