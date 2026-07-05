//
//  PhotoAlbumSheet.swift
//  anyapp
//

import PhotosUI
import SwiftUI

struct PhotoAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedItems: [PhotosPickerItem]

    var body: some View {
        NavigationStack {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                EmptyView()
            }
            .photosPickerStyle(.inline)
            .navigationTitle("사진")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title2)
                    }
                    .accessibilityIdentifier("closePhotoAlbumButton")
                    .accessibilityLabel("닫기")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("photoAlbumSheet")
    }
}

#Preview {
    PhotoAlbumSheet(selectedItems: .constant([]))
}
