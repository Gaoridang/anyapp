//
//  PhotoAlbumSheet.swift
//  anyapp
//

import PhotosUI
import SwiftUI

struct PhotoAlbumSheet: View {
    @Binding var selectedItems: [PhotosPickerItem]

    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 10,
            matching: .images
        ) {
            EmptyView()
        }
        .photosPickerStyle(.inline)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("photoAlbumSheet")
    }
}

#Preview {
    PhotoAlbumSheet(selectedItems: .constant([]))
}
