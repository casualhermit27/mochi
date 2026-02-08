import SwiftUI

struct KeypadView: View {
    let onTap: (String) -> Void
    var onLongPress: ((String) -> Void)? = nil // NEW: Long press callback
    var textColor: Color 
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(1...9, id: \.self) { num in
                KeypadButton(text: "\(num)", onTap: onTap, onLongPress: onLongPress, color: textColor)
            }
            
            // Bottom row
            KeypadButton(text: ".", onTap: onTap, onLongPress: nil, color: textColor)
            KeypadButton(text: "0", onTap: onTap, onLongPress: nil, color: textColor)
            
            // Backspace with repeat logic
            KeypadButton(text: "backspace", onTap: onTap, onLongPress: nil, color: textColor, isBackspace: true)
            .buttonStyle(SquishyButtonStyle())
        }
        .padding(.horizontal, 40)
    }
}

struct KeypadButton: View {
    let text: String
    let onTap: (String) -> Void
    var onLongPress: ((String) -> Void)? // NEW
    var color: Color
    var isBackspace: Bool = false
    
    @State private var pressStartTime: Date?
    @State private var timer: Timer?            // Restored
    @State private var isLongPressing = false   // Restored
    
    var body: some View {
        ZStack {
            // Background & Touch Target
            Circle()
                .fill(Color.gray.opacity(isLongPressing ? 0.2 : 0.001))
                .frame(width: 80, height: 80)
            
            if isBackspace {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .foregroundColor(color)
                    .opacity(isLongPressing ? 0.8 : 1.0)
            } else {
                Text(text)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .contentShape(Circle()) // Helper for hit testing
        .scaleEffect(isLongPressing ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLongPressing)
        // Unified Gesture Logic
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isLongPressing {
                        isLongPressing = true
                        pressStartTime = Date()
                        
                        if isBackspace {
                            // Backspace Immediate Trigger
                            HapticManager.shared.lightImpact()
                            onTap(text)
                            
                            // Repeat Logic for Backspace
                            timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                                timer?.invalidate()
                                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                                    HapticManager.shared.lightImpact()
                                    onTap(text)
                                }
                            }
                        } else {
                            // Standard Key: Wait for long press threshold
                            if let onLongPress = onLongPress {
                                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    // Long Press Triggered
                                    onLongPress(text)
                                    timer?.invalidate()
                                    timer = nil
                                    // Prevent tap on release by invalidating start time (optional flag check)
                                    pressStartTime = nil 
                                }
                            }
                        }
                    }
                }
                .onEnded { _ in
                    isLongPressing = false
                    timer?.invalidate()
                    timer = nil
                    
                    // Tap Logic (Only if not backspace, as backspace handles on changed)
                    if !isBackspace {
                         // Check if it was a short tap (pressStartTime is non-nil means timer didn't fire long press yet)
                        if let start = pressStartTime {
                             onTap(text)
                        }
                    }
                    pressStartTime = nil
                }
        )
    }
}

struct SquishyButtonStyle: ButtonStyle {
    var isDoneButton = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Group {
                    if !isDoneButton {
                        Circle()
                            .fill(Color.gray.opacity(configuration.isPressed ? 0.2 : 0.0)) // Neutral squish color
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}
