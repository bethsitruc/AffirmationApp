//
//  AffirmationAppApp.swift
//  AffirmationApp
//
//  Created by Bethany Curtis on 4/4/25.
//
import AffirmationShared
import SwiftUI

@main
struct AffirmationAppApp: App {
    var body: some Scene {
        WindowGroup {
            AffirmationView(store: AffirmationStore())
        }
    }
}
