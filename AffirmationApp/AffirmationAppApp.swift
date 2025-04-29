//
//  AffirmationAppApp.swift
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/4/25.
//
//  This is the entry point of the AffirmationApp.
//  It defines the main structure conforming to the App protocol,
//  and sets up the initial window and view hierarchy.
//

import AffirmationShared
import SwiftUI

@main // Marks this as the entry point of the SwiftUI app.
struct AffirmationAppApp: App {
    var body: some Scene {
        // Defines a group of windows; in iOS this usually means the main app window.
        WindowGroup {
            // Loads the main view of the app and injects the shared AffirmationStore instance.
            AffirmationView(store: AffirmationStore())
        }
    }
}
