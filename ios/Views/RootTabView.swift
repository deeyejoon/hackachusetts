//  RootTabView.swift
//  Bottom tab bar: Chat, Insights, Connect, Community.

import SwiftUI

struct RootTabView: View {
    init() {
        // Tint the active tab moss green and give the bar a warm surface.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.sageBackground)
        appearance.shadowColor = UIColor(Color.sageBorder)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.text.bubble.right")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }

            ConnectView()
                .tabItem {
                    Label("Connect", systemImage: "heart.text.square")
                }

            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.2")
                }
        }
        .tint(.sageMoss)
    }
}

#Preview {
    RootTabView()
}
