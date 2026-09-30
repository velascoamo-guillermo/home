//
//  HomeApp.swift
//  Home
//
//  Created by Guillermo Velasco on 15/5/26.
//

import SwiftUI

@main
struct HomeApp: App {
    #if os(macOS)
    @State private var mac = MacAppState()
    #endif

    var body: some Scene {
        #if os(macOS)
        MacScenes(app: mac)
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
