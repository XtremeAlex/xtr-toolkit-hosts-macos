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

    var errorDescription: String? {
        switch self {
        case .tempFile: return "Impossibile preparare il file temporaneo."
        case .script: return "Impossibile creare la richiesta di privilegi."
        case .cancelled: return "Salvataggio annullato: password di amministratore non inserita."
        case .failed(let m): return "Scrittura di /etc/hosts non riuscita: \(m)"
        case .invalidEntries(let list):
            return "Salvataggio bloccato, voci non valide:\n" + list.prefix(10).joined(separator: "\n")
        case .unreadable: return "Impossibile leggere /etc/hosts."
        }
    }
}

// Qui ho ripreso la logica dell'applicazione in JAVA, in scrittura qui vedo che c'è qualche problema e sto cercando di testare e sistemare nel tempo a mia disposizione...
class IOHostParser {
    static let ipPattern = "^(([0-9]{1,3}\\.){3}[0-9]{1,3})$"
    static let customSectionStart = HostsDocument.sectionMarker
    static let hostsFilePath = "/etc/hosts"
    private static let log = Logger(subsystem: "com.xtremealex.toolkit.hosts", category: "hosts-file")

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
                    let firstWord = strippedLine.components(separatedBy: .whitespaces).first ?? ""
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
                // Trovato un Load Balancer
                currentLb = line.dropFirst(4).trimmingCharacters(in: .whitespaces)

                if currentApp == nil {
                    currentApp = HostApp(name: "Indefinito", lb: currentLb)
                    apps.append(currentApp!)
                } else {
                    currentApp?.lb = currentLb
                }
            case "APP":
                // Trovata una nuova App
                let appName = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
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
                let parts = line.components(separatedBy: .whitespaces)
                // Rimuove il `#` dall'IP
                let ip = String(parts[0].dropFirst())

                if currentApp == nil {
                    currentApp = HostApp(name: "Indefinito", lb: currentLb)
                    apps.append(currentApp!)
                }

                // Per ogni FQDN, crea un nuovo Host disabilitato
                for fqdnPart in parts.dropFirst() {
                    let fqdn = fqdnPart.replacingOccurrences(of: "#", with: "")
                    let host = Host(ip: ip, fqdn: fqdn, enabled: false)
                    currentApp?.hosts.append(host)
                }
            case "IP":
                // IP non commentato (abilitato)
                let parts = line.components(separatedBy: .whitespaces)
                let ip = parts[0]

                if currentApp == nil {
                    currentApp = HostApp(name: "Indefinito", lb: currentLb)
                    apps.append(currentApp!)
                }

                // Per ogni FQDN, crea un nuovo Host
                for fqdnPart in parts.dropFirst() {
                    let fqdn = fqdnPart.replacingOccurrences(of: "#", with: "")
                    let enabled = !fqdnPart.hasPrefix("#")
                    let host = Host(ip: ip, fqdn: fqdn, enabled: enabled)
                    currentApp?.hosts.append(host)
                }
            default:
                // Gestione di ulteriori casi se necessario
                break
            }
        }

        return apps
    }

    /// Scrive il nuovo /etc/hosts con privilegi di amministratore.
    ///
    /// Scelte (uso aziendale):
    /// - il file temporaneo ha nome univoco e permessi 0600: altri utenti del Mac non possono
    ///   leggerlo ne' sostituirlo prima della copia;
    /// - prima della scrittura si salva `/etc/hosts.xtr-toolkit.bak`, per un ripristino immediato;
    /// - `install -o root -g wheel -m 0644` al posto di `mv`: con `mv` il file hosts diventava di
    ///   proprieta' dell'utente (chiunque con quella sessione poteva poi modificarlo senza password);
    /// - i percorsi passano da `quoted form of` di AppleScript: nessuna interpolazione in shell;
    /// - dopo la scrittura si svuota la cache DNS, altrimenti le modifiche non hanno effetto subito.
    static func writeHostsFileWithPrivileges(content: String, hostsPath: String = hostsFilePath) throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("xtr-toolkit-hosts-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard FileManager.default.createFile(atPath: tempURL.path, contents: Data(content.utf8),
                                             attributes: [.posixPermissions: 0o600]) else {
            throw HostsWriteError.tempFile
        }
        log.info("File temporaneo pronto (\(content.utf8.count) byte)")

        let script = """
        set src to quoted form of \(appleScriptLiteral(tempURL.path))
        set dst to quoted form of \(appleScriptLiteral(hostsPath))
        set bak to quoted form of \(appleScriptLiteral(hostsPath + ".xtr-toolkit.bak"))
        do shell script "/bin/cp -p " & dst & " " & bak & " && /usr/bin/install -o root -g wheel -m 0644 " & src & " " & dst & " && (/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder; true)" with administrator privileges
        """

        guard let scriptObject = NSAppleScript(source: script) else { throw HostsWriteError.script }
        var error: NSDictionary?
        scriptObject.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            // -128: l'utente ha annullato la richiesta di password.
            if code == -128 { throw HostsWriteError.cancelled }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Errore sconosciuto"
            log.error("Scrittura hosts fallita (\(code, privacy: .public)): \(message, privacy: .public)")
            throw HostsWriteError.failed(message)
        }
        log.info("File hosts aggiornato, backup in \(hostsPath, privacy: .public).xtr-toolkit.bak")
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
