//
// AccountView.swift
// CommuteTimely
//
// Simple account management view
//

import SwiftUI
import PhotosUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = AccountViewModel()
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .task { vm.loadProfile() }
                .overlay { loadingOverlay }
                .onChange(of: vm.selectedPhotoItem) { _, newValue in
                    if newValue != nil {
                        vm.handlePhotoSelection()
                    }
                }
                .onChange(of: vm.accountDeleted) { _, deleted in
                    if deleted {
                        handleAccountDeleted()
                    }
                }
                .alert("Delete Account?", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        vm.deleteAccount()
                    }
                } message: {
                    Text("This action cannot be undone. All your data will be permanently deleted.")
                }
        }
    }
    
    // MARK: - Form Content
    
    private var formContent: some View {
        Form {
            photoSection
            profileSection
            accountInfoSection
            errorSection
            successSection
            deleteSection
        }
    }
    
    // MARK: - Sections
    
    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    profileImage
                    
                    PhotosPicker(
                        selection: $vm.selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Text("Change Photo")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .disabled(vm.isUploadingPhoto)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }
    
    private var profileSection: some View {
        Section("Profile") {
            TextField("Full Name", text: $vm.fullName)
            TextField("First Name", text: $vm.firstName)
        }
    }
    
    private var accountInfoSection: some View {
        Section("Account Info") {
            HStack {
                Text("Email")
                Spacer()
                Text(vm.email)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let error = vm.errorMessage {
            Section {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    @ViewBuilder
    private var successSection: some View {
        if vm.saveSuccess {
            Section {
                Text("Profile saved successfully!")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Account")
                    Spacer()
                }
            }
            .disabled(vm.isDeleting)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                vm.saveProfile()
            }
            .disabled(vm.isSaving || vm.isUploadingPhoto)
        }
    }
    
    // MARK: - Loading Overlay
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if vm.isLoading || vm.isUploadingPhoto || vm.isDeleting {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(loadingMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
    }
    
    private var loadingMessage: String {
        if vm.isDeleting {
            return "Deleting account..."
        } else if vm.isUploadingPhoto {
            return "Uploading photo..."
        } else {
            return "Loading..."
        }
    }
    
    // MARK: - Profile Image View
    
    private var profileImage: some View {
        profileImageContent
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
            )
            .overlay(cameraIconOverlay)
            .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var profileImageContent: some View {
        if let selectedImage = vm.selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if !vm.avatarUrl.isEmpty, let url = URL(string: vm.avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderImage
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }
    
    private var cameraIconOverlay: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding(6)
            .background(Color.blue)
            .clipShape(Circle())
            .offset(x: 35, y: 35)
    }
    
    private var placeholderImage: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundColor(.gray)
    }
    
    // MARK: - Actions
    
    private func handleAccountDeleted() {
        URLCache.shared.removeAllCachedResponses()
        NotificationCenter.default.post(name: .accountDeleted, object: nil)
        dismiss()
    }
}

#Preview {
    AccountView()
}

// MARK: - Notification Extension

extension Notification.Name {
    static let accountDeleted = Notification.Name("accountDeleted")
}
