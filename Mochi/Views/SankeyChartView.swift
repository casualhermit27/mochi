import SwiftUI

struct SankeyLinkShape: Shape {
    var startY: CGFloat
    var startHeight: CGFloat
    var endY: CGFloat
    var endHeight: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            AnimatablePair(startY, AnimatablePair(startHeight, AnimatablePair(endY, endHeight)))
        }
        set {
            startY = newValue.first
            startHeight = newValue.second.first
            endY = newValue.second.second.first
            endHeight = newValue.second.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        
        let p1 = CGPoint(x: 0, y: startY)
        let p2 = CGPoint(x: width, y: endY)
        let p3 = CGPoint(x: width, y: endY + endHeight)
        let p4 = CGPoint(x: 0, y: startY + startHeight)
        
        // A smooth cubic bezier offset is typically half the width
        let cpOffset: CGFloat = width * 0.5
        
        path.move(to: p1)
        path.addCurve(to: p2, control1: CGPoint(x: p1.x + cpOffset, y: p1.y), control2: CGPoint(x: p2.x - cpOffset, y: p2.y))
        path.addLine(to: p3)
        path.addCurve(to: p4, control1: CGPoint(x: p3.x - cpOffset, y: p3.y), control2: CGPoint(x: p4.x + cpOffset, y: p4.y))
        path.closeSubpath()
        return path
    }
}

struct SankeyChartView: View {
    let data: [(category: String, amount: Double)]
    let totalSpent: Double
    let dynamicText: Color
    let currencySymbol: String
    let colors: [Color]

    struct HoverData: Equatable {
        let category: String
        let amount: Double
    }
    
    @State private var hoveredItem: HoverData? = nil
    @State private var hoverLocation: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let safeData = data.isEmpty ? [("NO DATA", 1.0)] : data
            let safeTotal = totalSpent == 0 ? 1.0 : totalSpent
            
            let totalHeight = geo.size.height
            let spacing: CGFloat = 8 // Small spacing for minimalist look
            let totalSpacing = spacing * CGFloat(max(0, safeData.count - 1))
            let availableHeight = max(0, totalHeight - totalSpacing)
            
            // MATH FOR MINIMUM HEIGHTS:
            // Ensure even tiny $2 purchases are visually rendered on screen
            let desiredMinHeight: CGFloat = 8.0
            let actualMinHeight = min(desiredMinHeight, availableHeight / CGFloat(safeData.count))
            let totalMinHeights = actualMinHeight * CGFloat(safeData.count)
            let distributableHeight = max(0, availableHeight - totalMinHeights)
            
            let baseLeftColor = dynamicText.opacity(0.8)
            
            ZStack(alignment: .topLeading) {
                // Left solid continuous bar
                Capsule(style: .continuous)
                    .fill(baseLeftColor)
                    .frame(width: 8, height: availableHeight)
                    .offset(x: 0, y: totalSpacing / 2) 
                
                // Draw Links and Right Bars
                ForEach(Array(safeData.enumerated()), id: \.element.category) { index, item in
                    
                    // Proportion of the dynamically distributable height
                    let dynamicHeight = CGFloat(item.amount / safeTotal) * distributableHeight
                    let nodeHeight = dynamicHeight + actualMinHeight
                    
                    // Accumulate heights of all previous nodes to find start Y
                    let previousNodesHeight = safeData.prefix(index).reduce(0) { sum, prevItem in
                        sum + (CGFloat(prevItem.amount / safeTotal) * distributableHeight) + actualMinHeight
                    }
                    
                    let startYForThis = previousNodesHeight + (totalSpacing / 2)
                    let endYForThis = previousNodesHeight + CGFloat(index) * spacing
                    
                    let itemColor = colors[index % colors.count]
                    
                    // The Flow
                    SankeyLinkShape(startY: startYForThis, startHeight: nodeHeight, endY: endYForThis, endHeight: nodeHeight)
                        .fill(
                            LinearGradient(
                                colors: [baseLeftColor.opacity(0.15), itemColor.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 10) 
                    
                    // The Right Bar
                    Capsule(style: .continuous)
                        .fill(itemColor)
                        .frame(width: 8, height: nodeHeight)
                        .offset(x: geo.size.width - 8, y: endYForThis)
                        
                    // Percentage label instead of emojis
                    let percentage = (item.amount / safeTotal) * 100
                    if percentage >= 1.0 && nodeHeight >= 12 {
                        Text("\(String(format: "%.0f", percentage))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText.opacity(0.5))
                            .offset(x: geo.size.width - 34, y: endYForThis + (nodeHeight / 2) - 6)
                    }
                }
                
                // Tooltip Overlay for Hovering
                if let hovered = hoveredItem {
                    VStack(spacing: 2) {
                        Text(hovered.category)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                        
                        Text("\(currencySymbol)\(String(format: "%.2f", hovered.amount))")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.8))
                    }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(dynamicText.opacity(0.05))
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(dynamicText.opacity(0.1), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.1), radius: 5, y: 3)
                        // Dynamic positioning near finger
                        .position(x: hoverLocation.x, y: hoverLocation.y - 32)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: hoverLocation)
                }
            }
            .contentShape(Rectangle())
            // The Hover / Touch interaction
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        hoverLocation = value.location
                        let isRightSide = value.location.x > geo.size.width / 2
                        
                        var foundData: HoverData? = nil
                        
                        for (index, item) in safeData.enumerated() {
                            let dynamicHeight = CGFloat(item.amount / safeTotal) * distributableHeight
                            let nodeHeight = dynamicHeight + actualMinHeight
                            
                            let startY = safeData.prefix(index).reduce(0) { sum, prevItem in
                                sum + (CGFloat(prevItem.amount / safeTotal) * distributableHeight) + actualMinHeight
                            } + (totalSpacing / 2)
                            let endY = startY - (totalSpacing / 2) + CGFloat(index) * spacing
                            
                            let boundsY = isRightSide ? endY : startY
                            
                            // Wide hit testing logic (approximate Y bounds of flow)
                            if value.location.y >= boundsY - 6 && value.location.y <= boundsY + nodeHeight + 6 {
                                // Clean up the name by removing emojis specifically
                                let cleanedString = item.category.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                                // If the cleaned string is empty from aggressive filtering, fallback
                                let catName = cleanedString.isEmpty ? item.category : cleanedString
                                foundData = HoverData(category: catName, amount: item.amount)
                                break
                            }
                        }
                        hoveredItem = foundData
                    }
                    .onEnded { _ in
                        hoveredItem = nil
                    }
            )
        }
    }
}
