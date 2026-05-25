// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import CMAFKitCommands

@main
struct CMAFKitCLI {
    static func main() async {
        await CMAFKitCommand.main()
    }
}
