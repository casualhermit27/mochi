import SwiftUI

struct KeypadView: View {
    let onTap: (String) -> Void
    var textColor: Color // Added support for dynamic color
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(1...9, id: \.self) { num in
                KeypadButton(text: "\(num)", onTap: onTap, color: textColor)
            }
            
            // Bottom row
            KeypadButton(text: ".", onTap: onTap, color: textColor)
            KeypadButton(text: "0", onTap: onTap, color: textColor)
            
            // Backspace with repeat logic
            KeypadButton(text: "backspace", onTap: onTap, color: textColor, isBackspace: true)
            .buttonStyle(SquishyButtonStyle())
        }
        .padding(.horizontal, 40)
    }
}

struct KeypadButton: View {
    let text: String
    let onTap: (String) -> Void
    var color: Color
    var isBackspace: Bool = false
    
    @State private var timer: Timer?
    @State private var isLongPressing = false
    
    var body: some View {
        if isBackspace {
            // Backspace: Gesture-based for repeating delete
            let pressGesture = DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isLongPressing {
                        isLongPressing = true
                        // Initial tap
                        HapticManager.shared.lightImpact()
                        onTap(text)
                        
                        // Delay before rapid fire
                        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
                            // Start rapid fire
                            timer?.invalidate()
                            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                                HapticManager.shared.lightImpact()
                                onTap(text)
                            }
                        }
                    }
                }
                .onEnded { _ in
                    isLongPressing = false
                    timer?.invalidate()
                    timer = nil
                }
            
            ZStack {
                // Background for touch target (Visual feedback)
                Circle()
                    .fill(Color.gray.opacity(isLongPressing ? 0.2 : 0.001))
                
                Image(systemName: "delete.left")
                    .font(.title2)
                    .foregroundColor(color)
                    .opacity(isLongPressing ? 0.8 : 1.0)
            }
            .frame(width: 80, height: 80)
            .contentShape(Circle()) // Increases touch area
            .simultaneousGesture(pressGesture)
            .scaleEffect(isLongPressing ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLongPressing)
            
        } else {
            // Standard Keys: Button-based (tap on release)
            Button(action: { onTap(text) }) {
                Text(text)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
                    .frame(width: 80, height: 80)
                    .background(Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(SquishyButtonStyle())
        }
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
