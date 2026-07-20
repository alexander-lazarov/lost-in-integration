//
//  ShareSheet.swift
//  Lost in Integration
//
//  Thin UIActivityViewController wrapper so a prepared export .zip can be
//  handed to the iOS share sheet (AirDrop, Save to Files, iCloud, …).
//

import SwiftUI
import UIKit

/// Identifiable wrapper so a URL can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
