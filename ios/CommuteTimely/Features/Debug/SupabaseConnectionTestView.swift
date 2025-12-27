//
// SupabaseConnectionTestView.swift
// CommuteTimely
//
// Debug view for testing Supabase connectivity and auth configuration
//

import SwiftUI
import Supabase
import OSLog

#if DEBUG
/// A debug view for testing Supabase connectivity and diagnosing connection issues.
/// This view is only available in DEBUG builds.
struct SupabaseConnectionTestView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var keyValidationStatus: KeyValidationStatus = .unknown
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var authStatus: AuthStatus = .unknown
    @State private var refreshSessionStatus: QueryStatus = .unknown
    @State private var todosQueryStatus: QueryStatus = .unknown
    @State private var todos: [Todo] = []
    @State private var errorMessages: [String] = []
    @State private var isRunningTests = false
    @State private var sessionDetails: String = ""
    
    private let supabaseClient: SupabaseClient
    private static let logger = Logger(subsystem: "com.commutetimely.debug", category: "SupabaseTest")
    
    init() {
        // Get the Supabase client from DIContainer
        if let client = DIContainer.shared.supabaseClient {
            self.supabaseClient = client
        } else {
            // Create a client for testing if none exists
            self.supabaseClient = SupabaseClient(
                supabaseURL: URL(string: AppSecrets.supabaseURL)!,
                supabaseKey: AppSecrets.supabaseAnonKey
            )
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Configuration Section
                Section("Configuration") {
                    configRow(title: "Supabase URL", value: AppSecrets.supabaseURL)
                    configRow(title: "Key (masked)", value: maskKey(AppSecrets.supabaseAnonKey))
                    configRow(title: "Key Format", value: keyFormatDescription)
                    configRow(title: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                }
                
                // Key Validation Section
                Section("Key Validation") {
                    statusRow(title: "Key Format Valid", status: keyValidationStatus.displayText, color: keyValidationStatus.color)
                    if keyValidationStatus == .invalid {
                        Text("⚠️ Key should start with 'eyJ' (JWT format)")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Get correct key from: Supabase Dashboard → Project Settings → API → anon key")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Connection Status Section
                Section("Connection Tests") {
                    statusRow(title: "Network Connection", status: connectionStatus.displayText, color: connectionStatus.color)
                    statusRow(title: "Auth Session", status: authStatus.displayText, color: authStatus.color)
                    statusRow(title: "Session Refresh", status: refreshSessionStatus.displayText, color: refreshSessionStatus.color)
                    statusRow(title: "Todos Query", status: todosQueryStatus.displayText, color: todosQueryStatus.color)
                }
                
                // Session Details
                if !sessionDetails.isEmpty {
                    Section("Session Details") {
                        Text(sessionDetails)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // OAuth Configuration Hints
                Section("OAuth Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple Sign-In")
                            .font(.headline)
                        Text("• Service ID must match Supabase Apple provider")
                            .font(.caption)
                        Text("• Redirect URL: https://dvvmlhfyabbfcvrohjip.supabase.co/auth/v1/callback")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google Sign-In")
                            .font(.headline)
                        Text("• Client ID: \(googleClientID)")
                            .font(.caption)
                        Text("• Ensure this matches Supabase Google provider")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Magic Link")
                            .font(.headline)
                        Text("• Redirect URL: commutetimely://auth/callback")
                            .font(.caption)
                        Text("• Add this to Supabase Auth → URL Configuration → Redirect URLs")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Todos Results Section
                if !todos.isEmpty {
                    Section("Todos (\(todos.count) items)") {
                        ForEach(todos) { todo in
                            HStack {
                                Text(todo.title)
                                Spacer()
                                if todo.isComplete == true {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                
                // Error Messages Section
                if !errorMessages.isEmpty {
                    Section("Error Log") {
                        ForEach(errorMessages.indices, id: \.self) { index in
                            Text(errorMessages[index])
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Actions Section
                Section {
                    Button(action: runAllTests) {
                        HStack {
                            if isRunningTests {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isRunningTests ? "Running Tests..." : "Run All Tests")
                        }
                    }
                    .disabled(isRunningTests)
                    
                    Button("Clear Results", role: .destructive) {
                        clearResults()
                    }
                }
                
                // SQL for creating todos table
                Section("Create Todos Table (SQL)") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run this in Supabase SQL Editor:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(todosSQLScript)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Supabase Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await runAllTestsAsync()
        }
    }
    
    // MARK: - Computed Properties
    
    private var keyFormatDescription: String {
        let key = AppSecrets.supabaseAnonKey
        if key.hasPrefix("eyJ") {
            return "JWT (✓ Valid format)"
        } else if key.hasPrefix("sb_") {
            return "sb_ prefix (✗ Invalid - use anon key)"
        } else {
            return "Unknown format (✗ Check key)"
        }
    }
    
    private var googleClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? "Not configured"
    }
    
    private var todosSQLScript: String {
        """
        CREATE TABLE IF NOT EXISTS public.todos (
          id BIGSERIAL PRIMARY KEY,
          title TEXT NOT NULL,
          is_complete BOOLEAN DEFAULT false,
          created_at TIMESTAMPTZ DEFAULT now()
        );
        
        ALTER TABLE public.todos ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY "Allow anon read" ON public.todos
          FOR SELECT USING (true);
        """
    }
    
    // MARK: - Helper Views
    
    private func configRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
        }
    }
    
    private func statusRow(title: String, status: String, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(status)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
    
    private func maskKey(_ key: String) -> String {
        guard key.count > 10 else { return "***" }
        let prefix = String(key.prefix(10))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }
    
    // MARK: - Test Actions
    
    private func runAllTests() {
        Task {
            await runAllTestsAsync()
        }
    }
    
    private func runAllTestsAsync() async {
        isRunningTests = true
        errorMessages.removeAll()
        sessionDetails = ""
        
        Self.logger.info("=== Starting Supabase Connection Tests ===")
        print("[SupabaseTest] === Starting Supabase Connection Tests ===")
        print("[SupabaseTest] URL: \(AppSecrets.supabaseURL)")
        print("[SupabaseTest] Key: \(maskKey(AppSecrets.supabaseAnonKey))")
        
        // Test 0: Validate key format
        validateKeyFormat()
        
        // Test 1: Network connectivity
        await testNetworkConnection()
        
        // Test 2: Auth session
        await testAuthSession()
        
        // Test 3: Refresh session
        await testRefreshSession()
        
        // Test 4: Todos query
        await testTodosQuery()
        
        Self.logger.info("=== Supabase Connection Tests Complete ===")
        print("[SupabaseTest] === Tests Complete ===")
        
        isRunningTests = false
    }
    
    private func validateKeyFormat() {
        let key = AppSecrets.supabaseAnonKey
        
        print("[SupabaseTest] Validating key format...")
        
        // Check if key starts with eyJ (JWT format)
        if key.hasPrefix("eyJ") && key.components(separatedBy: ".").count == 3 {
            // Check for placeholder text
            if key.contains("REPLACE_WITH") || key.contains("YOUR_") {
                keyValidationStatus = .placeholder
                errorMessages.append("⚠️ Key contains placeholder text - replace with real key")
                print("[SupabaseTest] ⚠️ Key contains placeholder text")
            } else {
                keyValidationStatus = .valid
                print("[SupabaseTest] ✅ Key format is valid (JWT)")
            }
        } else if key.hasPrefix("sb_") {
            keyValidationStatus = .invalid
            errorMessages.append("❌ Invalid key format: 'sb_' prefix is NOT a valid Supabase anon key")
            errorMessages.append("💡 Get the correct key from: Supabase Dashboard → Project Settings → API → anon key")
            print("[SupabaseTest] ❌ Invalid key format - 'sb_' prefix is wrong")
        } else {
            keyValidationStatus = .invalid
            errorMessages.append("❌ Key format unrecognized - should start with 'eyJ'")
            print("[SupabaseTest] ❌ Invalid key format - unrecognized")
        }
    }
    
    private func testNetworkConnection() async {
        connectionStatus = .testing
        Self.logger.info("Testing network connection...")
        print("[SupabaseTest] Testing network connection to \(AppSecrets.supabaseURL)")
        
        do {
            guard let url = URL(string: "\(AppSecrets.supabaseURL)/rest/v1/") else {
                throw NSError(domain: "SupabaseTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue(AppSecrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.timeoutInterval = 10
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[SupabaseTest] Network response status: \(httpResponse.statusCode)")
                Self.logger.info("Network response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 400 {
                    connectionStatus = .connected
                    print("[SupabaseTest] ✅ Network connection successful")
                } else if httpResponse.statusCode == 401 {
                    connectionStatus = .failed
                    errorMessages.append("Network: HTTP 401 Unauthorized - Check API key")
                    print("[SupabaseTest] ❌ HTTP 401 - Invalid API key")
                } else {
                    connectionStatus = .failed
                    let message = "HTTP \(httpResponse.statusCode)"
                    errorMessages.append("Network: \(message)")
                    print("[SupabaseTest] ❌ Network connection failed: \(message)")
                }
            }
        } catch {
            connectionStatus = .failed
            let message = error.localizedDescription
            errorMessages.append("Network: \(message)")
            Self.logger.error("Network connection failed: \(message)")
            print("[SupabaseTest] ❌ Network error: \(message)")
            
            // Check for ATS issues
            if message.contains("App Transport Security") || message.contains("ATS") {
                errorMessages.append("💡 Check Info.plist for ATS exceptions")
            }
        }
    }
    
    private func testAuthSession() async {
        authStatus = .testing
        Self.logger.info("Testing auth session...")
        print("[SupabaseTest] Testing auth session...")
        
        do {
            let session = try await supabaseClient.auth.session
            authStatus = .authenticated
            sessionDetails = """
            User ID: \(session.user.id)
            Email: \(session.user.email ?? "N/A")
            Provider: \(session.user.appMetadata["provider"] ?? "unknown")
            Expires: \(Date(timeIntervalSince1970: session.expiresAt))
            """
            print("[SupabaseTest] ✅ Auth session found - User ID: \(session.user.id)")
            Self.logger.info("Auth session found - User ID: \(session.user.id)")
        } catch {
            // Check if it's just "no session" vs actual error
            let errorMessage = error.localizedDescription
            if errorMessage.lowercased().contains("session") || 
               errorMessage.lowercased().contains("not authenticated") ||
               errorMessage.lowercased().contains("no current") {
                authStatus = .notAuthenticated
                sessionDetails = "No active session - user not signed in"
                print("[SupabaseTest] ℹ️ No active auth session (user not signed in)")
                Self.logger.info("No active auth session")
            } else {
                authStatus = .error
                errorMessages.append("Auth: \(errorMessage)")
                print("[SupabaseTest] ❌ Auth error: \(errorMessage)")
                Self.logger.error("Auth error: \(errorMessage)")
            }
        }
    }
    
    private func testRefreshSession() async {
        refreshSessionStatus = .testing
        Self.logger.info("Testing session refresh...")
        print("[SupabaseTest] Testing session refresh...")
        
        do {
            let session = try await supabaseClient.auth.refreshSession()
            refreshSessionStatus = .success
            print("[SupabaseTest] ✅ Session refresh successful - User: \(session.user.id)")
            Self.logger.info("Session refresh successful")
        } catch {
            let errorMessage = error.localizedDescription
            // Not having a session to refresh is expected if not signed in
            if authStatus == .notAuthenticated {
                refreshSessionStatus = .success // N/A really, but not an error
                print("[SupabaseTest] ℹ️ No session to refresh (not signed in)")
            } else {
                refreshSessionStatus = .failed
                errorMessages.append("Refresh: \(errorMessage)")
                print("[SupabaseTest] ❌ Session refresh failed: \(errorMessage)")
            }
        }
    }
    
    private func testTodosQuery() async {
        todosQueryStatus = .testing
        Self.logger.info("Testing todos table query...")
        print("[SupabaseTest] Testing todos table query...")
        
        do {
            let fetchedTodos: [Todo] = try await supabaseClient
                .from("todos")
                .select()
                .execute()
                .value
            
            todos = fetchedTodos
            todosQueryStatus = .success
            print("[SupabaseTest] ✅ Todos query successful - \(fetchedTodos.count) items")
            Self.logger.info("Todos query successful - \(fetchedTodos.count) items")
            
            for todo in fetchedTodos {
                print("[SupabaseTest]   - Todo \(todo.id): \(todo.title)")
            }
        } catch {
            todosQueryStatus = .failed
            let errorMessage = error.localizedDescription
            errorMessages.append("Todos Query: \(errorMessage)")
            print("[SupabaseTest] ❌ Todos query failed: \(errorMessage)")
            Self.logger.error("Todos query failed: \(errorMessage)")
            
            // Check for common issues
            if errorMessage.contains("relation") && errorMessage.contains("does not exist") {
                errorMessages.append("💡 The 'todos' table doesn't exist. Create it in Supabase Dashboard using the SQL above.")
                print("[SupabaseTest] 💡 Hint: Create a 'todos' table in your Supabase Dashboard")
            } else if errorMessage.contains("RLS") || errorMessage.contains("policy") {
                errorMessages.append("💡 RLS policy may be blocking access. Add a policy to allow reads.")
                print("[SupabaseTest] 💡 Hint: Check RLS policies on the 'todos' table")
            } else if errorMessage.contains("Invalid API key") || errorMessage.contains("apikey") || errorMessage.contains("401") {
                errorMessages.append("💡 The Supabase API key is invalid. Check AppSecrets.swift")
                print("[SupabaseTest] 💡 Hint: Verify your Supabase API key is correct")
            }
        }
    }
    
    private func clearResults() {
        keyValidationStatus = .unknown
        connectionStatus = .unknown
        authStatus = .unknown
        refreshSessionStatus = .unknown
        todosQueryStatus = .unknown
        todos = []
        errorMessages = []
        sessionDetails = ""
    }
}

// MARK: - Status Enums

extension SupabaseConnectionTestView {
    enum KeyValidationStatus {
        case unknown, valid, invalid, placeholder
        
        var displayText: String {
            switch self {
            case .unknown: return "Not Tested"
            case .valid: return "Valid (JWT)"
            case .invalid: return "Invalid Format"
            case .placeholder: return "Placeholder"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .valid: return .green
            case .invalid: return .red
            case .placeholder: return .orange
            }
        }
    }
    
    enum ConnectionStatus {
        case unknown, testing, connected, failed
        
        var displayText: String {
            switch self {
            case .unknown: return "Not Tested"
            case .testing: return "Testing..."
            case .connected: return "Connected"
            case .failed: return "Failed"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .testing: return .orange
            case .connected: return .green
            case .failed: return .red
            }
        }
    }
    
    enum AuthStatus {
        case unknown, testing, authenticated, notAuthenticated, error
        
        var displayText: String {
            switch self {
            case .unknown: return "Not Tested"
            case .testing: return "Testing..."
            case .authenticated: return "Authenticated"
            case .notAuthenticated: return "Not Signed In"
            case .error: return "Error"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .testing: return .orange
            case .authenticated: return .green
            case .notAuthenticated: return .yellow
            case .error: return .red
            }
        }
    }
    
    enum QueryStatus {
        case unknown, testing, success, failed
        
        var displayText: String {
            switch self {
            case .unknown: return "Not Tested"
            case .testing: return "Testing..."
            case .success: return "Success"
            case .failed: return "Failed"
            }
        }
        
        var color: Color {
            switch self {
            case .unknown: return .secondary
            case .testing: return .orange
            case .success: return .green
            case .failed: return .red
            }
        }
    }
}

#Preview {
    SupabaseConnectionTestView()
}
#endif
