//
// AccountViewModel.swift
// CommuteTimely
//
// ViewModel for Account/Profile management
//

import Foundation
import Combine
import SwiftUI
import PhotosUI

@MainActor
final class AccountViewModel: ObservableObject {

    @Published var fullName: String = ""
    @Published var firstName: String = ""
    @Published var email: String = ""
    @Published var avatarUrl: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isUploadingPhoto: Bool = false
    @Published var saveSuccess: Bool = false
    
    // For photo picker
    @Published var selectedPhotoItem: PhotosPickerItem? = nil
    @Published var selectedImage: UIImage? = nil

    func loadProfile() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let profile = try await SupabaseService.shared.fetchUserProfile()
                fullName = profile.fullName ?? ""
                firstName = profile.firstName ?? ""
                email = profile.email ?? ""
                avatarUrl = profile.avatarUrl ?? ""
            } catch {
                // Profile might not exist yet - that's okay for new users
                print("Profile load error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    func saveProfile() {
        Task {
            isSaving = true
            errorMessage = nil
            saveSuccess = false
            do {
                try await SupabaseService.shared.saveUserProfile(
                    fullName: fullName,
                    firstName: firstName,
                    avatarUrl: avatarUrl.isEmpty ? nil : avatarUrl
                )
                saveSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
    
    func handlePhotoSelection() {
        guard let item = selectedPhotoItem else { return }
        
        Task {
            isUploadingPhoto = true
            errorMessage = nil
            
            do {
                // Load the image data
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = "Failed to load image"
                    isUploadingPhoto = false
                    return
                }
                
                // Convert to UIImage and then to PNG
                guard let uiImage = UIImage(data: data) else {
                    errorMessage = "Failed to process image"
                    isUploadingPhoto = false
                    return
                }
                
                // Convert to PNG data
                guard let pngData = uiImage.pngData() else {
                    errorMessage = "Failed to convert image"
                    isUploadingPhoto = false
                    return
                }
                
                // Upload to Supabase Storage
                let newAvatarUrl = try await SupabaseService.shared.uploadAvatar(imageData: pngData)
                
                // Update local state
                avatarUrl = newAvatarUrl
                selectedImage = uiImage
                
                // Save profile with new avatar URL
                try await SupabaseService.shared.saveUserProfile(
                    fullName: fullName,
                    firstName: firstName,
                    avatarUrl: newAvatarUrl
                )
                
                saveSuccess = true
                
            } catch {
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
            
            isUploadingPhoto = false
            selectedPhotoItem = nil
        }
    }
}
