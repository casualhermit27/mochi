import SwiftUI

struct AnimatedHeroView: View {
    let chunks: [HeroChunk]
    let textPrimary: Color
    let textSecondary: Color
    let startDelay: Double

    @State private var itemsRevealed: Int = -1
    @State private var visibleImages: [Int: Image] = [:]
    @State private var hiddenImages: [Int: Image] = [:]
    @State private var isReady: Bool = false
    
    var body: some View {
        Group {
            if isReady {
                composedText
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineSpacing(8)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            } else {
                Text("") // placeholder while rendering
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            prerenderItems()
            isReady = true
            triggerAnimationSequence()
        }
    }
    
    private var composedText: Text {
        var combined = Text("")
        
        for (index, chunk) in chunks.enumerated() {
            let isVisible = index <= itemsRevealed
            var textFragment = Text("")
            
            // Subtle transition properties
            let clearColor = Color.clear
            
            switch chunk {
            case .text(let string, let isHighlight):
                let color = isHighlight ? textPrimary : textSecondary
                textFragment = Text(LocalizedStringKey(string))
                    .foregroundColor(isVisible ? color : clearColor)
                
            case .icon(let name, let color):
                textFragment = Text(Image(systemName: name))
                    .foregroundColor(isVisible ? color : clearColor)
                
            case .image(_), .mascot(_), .button(_, _), .iconButton(_, _):
                if let img = isVisible ? visibleImages[index] : hiddenImages[index] {
                    // Tweak baseline dynamically based on the type of rendered asset to optically center it
                    let offset: CGFloat = {
                        if case .mascot = chunk { return -8 }
                        if case .button = chunk { return -4 }
                        if case .image = chunk { return -4 }
                        return 0
                    }()
                    textFragment = Text(img).baselineOffset(offset)
                }
                
            case .newline:
                textFragment = Text("\n")
            }
            
            combined = Text("\(combined)\(textFragment)")
        }
        
        return combined
    }
    
    private func triggerAnimationSequence() {
        itemsRevealed = -1
        let staggerTime = 0.05
        for index in chunks.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + (Double(index) * staggerTime)) {
                withAnimation(.easeOut(duration: 0.3)) {
                    itemsRevealed = index
                }
            }
        }
    }
    
    @MainActor
    private func prerenderItems() {
        for (index, chunk) in chunks.enumerated() {
            switch chunk {
            case .image(let name):
                visibleImages[index] = renderAsset(name: name, height: 26, isVisible: true, rounded: name == "MochiLogo")
                hiddenImages[index] = renderAsset(name: name, height: 26, isVisible: false, rounded: name == "MochiLogo")
            case .mascot(let name):
                visibleImages[index] = renderAsset(name: name, height: 38, isVisible: true)
                hiddenImages[index] = renderAsset(name: name, height: 38, isVisible: false)
            case .button(let title, let color):
                visibleImages[index] = renderPill(title: title, color: color, isVisible: true)
                hiddenImages[index] = renderPill(title: title, color: color, isVisible: false)
            case .iconButton(let name, let color):
                visibleImages[index] = renderIconButton(name: name, color: color, isVisible: true)
                hiddenImages[index] = renderIconButton(name: name, color: color, isVisible: false)
            default:
                break
            }
        }
    }
    
    @MainActor
    private func renderPill(title: String, color: Color, isVisible: Bool) -> Image? {
        let view = Text(LocalizedStringKey(title))
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
            .opacity(isVisible ? 1 : 0)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = UITraitCollection.current.displayScale
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }

    @MainActor
    private func renderIconButton(name: String, color: Color, isVisible: Bool) -> Image? {
        let view = Image(systemName: name)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(6)
            .background(color)
            .clipShape(Circle())
            .opacity(isVisible ? 1 : 0)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = UITraitCollection.current.displayScale
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }
    
    @MainActor
    private func renderAsset(name: String, height: CGFloat, isVisible: Bool, rounded: Bool = false) -> Image? {
        let view = Image(name)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: rounded ? height * 0.225 : 0, style: .continuous))
            .opacity(isVisible ? 1 : 0)
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = UITraitCollection.current.displayScale
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }
}

enum HeroChunk {
    case text(String, isHighlight: Bool)
    case icon(String, Color)
    case image(String)
    case mascot(String)
    case button(String, Color)
    case iconButton(String, Color)
    case newline
}
