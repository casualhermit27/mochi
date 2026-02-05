import SwiftUI

struct PaymentMethodSelector: View {
    @ObservedObject var settings = SettingsManager.shared
    @Binding var isVisible: Bool
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    var onAddRequest: () -> Void // Callback to open card screen
    
    private let itemWidth: CGFloat = 80 // Reduced from 110
    
    var body: some View {
        GeometryReader { outerProxy in
            let screenWidth = outerProxy.size.width
            let sideInset = (screenWidth - itemWidth) / 2
            
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        // Existing Payment Methods
                        ForEach(settings.paymentMethods) { method in
                            PaymentMethodDialItem(
                                method: method,
                                dynamicText: dynamicText,
                                screenWidth: screenWidth,
                                onCenter: {
                                    if settings.selectedPaymentMethodId != method.id.uuidString {
                                        HapticManager.shared.selection()
                                        settings.selectPaymentMethod(method)
                                    }
                                }
                            )
                            .frame(width: itemWidth)
                            .id(method.id.uuidString)
                        }
                        
                        // Add Button at the end (Now behaves like a dial item)
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .named("dial_scroll"))
                            let midX = frame.midX
                            let center = screenWidth / 2
                            let distance = abs(midX - center)
                            let proximity = max(0, 1.0 - (distance / (screenWidth / 2)))
                            
                            Button(action: {
                                HapticManager.shared.rigidImpact()
                                onAddRequest()
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(dynamicText)
                                    Text("New")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(dynamicText)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(0.15 + (proximity * 0.85))
                                .scaleEffect(0.8 + (proximity * 0.3)) // Subtly more "glow" growth
                                .shadow(color: dynamicText.opacity(proximity * 0.2), radius: 10)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: itemWidth)
                        .id("add_button")
                    }
                    .scrollTargetLayout()
                }
                .coordinateSpace(name: "dial_scroll")
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
                .onAppear {
                    // Start at selected method
                    scrollProxy.scrollTo(settings.selectedPaymentMethodId, anchor: .center)
                }
            }
        }
        .frame(height: 50)
    }
}

struct PaymentMethodDialItem: View {
    let method: PaymentMethod
    let dynamicText: Color
    let screenWidth: CGFloat
    let onCenter: () -> Void
    
    @ObservedObject var settings = SettingsManager.shared
    
    var isSelected: Bool {
        settings.selectedPaymentMethodId == method.id.uuidString
    }
    
    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("dial_scroll"))
            let midX = frame.midX
            let center = screenWidth / 2
            let distance = abs(midX - center)
            let proximity = max(0, 1.0 - (distance / (screenWidth / 2)))
            
            VStack(spacing: 4) { // Reduced spacing
                Image(systemName: isSelected ? (method.type == .cash ? "banknote.fill" : "creditcard.fill") : (method.type == .cash ? "banknote" : "creditcard"))
                    .font(.system(size: 20, weight: isSelected ? .bold : .regular)) // Reduced from 26
                    .foregroundColor(isSelected ? method.color : dynamicText)
                
                Text(method.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded)) // Reduced from 13
                    .foregroundColor(isSelected ? method.color : dynamicText)
                    .lineLimit(1)
            }
            .opacity(0.15 + (proximity * 0.85))
            .scaleEffect(0.8 + (proximity * 0.2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: midX) { _, _ in
                // If this item is closest to center (within a small margin)
                if distance < 10 {
                    onCenter()
                }
            }
        }
    }
}

// MARK: - Compact Badge (For History)

struct CompactPaymentBadge: View {
    let method: PaymentMethod?
    let dynamicText: Color
    
    var body: some View {
        if let method = method {
            HStack(spacing: 4) {
                Image(systemName: method.type == .cash ? "banknote" : "creditcard")
                    .font(.system(size: 9))
                Text(method.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(method.color.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(method.color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

