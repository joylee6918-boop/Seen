import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var messageStore: MessageStore

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(Color.gSurface)
        appearance.shadowColor = UIColor(red: 0xE8/255, green: 0xE0/255, blue: 0xDC/255, alpha: 1)
        let item = UITabBarItemAppearance()
        item.normal.iconColor = UIColor(red: 0x7F/255, green: 0x77/255, blue: 0x7C/255, alpha: 1)
        item.normal.titleTextAttributes = [.foregroundColor: UIColor(red: 0x7F/255, green: 0x77/255, blue: 0x7C/255, alpha: 1)]
        item.selected.iconColor = UIColor(red: 0xC9/255, green: 0x6F/255, blue: 0x83/255, alpha: 1)
        item.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0xC9/255, green: 0x6F/255, blue: 0x83/255, alpha: 1)]
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        appearance.selectionIndicatorTintColor = UIColor(red: 0xF7/255, green: 0xE6/255, blue: 0xEA/255, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.gTextSecondary)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("首页", systemImage: "house") }
                .tag(0)

            RecordView()
                .tabItem { Label("记录", systemImage: "plus.circle") }
                .tag(1)

            TrendView()
                .tabItem { Label("最近", systemImage: "chart.xyaxis.line") }
                .tag(2)

            AIView()
                .tabItem { Label("回信", systemImage: "sparkles") }
                .tag(3)

            MoreView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .tint(Color.dMood)
        .toolbarBackground(Color.gSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .center) {
            if let msg = messageStore.current {
                MessagePopup(msg: msg) {
                    messageStore.dismissCurrent()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .overlay(alignment: .bottom) {
            if let r = messageStore.reaction {
                ReactionBanner(text: r) { messageStore.dismissReaction() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: messageStore.current)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: messageStore.reaction)
    }
}

// MARK: - 留言弹窗
private struct MessagePopup: View {
    let msg: MessageData
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.gTextPrimary.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    DataIcon(type: .ai, size: 32)
                    Text("依安给你留了话").font(.gH3)
                    Spacer()
                }
                Text(msg.text)
                    .font(.gBody)
                    .foregroundColor(.gTextPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let ts = msg.createdAt {
                    Text(ts).font(.gCaption).foregroundColor(.gTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    onConfirm()
                } label: {
                    Text("看到了")
                        .font(.gH3).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.dMood).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(Color.gSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gHairline, lineWidth: 1))
            .shadow(color: Color.gTextPrimary.opacity(0.12), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Reaction 浮层 (打卡即时反应)
// 跟留言弹窗完全分开: 不挡操作, 不盖全屏, 底部一条卡片, 4 秒自动消失或点关闭.
private struct ReactionBanner: View {
    let text: String
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.dAi)
                .padding(.top, 1)
            Text(text)
                .font(.gCaption)
                .foregroundColor(.gTextBody)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Button(action: onTap) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gTextSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gSurface.opacity(0.96))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.gHairline, lineWidth: 1)
        )
        .shadow(color: Color.gTextPrimary.opacity(0.07), radius: 10, x: 0, y: 3)
    }
}
