//
//  ContentView.swift
//  TwinMindAssignment
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("TwinMind Assignment")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Audio Recording & Transcription App")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Audio Engine: \(EnvironmentHolder.useFakes ? "Fake (Preview)" : "Production (AVAudioEngine)")")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                NavigationLink(destination: RecordingView()) {
                    Text("Start Recording")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                NavigationLink(destination: SessionsListView()) {
                    Text("View Sessions")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                
                NavigationLink(destination: SettingsView()) {
                    Text("Settings")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("TwinMind")
        }
    }
}

#Preview {
    ContentView()
}
