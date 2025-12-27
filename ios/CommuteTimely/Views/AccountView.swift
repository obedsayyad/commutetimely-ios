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
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo Section
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
                
                Section("Profile") {
                    TextField("Full Name", text: $vm.fullName)
                    TextField("First Name", text: $vm.firstName)
                }
                
                Section("Account Info") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(vm.email)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = vm.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if vm.saveSuccess {
                    Section {
                        Text("Profile saved successfully!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .task {
                vm.loadProfile()
            }
            .overlay {
                if vm.isLoading || vm.isUploadingPhoto {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(vm.isUploadingPhoto ? "Uploading photo..." : "Loading...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
            }
            .onChange(of: vm.selectedPhotoItem) { _, newValue in
                if newValue != nil {
                    vm.handlePhotoSelection()
                }
            }
        }
    }
    
    // MARK: - Profile Image View
    
    private var profileImage: some View {
        Group {
            // Show selected image first (if available), then URL, then placeholder
            if let selectedImage = vm.selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let urlString = vm.avatarUrl.isEmpty ? nil : vm.avatarUrl,
                      let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
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
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
        )
        .overlay(
            // Camera icon overlay
            Image(systemName: "camera.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.blue)
                .clipShape(Circle())
                .offset(x: 35, y: 35)
        )
        .padding(.vertical, 12)
    }
    
    private var placeholderImage: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundColor(.gray)
    }
}

#Preview {
    AccountView()
}
