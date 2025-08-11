import Foundation
import Combine

/// Custom retry operator with exponential backoff strategy
extension Publisher {
    
    /// Retries the publisher with exponential backoff strategy
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - baseDelay: Base delay in seconds for the first retry
    ///   - shouldRetry: Optional closure to determine if retry should be attempted
    /// - Returns: Publisher that retries on failure with exponential backoff
    func retryBackoff(
        maxRetries: Int,
        baseDelay: TimeInterval,
        shouldRetry: ((Self.Failure) -> Bool)? = nil
    ) -> AnyPublisher<Self.Output, Self.Failure> {
        
        return self.catch { error -> AnyPublisher<Self.Output, Self.Failure> in
            // Check if we should retry this error
            if let shouldRetry = shouldRetry, !shouldRetry(error) {
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            // Create retry publisher with exponential backoff
            return RetryBackoffPublisher(
                upstream: self,
                maxRetries: maxRetries,
                baseDelay: baseDelay,
                currentRetry: 0
            ).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

/// Internal publisher that handles retry logic with exponential backoff
private struct RetryBackoffPublisher<Upstream: Publisher>: Publisher {
    
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure
    
    let upstream: Upstream
    let maxRetries: Int
    let baseDelay: TimeInterval
    let currentRetry: Int
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = RetryBackoffSubscription(
            upstream: upstream,
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            currentRetry: currentRetry,
            subscriber: subscriber
        )
        subscriber.receive(subscription: subscription)
    }
}

/// Subscription that manages retry attempts
private final class RetryBackoffSubscription<Upstream: Publisher, S: Subscriber>: Subscription 
where S.Input == Upstream.Output, S.Failure == Upstream.Failure {
    
    private let upstream: Upstream
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let currentRetry: Int
    private let subscriber: S
    
    private var cancellables = Set<AnyCancellable>()
    private var demand: Subscribers.Demand = .none
    
    init(
        upstream: Upstream,
        maxRetries: Int,
        baseDelay: TimeInterval,
        currentRetry: Int,
        subscriber: S
    ) {
        self.upstream = upstream
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.currentRetry = currentRetry
        self.subscriber = subscriber
    }
    
    func request(_ demand: Subscribers.Demand) {
        self.demand = demand
        
        if currentRetry <= maxRetries {
            attemptRequest()
        } else {
            // Max retries exceeded, forward the error
            let error = NSError(domain: "RetryBackoff", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"])
            subscriber.receive(completion: .failure(error as! S.Failure))
        }
    }
    
    func cancel() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    private func attemptRequest() {
        upstream
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleFailure(error)
                    }
                }
            )
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.subscriber.receive(completion: completion)
                },
                receiveValue: { [weak self] value in
                    _ = self?.subscriber.receive(value)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleFailure(_ error: Upstream.Failure) {
        guard currentRetry < maxRetries else {
            // Max retries exceeded
            subscriber.receive(completion: .failure(error))
            return
        }
        
        // Calculate delay with exponential backoff
        let delay = baseDelay * pow(2.0, Double(currentRetry))
        
        // Schedule retry
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.retry()
        }
    }
    
    private func retry() {
        // Create new retry publisher for the next attempt
        let retryPublisher = RetryBackoffPublisher(
            upstream: upstream,
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            currentRetry: currentRetry + 1
        )
        
        retryPublisher
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.subscriber.receive(completion: completion)
                },
                receiveValue: { [weak self] value in
                    _ = self?.subscriber.receive(value)
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Convenience Extensions

extension Publisher {
    
    /// Retries the publisher with default settings (5 retries, 1 second base delay)
    func retryBackoff() -> AnyPublisher<Self.Output, Self.Failure> {
        return retryBackoff(maxRetries: 5, baseDelay: 1.0)
    }
    
    /// Retries the publisher with custom retry condition
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - baseDelay: Base delay in seconds for the first retry
    ///   - retryCondition: Closure that determines if retry should be attempted
    /// - Returns: Publisher that retries on failure with exponential backoff
    func retryBackoff(
        maxRetries: Int,
        baseDelay: TimeInterval,
        retryCondition: @escaping (Self.Failure) -> Bool
    ) -> AnyPublisher<Self.Output, Self.Failure> {
        return retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay, shouldRetry: retryCondition)
    }
} 