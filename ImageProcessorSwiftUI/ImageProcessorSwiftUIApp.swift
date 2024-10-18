//
//  ImageProcessorSwiftUIApp.swift
//  ImageProcessorSwiftUI
//
//  Created by Justin on 10/18/24.
//

import SwiftUI

@main
struct ImageProcessorSwiftUIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
