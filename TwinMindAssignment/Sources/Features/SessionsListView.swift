import SwiftUI
import Combine

/// View for displaying a list of recording sessions with search and pagination
struct SessionsListView: View {
    
    @StateObject private var viewModel = SessionsListViewModel()
    @Environment(\.environmentHolder) private var environment
    @State private var selectedSession: RecordingSession?
    @State private var showingPlayback = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New") {
                        viewModel.createNewSession()
                    }
                }
            }
            .onAppear {
                viewModel.setup(with: environment)
                viewModel.loadSessions()
            }
            .onDisappear {
                viewModel.cleanup()
            }
            .sheet(isPresented: $showingPlayback) {
                if let session = selectedSession {
                    SessionPlaybackView(session: session)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search sessions...", text: $viewModel.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !viewModel.searchQuery.isEmpty {
                Button("Clear") {
                    viewModel.searchQuery = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading sessions...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No sessions found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Start recording to create your first session")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Start Recording") {
                viewModel.createNewSession()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var sessionsList: some View {
        List {
            ForEach(viewModel.groupedSessions.keys.sorted(by: >), id: \.self) { date in
                Section(header: dateHeader(for: date)) {
                    ForEach(viewModel.groupedSessions[date] ?? [], id: \.id) { session in
                        SessionRowView(session: session)
                            .onTapGesture {
                                selectedSession = session
                                showingPlayback = true
                            }
                    }
                }
            }
            
            // Pagination indicator
            if viewModel.hasMorePages {
                HStack {
                    Spacer()
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Load More") {
                            viewModel.loadMoreSessions()
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await viewModel.refreshSessions()
        }
    }
    
    private func dateHeader(for date: Date) -> some View {
        HStack {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(viewModel.groupedSessions[date]?.count ?? 0) sessions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: RecordingSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Play Button Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(session.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    StatusChip.forNetworkStatus(isOnline: true) // This would come from environment
                }
                
                HStack {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(session.segments.count) segments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
final class SessionsListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var sessions: [RecordingSession] = []
    @Published var searchQuery = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var repository: RecordingSessionRepositoryProtocol?
    private var searchDebounceTimer: Timer?
    
    // MARK: - Computed Properties
    
    var groupedSessions: [Date: [RecordingSession]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }
        return grouped
    }
    
    // MARK: - Public Methods
    
    func setup(with environment: EnvironmentHolder) {
        self.repository = environment.recordingSessionRepository
        setupSearchDebouncing()
    }
    
    func cleanup() {
        cancellables.removeAll()
        searchDebounceTimer?.invalidate()
    }
    
    func loadSessions() {
        guard let repository = repository else { return }
        
        isLoading = true
        
        repository.fetchSessions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("Failed to load sessions: \(error)")
                    }
                },
                receiveValue: { [weak self] sessions in
                    self?.sessions = sessions
                }
            )
            .store(in: &cancellables)
    }
    
    func loadMoreSessions() {
        guard let _ = repository, hasMorePages else { return }
        
        isLoadingMore = true
        
        // This would implement actual pagination
        // For now, just simulate loading more
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isLoadingMore = false
            self?.hasMorePages = false
        }
    }
    
    func refreshSessions() async {
        await MainActor.run {
            loadSessions()
        }
    }
    
    func createNewSession() {
        // This would navigate to recording view or create a new session
        print("Create new session")
    }
    
    func selectSession(_ session: RecordingSession) {
        // This would navigate to session detail view
        print("Selected session: \(session.title)")
    }
    
    // MARK: - Private Methods
    
    private func setupSearchDebouncing() {
        $searchQuery
            .sink { [weak self] query in
                self?.searchDebounceTimer?.invalidate()
                
                self?.searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    DispatchQueue.main.async {
                        self?.performSearch(query: query)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        guard let repository = repository else { return }
        
        if query.isEmpty {
            loadSessions()
        } else {
            isLoading = true
            
            repository.searchSessions(query: query)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            print("Search failed: \(error)")
                        }
                    },
                    receiveValue: { [weak self] sessions in
                        self?.sessions = sessions
                    }
                )
                .store(in: &cancellables)
        }
    }
}

// MARK: - Preview

struct SessionsListView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsListView()
            .environmentHolder(EnvironmentHolder.createForPreview())
    }
}

struct SessionRowView_Previews: PreviewProvider {
    static var previews: some View {
        let session = RecordingSession(
            title: "Sample Recording Session",
            notes: "This is a sample recording session with some notes for testing purposes."
        )
        
        SessionRowView(session: session)
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 