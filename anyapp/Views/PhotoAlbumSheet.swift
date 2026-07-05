//
//  PhotoAlbumSheet.swift
//  anyapp
//

import PhotosUI
import SwiftUI

struct PhotoAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedItems: [PhotosPickerItem]
    @State private var detent: PresentationDetent = .large

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
            .photosPickerAccessoryVisibility(.visible, edges: .top)
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("photoAlbumSheet")
        .onChange(of: selectedItems) { oldValue, newValue in
            if !oldValue.isEmpty, newValue.isEmpty {
                dismiss()
            }
        }
    }
}

#Preview {
    PhotoAlbumSheet(selectedItems: .constant([]))
}
