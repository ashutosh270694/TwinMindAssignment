import Foundation
import SwiftData
import Combine

/// Manages SwiftData persistent container and provides access to model context
final class SwiftDataStack: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    // MARK: - Publishers
    
    var contextPublisher: AnyPublisher<ModelContext, Never> {
        return Just(modelContext).eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() throws {
        // Define the schema with all models
        let schema = Schema([
            RecordingSession.self,
            TranscriptSegment.self
        ])
        
        // Configure model configuration with migration options
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        // Create model container
        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            self.modelContext = ModelContext(modelContainer)
            
            print("SwiftDataStack: Successfully initialized persistent container")
        } catch {
            print("SwiftDataStack: Failed to create model container: \(error)")
            throw error
        }
    }
    
    /// Preview initializer for SwiftUI previews
    init(preview: Bool = false) throws {
        // Define the schema with all models
        let schema = Schema([
            RecordingSession.self,
            TranscriptSegment.self
        ])
        
        // Configure model configuration
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: preview,
            allowsSave: true
        )
        
        // Create model container
        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            self.modelContext = ModelContext(modelContainer)
            
            if preview {
                print("SwiftDataStack: Preview mode initialized")
            } else {
                print("SwiftDataStack: Successfully initialized persistent container")
            }
        } catch {
            print("SwiftDataStack: Failed to create model container: \(error)")
            throw error
        }
    }
    
    // MARK: - Public Methods
    
    /// Returns the main model context
    func getContext() -> ModelContext {
        return modelContext
    }
    
    /// Saves the current context
    func save() throws {
        try modelContext.save()
    }
    
    /// Performs a background save operation
    func saveInBackground() async throws {
        try modelContext.save()
        print("SwiftDataStack: Background save completed")
    }
    
    /// Deletes all data (for testing purposes)
    func deleteAllData() throws {
        let fetchDescriptor = FetchDescriptor<RecordingSession>()
        let sessions = try modelContext.fetch(fetchDescriptor)
        
        for session in sessions {
            modelContext.delete(session)
        }
        
        try modelContext.save()
        print("SwiftDataStack: All data deleted")
    }
    
    /// Performs a lightweight migration if needed
    func performMigrationIfNeeded() {
        // SwiftData handles most migrations automatically
        // This method can be extended for custom migration logic
        print("SwiftDataStack: Migration check completed")
    }
}

// MARK: - Preview Support

extension SwiftDataStack {
    /// Creates an in-memory stack for SwiftUI previews
    static func createPreview() -> SwiftDataStack {
        do {
            return try SwiftDataStack(preview: true)
        } catch {
            fatalError("Failed to create preview SwiftDataStack: \(error)")
        }
    }
} 