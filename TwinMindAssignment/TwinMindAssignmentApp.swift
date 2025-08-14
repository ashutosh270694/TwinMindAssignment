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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentHolder(EnvironmentHolder.createDefault())
        }
    }
}
