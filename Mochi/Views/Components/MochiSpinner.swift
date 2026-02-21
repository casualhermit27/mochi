import SwiftUI

struct MochiSpinner: View {
    var size: CGFloat = 24
    @State private var isRotating = false
    
    var body: some View {
        Image("MochiCharacter")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .rotationEffect(Angle.degrees(isRotating ? 360 : 0))
            .opacity(0.8)
            .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
    }
}
