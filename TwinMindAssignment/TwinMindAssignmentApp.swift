//
//  TwinMindAssignmentApp.swift
//  TwinMindAssignment
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import SwiftUI

@main
struct TwinMindAssignmentApp: App {
    @State private var showingStartupTests = true
    @State private var startupTestsPassed = false
    
    var body: some Scene {
        WindowGroup {
            if showingStartupTests {
                StartupTestView()
                    .onReceive(NotificationCenter.default.publisher(for: .startupTestsCompleted)) { _ in
                        print("📱 Main app received startupTestsCompleted notification!")
                        print("📱 Transitioning from startup tests to main app...")
                        showingStartupTests = false
                        print("📱 showingStartupTests set to false")
                    }
            } else {
                ContentView()
                    .environmentHolder(EnvironmentHolder.createDefault())
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startupTestsCompleted = Notification.Name("startupTestsCompleted")
}
