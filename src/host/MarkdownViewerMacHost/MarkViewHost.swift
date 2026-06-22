import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var handledActivation = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        let args = Array(CommandLine.arguments.dropFirst())
        if !args.isEmpty {
            handleInputs(args)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            if !self.handledActivation {
                self.showHelpAndExit()
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        handleInputs(filenames)
        sender.reply(toOpenOrPrint: .success)
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              !urlString.isEmpty else {
            finishSoon()
            return
        }

        handleInputs([urlString])
    }

    private func handleInputs(_ inputs: [String]) {
        handledActivation = true

        for input in inputs where !input.isEmpty {
            do {
                try launchPowerShell(input: input)
            } catch {
                showError("Could not open Markdown file.\n\n\(error.localizedDescription)")
            }
        }

        finishSoon()
    }

    private func launchPowerShell(input: String) throws {
        guard let resourcesURL = Bundle.main.resourceURL else {
            throw HostError.missingResources
        }

        let pwshURL = resourcesURL.appendingPathComponent("pwsh/pwsh")
        let scriptURL = resourcesURL.appendingPathComponent("app/Open-Markdown.ps1")

        guard FileManager.default.isExecutableFile(atPath: pwshURL.path) else {
            throw HostError.missingPowerShell(pwshURL.path)
        }

        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw HostError.missingEngine(scriptURL.path)
        }

        let process = Process()
        process.executableURL = pwshURL
        process.arguments = [
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", scriptURL.path,
            "-Path", input
        ]
        process.currentDirectoryURL = resourcesURL.appendingPathComponent("app")

        try process.run()
    }

    private func showHelpAndExit() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "MarkView"
        alert.informativeText = "Open a Markdown file with MarkView from Finder, or use a mdview: link from a rendered document."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        finishSoon()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "MarkView"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func finishSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApplication.shared.terminate(nil)
        }
    }
}

enum HostError: LocalizedError {
    case missingResources
    case missingPowerShell(String)
    case missingEngine(String)

    var errorDescription: String? {
        switch self {
        case .missingResources:
            return "The app bundle resources directory could not be found."
        case .missingPowerShell(let path):
            return "Bundled PowerShell was not found or is not executable at \(path)."
        case .missingEngine(let path):
            return "The MarkView engine was not found at \(path)."
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
