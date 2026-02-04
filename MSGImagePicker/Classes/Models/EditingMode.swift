//
//  EditingMode.swift
//  MSGImagePicker
//
//  Enum representing the available editing modes for media.
//

import Foundation

/// Represents the available editing modes for media in the MediaEditView.
public enum EditingMode: String, CaseIterable, Sendable {
    /// Crop mode for adjusting image boundaries.
    case crop
    
    // Future modes:
    // case filter
    // case text
    // case draw
}
