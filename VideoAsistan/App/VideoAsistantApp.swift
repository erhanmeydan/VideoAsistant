import SwiftUI

@main
struct VideoAsistantApp: App {
    init() {
        // Terminalden çalıştırılan komut satırı modlarında arayüz açılmadan
        // iş yapılır ve süreç doğrudan sonlanır.
        if let command = CLICommand.parse(arguments: CommandLine.arguments) {
            exit(CLICommand.run(command))
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
