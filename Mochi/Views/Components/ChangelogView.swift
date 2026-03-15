import SwiftUI
import Combine

struct ChangelogView: View {
    @ObservedObject var manager = ChangelogManager.shared
    
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(accentColor)
                    .padding(.top, 40)
                
                Text("What's New")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(dynamicText)
            }
            
            // Feature List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    ForEach(manager.currentChangelog) { item in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: item.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(accentColor)
                                .frame(width: 32)
                                .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(dynamicText)
                                
                                Text(item.description)
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(dynamicText.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            
            Spacer()
            
            // Continue Button
            Button(action: {
                HapticManager.shared.success()
                manager.markAsSeen()
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white) // Hardcoded for contrast
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(dynamicBackground.ignoresSafeArea())
    }
}
