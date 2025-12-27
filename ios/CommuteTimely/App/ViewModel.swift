//
// ViewModel.swift
// CommuteTimely
//
// Base protocol for ViewModels with common lifecycle and state management
//

import Foundation
import Combine

protocol ViewModel: ObservableObject {
    func onAppear()
    func onDisappear()
}

extension ViewModel {
    func onAppear() {}
    func onDisappear() {}
}

// MARK: - View State

enum ViewState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - Base ViewModel Implementation

@MainActor
class BaseViewModel: ObservableObject {
    @Published var state: ViewState = .idle
    
    var cancellables = Set<AnyCancellable>()
    
    func onAppear() {}
    func onDisappear() {
        cancellables.removeAll()
    }
    
    func setLoading() {
        state = .loading
    }
    
    func setLoaded() {
        state = .loaded
    }
    
    func setError(_ message: String) {
        state = .error(message)
    }
    
    func setError(_ error: Error) {
        state = .error(error.localizedDescription)
    }
    
    func resetState() {
        state = .idle
    }
}

