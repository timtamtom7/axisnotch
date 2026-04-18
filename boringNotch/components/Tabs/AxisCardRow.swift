//
//  AxisCardRow.swift
//  boringNotch
//
//  Horizontal scrolling card row with snap-to-item and haptic feedback
//

import SwiftUI

struct AxisCardRow<Item: Identifiable, CardContent: View>: View {
    let items: [Item]
    let spacing: CGFloat
    @ViewBuilder let cardContent: (Item) -> CardContent

    @State private var haptics: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    cardContent(item)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.alignment, trigger: haptics)
    }
}
