# xtr-toolkit-hosts-macos

Applicazione macOS nativa per gestire il file `/etc/hosts` di sistema in modo semplice ed efficace, con gestione dei gruppi di host e dei load balancer.

![Progetto](_assets/images/1.png)
![Progetto](_assets/images/2.png)
![Progetto](_assets/images/3.png)

## Info sul progetto

**XTR Toolkit Hosts** è un'applicazione macOS ispirata alla gemella Java [xtr-toolkit-hosts](https://github.com/XtremeAlex/xtr-toolkit-hosts), progettata per gestire il file `/etc/hosts` del sistema. Permette di visualizzare, aggiungere, modificare ed eliminare gruppi di host, gestire i load balancer associati e interagire con un'interfaccia arricchita da animazioni. È ancora in ALPHA e sotto test: seguiranno aggiornamenti nelle prossime release.

Funzionalità principali:

- Visualizzazione, aggiunta, modifica ed eliminazione di gruppi di host.
- Gestione degli host associati a ciascuna applicazione.
- Abilitazione/disabilitazione degli host tramite toggle.
- Gestione dei load balancer per le applicazioni (utile con K8s + ALB).
- Interfaccia utente intuitiva con animazioni.
- Persistenza automatica: le modifiche vengono salvate nel file `/etc/hosts`.

## Stack tecnologico

- Swift, SwiftUI (macOS)
- Xcode
- Architettura MVVM con elementi di MVP

## Architettura dell'applicazione

L'applicazione segue un'architettura **MVVM (Model-View-ViewModel)** con elementi di **MVP (Model-View-Presenter)**, garantendo separazione delle responsabilità e facilità di manutenzione.

### Modelli (Models)

- **Host** — proprietà: `ip`, `fqdn`, `enabled`. Rappresenta un singolo record del file `/etc/hosts`; è osservabile per aggiornare l'interfaccia al cambiamento.
- **HostApp** — proprietà: `name`, `info`, `lb` (load balancer), `hosts`. Raggruppa gli host sotto un'applicazione specifica e gestisce i load balancer per l'aggiornamento degli IP.

### Viste (Views)

- **ContentView** — vista principale che contiene l'animazione introduttiva.
- **IntroAnimationView** — animazione iniziale con ASCII art e simulazione di terminale.
- **MainView** — vista principale dopo l'animazione, mostra `EditingView` o `ViewingView` in base allo stato.
- **EditingView / ViewingView** — modalità di modifica e visualizzazione.
- **HeaderView** — intestazione con controlli per musica e modalità di modifica.
- Altre viste personalizzate (righe e modali).

### Controller e Presenter

- **MainViewController** (ViewModel) — proprietà: `apps`, `isEditing`, `isMusicOn`. Metodi principali: `saveChanges()`, `showAddLBModal(for:)`, `updateIPForHost(_:lb:)`. Gestisce lo stato dell'applicazione e l'interazione con la vista.
- **MainPresenter** — proprietà: `apps`, `originalApps` (copia per annullare le modifiche). Metodi principali: `initialize()`, `saveChanges()`, `addApp(_:)`, `removeApp(_:)`, `addHost(_:to:)`, `removeHost(_:)`. Gestisce la logica di business e interagisce con `IOHostParser`.

### Utilità

- **AudioManager** — proprietà `player`; metodi `playBackgroundMusic()`, `pauseBackgroundMusic()`. Gestione centralizzata della musica.
- **IOHostParser** — metodi `parseHostsFile(filePath:)`, `writeHostsFileWithPrivileges(content:)`, `generateOrderedCustomSection(_:)`. Gestisce l'I/O del file hosts, inclusa la gestione dei permessi.

## Flusso logico dell'applicazione

**Avvio e animazione**

1. Il punto di ingresso (`xtr_toolkit_hosts_macosApp`) usa `@main` per avviare `ContentView`.
2. `ContentView` contiene `IntroAnimationView` (ASCII art + simulazione terminale) e avvia la musica tramite `AudioManager`; al termine passa a `MainView` impostando `showMainContent` a `true`.

**Inizializzazione dei dati**

1. `MainViewController` crea un'istanza di `MainPresenter` e chiama `presenter.initialize()` per leggere il file hosts.
2. `IOHostParser.parseHostsFile` legge il file e costruisce il modello (`apps` e `hosts`), gestendo commenti e sezioni personalizzate.
3. `MainViewController` aggiorna la vista con i dati ottenuti.

**Interazione dell'utente**

1. In `ViewingView` l'utente abilita/disabilita gli host tramite toggle; ogni modifica viene salvata automaticamente.
2. In `EditingView` (da "Modifica" in `HeaderView`) l'utente può aggiungere, modificare o eliminare applicazioni e host tramite viste modali.
3. Con "Salva" i cambiamenti vengono scritti tramite `MainPresenter.saveChanges()`, che usa `IOHostParser.writeHostsFileWithPrivileges`.

**Gestione della musica**

- Il toggle in `HeaderView` controlla la musica; `MainViewController` osserva `isMusicOn` e invoca i metodi di `AudioManager`.

**Flusso di esecuzione**

```
[App @main Entry Point]
    |
    v
[ContentView] --> [IntroAnimationView] --(animazione completata)--> [MainView]
                                                    |
                                                    v
                                           [MainViewController] <--Comunicazione bidirezionale--> [MainPresenter]
                                                    |                          |
                                                    v                          v
                                                [Views]                 [IOHostParser]
                                                    |
                                                    v
                                             [User Interactions]
```

## Getting Started

### Prerequisiti

- macOS
- Xcode

### Installazione

1. Clona il repository:
   ```bash
   git clone https://github.com/XtremeAlex/xtr-toolkit-hosts-macos.git
   cd xtr-toolkit-hosts-macos
   ```

2. Apri il progetto in Xcode:
   ```bash
   open xtr-toolkit-hosts-macos.xcodeproj
   ```

3. Seleziona il target desiderato e clicca su `Run` in Xcode.

### Utilizzo

Prima di usare l'app, aggiungere la stringa `##start-xtr-toolkit-host` nel file hosts: indica il punto da cui iniziare la lettura.

## Come contribuire

I contributi sono molto apprezzati.

1. Crea il tuo feature branch (`git checkout -b feature/nome-feature`)
2. Fai commit delle modifiche (`git commit -m "Aggiunge nome-feature"`)
3. Fai push sul branch (`git push origin feature/nome-feature`)
4. Apri una Pull Request

## License

Distribuito sotto licenza MIT. Vedi il file [`LICENSE`](LICENSE) per i dettagli.

## Contatti

Andrei Alexandru Dabija — [LinkedIn](https://www.linkedin.com/in/andrei-alexandru-dabija/) — [github.com/XtremeAlex](https://github.com/XtremeAlex)
