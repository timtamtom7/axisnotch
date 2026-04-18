//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI
import Defaults

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                    withAnimation(.smooth) {
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 26)
                .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                .background {
                    if tab.view == coordinator.currentView {
                        Capsule()
                            .fill(Color(nsColor: .secondarySystemFill))
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    } else {
                        Capsule()
                            .fill(Color.clear)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                            .hidden()
                    }
                }
            }
        }
        .clipShape(Capsule())
    }

    private var visibleTabs: [TabModel] {
        var result = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        result.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        if Defaults[.showTasksTab] {
            result.append(TabModel(label: "Tasks", icon: "checklist", view: .tasks))
        }
        if Defaults[.showToolsTab] {
            result.append(TabModel(label: "Tools", icon: "wrench.and.screwdriver", view: .tools))
        }
        return result
    }
}

#Preview {
    TabSelectionView()
        .frame(width: 300, height: 30)
        .background(Color.black)
}
