# MSGImagePicker

A pure SwiftUI media picker for selecting photos and videos from the photo library.

## Features

- Multi-selection with configurable maximum limit
- Ordered selection tracking with numbered badges
- Support for both photos and videos
- Action bar with edit button, caption input, and send button
- Presentation-agnostic (works with sheets, fullscreen, navigation push)
- No external dependencies (uses only system Photos framework)

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### CocoaPods

Add the following to your Podfile:

```ruby
pod 'MSGImagePicker'
```

## Usage

```swift
import MSGImagePicker

struct ContentView: View {
    @State private var showPicker = false
    
    var body: some View {
        Button("Select Media") {
            showPicker = true
        }
        .sheet(isPresented: $showPicker) {
            MSGImagePicker(
                config: MSGImagePickerConfig(maxSelection: 5),
                onCancel: {
                    showPicker = false
                },
                onSend: { selectedMedia in
                    // Handle selected media
                    print("Selected \(selectedMedia.count) items")
                    showPicker = false
                }
            )
        }
    }
}
```

## Configuration

```swift
public struct MSGImagePickerConfig {
    public var maxSelection: Int        // Maximum number of selectable items (default: 10)
    public var allowsVideo: Bool        // Allow video selection (default: true)
    public var allowsPhoto: Bool        // Allow photo selection (default: true)
    public var showsCaptions: Bool      // Show caption input field (default: true)
}
```

## Output

The `onSend` callback receives an array of `PickedMedia` objects:

```swift
public struct PickedMedia {
    public let id: String
    public let asset: PHAsset           // Original asset reference
    public var editedImage: UIImage?    // Edited image (nil if not edited)
    public var editedVideoURL: URL?     // Edited video URL (nil if not edited)
    public var caption: String          // User-entered caption
    public let selectionOrder: Int      // Order of selection (1-based)
}
```

## License

MSGImagePicker is available under the MIT license. See the LICENSE file for more info.
