//
//  IOHostParser.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Utilities/IOHostParser.swift
import Foundation
import OSLog

enum HostsWriteError: LocalizedError {
    case tempFile, script, cancelled
    case failed(String)
    case invalidEntries([String])
    case unreadable
    case readOnly
    case modifiedExternally
    case verificationFailed
    case backupFailed

    var errorDescription: String? {
        switch self {
        case .tempFile: return "Impossibile preparare il file temporaneo."
        case .script: return "Impossibile creare la richiesta di privilegi."
        case .cancelled: return "Salvataggio annullato: password di amministratore non inserita."
        case .failed(let m): return "Scrittura di /etc/hosts non riuscita: \(m)"
        case .invalidEntries(let list):
            return "Salvataggio bloccato, voci non valide:\n" + list.prefix(10).joined(separator: "\n")
        case .unreadable: return "Impossibile leggere /etc/hosts."
        case .readOnly: return "Modifiche disattivate dall'amministratore (profilo di configurazione)."
        case .modifiedExternally:
            return "/etc/hosts e' stato modificato da un altro processo dopo l'apertura: nulla e' stato scritto. Ricarica e riprova."
        case .verificationFailed: return "Verifica dopo la scrittura non riuscita: controlla /etc/hosts e il backup."
        case .backupFailed: return "Backup di /etc/hosts non riuscito: nulla e' stato scritto."
        }
    }
}

// Qui ho ripreso la logica dell'applicazione in JAVA, in scrittura qui vedo che c'è qualche problema e sto cercando di testare e sistemare nel tempo a mia disposizione...
class IOHostParser {
    static let ipPattern = "^(([0-9]{1,3}\\.){3}[0-9]{1,3})$"
    static let customSectionStart = HostsDocument.sectionMarker
    static let hostsFilePath = "/etc/hosts"
    private static let log = Logger(subsystem: "com.xtremealex.toolkit.hosts", category: "hosts-file")
    private static let audit = Logger(subsystem: "com.xtremealex.toolkit.hosts", category: "audit")

    static func parseHostsFile(filePath: String) throws -> [HostApp] {
        let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = fileContent.components(separatedBy: .newlines)

        var apps: [HostApp] = []
        var currentApp: HostApp?
        var currentLb: String?

        var startReading = false

        for var line in lines {
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Ignora le righe vuote
            if line.isEmpty {
                continue
            }

            // Riconoscimento delle sezioni
            if line == customSectionStart {
                startReading = true
                continue
            }

            if !startReading {
                continue
            }

            var keyword = ""

            if line.hasPrefix("#") {
                let strippedLine = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)

                if strippedLine.hasPrefix("LB:") {
                    keyword = "LB"
                } else if strippedLine.hasPrefix("APP:") {
                    keyword = "APP"
                } else {
                    // Se è un IP commentato
                    let firstWord = HostsDocument.tokens(of: strippedLine).first ?? ""
                    // Anche IPv6 (es. "#::1 nome"): prima solo IPv4 era riconosciuto come IP commentato.
                    if matches(pattern: ipPattern, text: firstWord) || HostsDocument.isValidIP(firstWord) {
                        keyword = "IP_COMMENTED"
                    } else {
                        // Se non è un IP, consideriamolo come APP implicita
                        keyword = "APP_IMPLICIT"
                    }
                }
            } else {
                // IP non commentato
                keyword = "IP"
            }

            switch keyword {
            case "LB":
                // Trovato un Load Balancer. Si estrae dalla riga senza "#" e spazi: con
                // "# LB: x" il vecchio dropFirst(4) sulla riga grezza restituiva ": x".
                currentLb = commentBody(line).dropFirst(3).trimmingCharacters(in: .whitespaces)

                if currentApp == nil {
                    currentApp = HostApp(name: "Indefinito", lb: currentLb)
                    apps.append(currentApp!)
                } else {
                    currentApp?.lb = currentLb
                }
            case "APP":
                // Trovata una nuova App
                let appName = commentBody(line).dropFirst(4).trimmingCharacters(in: .whitespaces)
                currentApp = HostApp(name: appName)
                currentLb = nil
                apps.append(currentApp!)
            case "APP_IMPLICIT":
                // Importa la stringa come nome dell'App se non è un IP
                if currentApp == nil || currentApp?.name.isEmpty == true {
                    let appName = line.dropFirst().trimmingCharacters(in: .whitespaces)
                    currentApp = HostApp(name: appName)
                    currentLb = nil
                    apps.append(currentApp!)
                }
            case "IP_COMMENTED":
                // IP Commentato (disabilitato)
                // Parole della riga senza il "#" iniziale; un commento in coda non e' un host
                let parts = HostsDocument.tokens(of: commentBody(line))
                guard let ip = parts.first else { break }

                if currentApp == nil {
                    currentApp = HostApp(name: "Indefinito", lb: currentLb)
                    apps.append(currentApp!)
                }

                // Per ogni FQDN, crea un nuovo Host disabilitato
                for fqdn in parts.dropFirst() {
                    currentApp?.hosts.append(Host(ip: ip, fqdn: fqdn, enabled: false))
                }
            case "IP":
                // IP non commentato (abilitato)
                // Separatori multipli e tab non creano host vuoti; "# nota" in coda e' ignorata
                let parts = HostsDocument.tokens(of: line)
                guard let ip = parts.first else { break }

                if currentApp == nil {
                    currentApp = HostApp(name: "Indefinito", lb: currentLb)
                    apps.append(currentApp!)
                }

                // "ip nome #altro": formato storico con singoli nomi disabilitati
                for entry in HostsDocument.hostEntries(of: line) {
                    currentApp?.hosts.append(Host(ip: ip, fqdn: entry.name, enabled: entry.enabled))
                }
            default:
                // Gestione di ulteriori casi se necessario
                break
            }
        }

        return apps
    }

    /// Scrive il nuovo /etc/hosts con privilegi di amministratore e restituisce il percorso
    /// del backup. Lo script (vedi `HostsWriteScript`) verifica che il file non sia cambiato
    /// dopo la lettura, salva un backup datato, installa in modo atomico, controlla il
    /// risultato, ruota i backup e svuota la cache DNS.
    ///
    /// - il file temporaneo ha nome univoco e permessi 0600: altri utenti del Mac non possono
    ///   leggerlo ne' sostituirlo prima della copia;
    /// - `install -o root -g wheel -m 0644` al posto di `mv`: il file resta di root.
    @discardableResult
    static func writeHostsFileWithPrivileges(content: String, expectedOriginalSHA256: String,
                                             policy: HostsPolicy = .current(),
                                             hostsPath: String = hostsFilePath,
                                             now: Date = Date()) throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xtr-toolkit-hosts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard FileManager.default.createFile(atPath: tempURL.path, contents: Data(content.utf8),
                                             attributes: [.posixPermissions: 0o600]) else {
            throw HostsWriteError.tempFile
        }
        log.info("File temporaneo pronto (\(content.utf8.count) byte)")

        let backup = HostsWriteScript.backupPath(for: hostsPath, date: now)
        let command = HostsWriteScript.command(source: tempURL.path, hostsPath: hostsPath, backupPath: backup,
                                               expectedSHA256: expectedOriginalSHA256, policy: policy)
        let script = "do shell script \(appleScriptLiteral(command)) with administrator privileges"

        guard let scriptObject = NSAppleScript(source: script) else { throw HostsWriteError.script }
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = error[NSAppleScript.errorMessage] as? String ?? "Errore sconosciuto"
            log.error("Scrittura hosts fallita (\(code, privacy: .public)): \(message, privacy: .public)")
            switch code {
            case -128: throw HostsWriteError.cancelled        // password non inserita
            case HostsWriteScript.exitModified: throw HostsWriteError.modifiedExternally
            case HostsWriteScript.exitVerify: throw HostsWriteError.verificationFailed
            case HostsWriteScript.exitBackup: throw HostsWriteError.backupFailed
            default: throw HostsWriteError.failed(message)
            }
        }
        log.info("File hosts aggiornato, backup \(backup, privacy: .public)")
        return backup
    }

    /// Registro di audit in ~/Library/Logs/xtr-toolkit-hosts/audit.log (JSON Lines, solo
    /// append) e nel log di sistema, categoria "audit". Un errore qui non annulla il
    /// salvataggio gia' avvenuto: viene solo segnalato nel log.
    static func appendAudit(_ record: HostsAuditRecord,
                            directory: URL = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent("Library/Logs/xtr-toolkit-hosts")) {
        audit.notice("hosts salvato da \(record.user, privacy: .public): +\(record.added.count) -\(record.removed.count), backup \(record.backupPath, privacy: .public)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("audit.log")
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(record.jsonLine().utf8))
        } catch {
            audit.error("Registro di audit non scritto: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Testo di un commento senza il "#" iniziale e gli spazi.
    private static func commentBody(_ line: String) -> String {
        String(line.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
    }

    /// Letterale stringa AppleScript con escape di backslash e virgolette.
    static func appleScriptLiteral(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Sezione personalizzata (delegata a HostsDocument: ordine stabile, testabile).
    public static func generateOrderedCustomSection(_ apps: [HostApp]) -> [String] {
        HostsDocument.section(for: apps.map(\.snapshot))
    }

    private static func matches(pattern: String, text: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
        return false
    }
}
