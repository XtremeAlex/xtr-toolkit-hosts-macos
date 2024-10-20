//
//  IOHostParser.swift
//  xtr-toolkit-hosts-macos
//
//  Created by MACBOOK PRO on 27/09/24.
//

// Utilities/IOHostParser.swift
import Foundation

// Qui ho ripreso la logica dell'applicazione in JAVA, in scrittura qui vedo che c'è qualche problema e sto cercando di testare e sistemare nel tempo a mia disposizione...
class IOHostParser {
    static let ipPattern = "^(([0-9]{1,3}\\.){3}[0-9]{1,3})$"
    static let customSectionStart = "##start-xtr-toolkit-host"

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
                    if matches(pattern: ipPattern, text: firstWord) {
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

    // Scrittura file hosts con privilegi di root
    static func writeHostsFileWithPrivileges(content: String) throws {
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let tempFileURL = tempDirectoryURL.appendingPathComponent("temp_hosts_file")
        let tempFilePath = tempFileURL.path

        print("Percorso del file temporaneo: \(tempFilePath)")

        // nuovo contenuto del file hosts in un file temporaneo
        try content.write(to: tempFileURL, atomically: true, encoding: .utf8)
        print("Contenuto scritto nel file temporaneo.")

        // gestisco i permessi del file temporaneo
        let fileManager = FileManager.default
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempFilePath)
        print("Permessi del file temporaneo impostati.")

        let escapedTempFilePath = tempFilePath.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedHostsFilePath = "/etc/hosts"
        print("Percorso temporaneo escapato: \(escapedTempFilePath)")
        print("Percorso /etc/hosts escapato: \(escapedHostsFilePath)")

        // Costruisci lo script AppleScript per richiedere i privilegi
        let script =
        """
        do shell script "mv \\\"\(escapedTempFilePath)\\\" \\\"\(escapedHostsFilePath)\\\"" with administrator privileges
        """
        print("Script AppleScript: \(script)")

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Errore AppleScript: \(error)")
                throw NSError(domain: "WriteHostsFileError", code: -1, userInfo: [NSLocalizedDescriptionKey: error[NSAppleScript.errorMessage] ?? "Errore sconosciuto"])
            } else {
                print("File hosts aggiornato con successo.")
            }
        } else {
            print("Errore nella creazione dello script AppleScript.")
            throw NSError(domain: "WriteHostsFileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Impossibile creare lo script AppleScript."])
        }
    }

    // PEr gestire la sezione personalizzata del file hosts (Da testare per bene ... )
    public static func generateOrderedCustomSection(_ apps: [HostApp]) -> [String] {
        var sectionLines: [String] = []
        sectionLines.append(customSectionStart)
        for app in apps {
            if !app.name.trimmingCharacters(in: .whitespaces).isEmpty {
                sectionLines.append("#APP: \(app.name.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ":", with: ""))")
            }
            if let lb = app.lb, !lb.trimmingCharacters(in: .whitespaces).isEmpty {
                sectionLines.append("#LB: \(lb.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ":", with: ""))")
            }

            var hostsByIp: [String: [Host]] = [:]
            for host in app.hosts {
                hostsByIp[host.ip, default: []].append(host)
            }

            for (ip, hosts) in hostsByIp {
                for host in hosts {
                    var hostLine = ""
                    if !host.enabled { hostLine += "#" }
                    hostLine += "\(ip) \(host.fqdn)"
                    sectionLines.append(hostLine)
                }
            }

            sectionLines.append("")
        }
        return sectionLines
    }

    private static func matches(pattern: String, text: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: text.utf16.count)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
        return false
    }
}
