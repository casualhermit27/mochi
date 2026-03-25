import SwiftUI

struct PaymentMethodSelector: View {
    @ObservedObject var settings = SettingsManager.shared
    @Binding var isVisible: Bool
    @Binding var note: String // Binding to parent state
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    var onAddRequest: () -> Void 
    var onSave: (() -> Void)?
    
    private let itemWidth: CGFloat = 80 
    @State private var isNoteActive = false
    @FocusState private var isNoteFocused: Bool
    @Namespace private var animation
    
    @State private var localMethods: [PaymentMethod]

    init(isVisible: Binding<Bool>, note: Binding<String>, dynamicText: Color, dynamicBackground: Color, accentColor: Color, onAddRequest: @escaping () -> Void, onSave: (() -> Void)? = nil) {
        self._isVisible = isVisible
        self._note = note
        self.dynamicText = dynamicText
        self.dynamicBackground = dynamicBackground
        self.accentColor = accentColor
        self.onAddRequest = onAddRequest
        self.onSave = onSave
        
        let manager = SettingsManager.shared
        var methods = manager.paymentMethods
        if let idx = methods.firstIndex(where: { $0.id.uuidString == manager.selectedPaymentMethodId }) {
            let selected = methods.remove(at: idx)
            methods.insert(selected, at: 0)
        }
        self._localMethods = State(initialValue: methods)
    }
    
    var body: some View {
        GeometryReader { outerProxy in
            let screenWidth = outerProxy.size.width
            let noteWidth: CGFloat = isNoteActive ? 160 : itemWidth
            
            // Layout Logic:
            // 1. We want the ScrollView to span the full width so items can scroll "under" the Note button.
            // 2. We want the "Default" position of the first item (Cash) to be centered on screen.
            //    It implies: PaddingLeading = (ScreenCenter - ItemHalfWidth).
            //    Note Button (80) should be positioned at: PaddingLeading - NoteWidth.
            
            // Layout Logic:
            let centerOffset = (screenWidth / 2) - (itemWidth / 2)
            // Fix: Anchor the Note button using the CONSTANT itemWidth (80), not dynamic noteWidth.
            // This ensures it starts at the same visual position and grows rightwards.
            // NoteVisualOffset = ScreenCenter (200) - ItemHalf (40) - ItemWidth (80) = 80.
            let noteVisualOffset = max(0, centerOffset - itemWidth)
            
            // Push Logic:
            // When Note is active, it grows by (160 - 80) = 80.
            // We want to push the Scroll Area right by this amount.
            let activePush = isNoteActive ? (160 - 80) : 0
            
            ZStack(alignment: .leading) {
                
                // MARK: - Scrollable Payment Methods (Bottom Layer)
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            // Existing Payment Methods
                            ForEach(localMethods) { method in
                                PaymentMethodDialItem(
                                    method: method,
                                    dynamicText: dynamicText,
                                    screenWidth: screenWidth,
                                    onCenter: {
                                        // Only select if we are close to center
                                        if settings.selectedPaymentMethodId != method.id.uuidString {
                                            HapticManager.shared.selection()
                                            settings.selectPaymentMethod(method)
                                        }
                                    }
                                )
                                .frame(width: itemWidth)
                                .id(method.id.uuidString)
                                // Fade out logic can remain or be removed if ZStack hiding is sufficient.
                                // User asked for fading "one behind note".
                                // If it's literally behind, it's hidden.
                                // But maybe "proximity" opacity handles the rest.
                            }
                            
                            // Add Button at the end
                            GeometryReader { proxy in
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
                                    .opacity(0.3)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(width: itemWidth)
                            .id("add_button")
                        }
                        .scrollTargetLayout()
                    }
                    // Margin determines where the list starts.
                    // Default: CenterOffset (Aligns first item to center).
                    // Active: CenterOffset + Push.
                    .contentMargins(.leading, centerOffset + CGFloat(activePush), for: .scrollContent)
                    .contentMargins(.trailing, centerOffset, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled() 
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activePush)
                    .onAppear {
                        scrollProxy.scrollTo(settings.selectedPaymentMethodId, anchor: .center)
                    }
                    .onChange(of: settings.paymentMethods) { _, newMethods in
                        var methods = newMethods
                        if let idx = methods.firstIndex(where: { $0.id.uuidString == settings.selectedPaymentMethodId }) {
                            let selected = methods.remove(at: idx)
                            methods.insert(selected, at: 0)
                        }
                        localMethods = methods
                    }
                    .mask(
                        HStack(spacing: 0) {
                            Color.clear.frame(width: noteVisualOffset + noteWidth)
                            Color.white
                        }
                    )
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            if isNoteActive {
                                isNoteFocused = false
                            }
                        }
                    )
                }
                
                // MARK: - Fixed Note Button (Top Layer)
                ZStack {
                    if isNoteActive {
                        HStack(spacing: 8) {
                            // Pencil Icon (Tap to close)
                            Button(action: {
                                HapticManager.shared.softSquish()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isNoteActive = false }
                                isNoteFocused = false
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("Note", text: $note)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicText)
                                .tint(accentColor)
                                .focused($isNoteFocused)
                                .submitLabel(.done)
                                .onSubmit {
                                    isNoteFocused = false
                                }
                            
                            if !note.isEmpty {
                                Button(action: {
                                    note = ""
                                    // Don't close immediately, just clear
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(dynamicText.opacity(0.3))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(width: 160, height: 44)
                        .background {
                            ZStack {
                                dynamicBackground
                                dynamicText.opacity(0.06)
                            }
                            .clipShape(Capsule())
                            .matchedGeometryEffect(id: "noteBackground", in: animation)
                        }
                        .overlay(
                            Capsule().stroke(accentColor.opacity(0.3), lineWidth: 1)
                                .matchedGeometryEffect(id: "noteBorder", in: animation)
                        )
                    } else {
                        // Default Icon State
                        Button(action: {
                            HapticManager.shared.softSquish()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isNoteActive = true
                                isNoteFocused = true
                            }
                        }) {
                            ZStack {
                                if note.isEmpty {
                                    VStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(dynamicText)
                                        
                                        Text("Note")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText)
                                    }
                                } else {
                                    Text(note)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(dynamicText)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                        .padding(.horizontal, 6)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                dynamicBackground // Essential for masking
                                    .clipShape(Circle()) // Or Capsule, fitting the frame
                                    .matchedGeometryEffect(id: "noteBackground", in: animation)
                            }
                            .overlay(
                                Circle().stroke(Color.clear, lineWidth: 1) // Placeholder to match structure
                                    .matchedGeometryEffect(id: "noteBorder", in: animation)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: noteWidth)
                .offset(x: noteVisualOffset) // Place it relative to center
                .onChange(of: isNoteFocused) { _, focused in
                    if !focused {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isNoteActive = false
                        }
                    }
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
            let frame = proxy.frame(in: .global) 
            let midX = frame.midX
            let center = screenWidth / 2
            let distance = abs(midX - center)
            let proximity = max(0, 1.0 - (distance / (screenWidth / 2)))
            
            VStack(spacing: 4) { 
                Image(systemName: isSelected ? (method.type == .cash ? "banknote.fill" : "creditcard.fill") : (method.type == .cash ? "banknote" : "creditcard"))
                    .font(.system(size: 20, weight: isSelected ? .bold : .regular)) 
                    .foregroundColor(isSelected ? method.color : dynamicText)
                
                Text(LocalizedStringKey(method.name))
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? method.color : dynamicText)
                    .lineLimit(1)
            }
            .opacity(0.15 + (proximity * 0.85))
            .scaleEffect(0.8 + (proximity * 0.2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: midX) { _, _ in
                // If this item is closest to center
                // With margin offsetting, Global Frame Center logic still holds because the "Screen Center" is static.
                if distance < 30 { // Slightly wider activation zone
                    onCenter()
                }
            }
        }
    }
}

// MARK: - Compact Badge (For History)

struct CompactPaymentBadge: View {
    let method: PaymentMethod
    let dynamicText: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: method.type == .cash ? "banknote" : "creditcard")
                .font(.system(size: 9, weight: .bold))
            Text(LocalizedStringKey(method.name))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(method.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(method.color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(method.color.opacity(0.3), lineWidth: 1)
        )
    }
}

