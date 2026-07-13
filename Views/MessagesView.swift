import SwiftUI

// 回信 — AIname 给 Username 的全部回复历史
struct MessagesView: View {
    @EnvironmentObject var messageStore: MessageStore
    @State private var loading = false

    var body: some View {
        ZStack {
            SeenBackground()
            if messageStore.history.isEmpty && !loading {
                EmptyState()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messageStore.history) { msg in
                            MessageRow(msg: msg)
                        }
                        if loading {
                            ProgressView().padding(.vertical, 20)
                        }
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .refreshable {
                    await messageStore.syncFromServer()
                }
            }
        }
        .navigationTitle("回信")
        .navigationBarTitleDisplayMode(.large)
        .task {
            loading = true
            await messageStore.syncFromServer()
            loading = false
        }
    }
}

private struct MessageRow: View {
    let msg: MessageData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DataIcon(type: .ai, size: 28)
                Text("AIname").font(.gH3)
                Spacer()
                if msg.readAt == nil {
                    StatusPill(text: "未读", kind: .ai)
                } else {
                    StatusPill(text: "已读", kind: .success)
                }
            }
            Text(msg.text)
                .font(.gBody)
                .foregroundColor(.gTextPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if let ts = msg.createdAt {
                    Text(formatTime(ts)).font(.gCaption).foregroundColor(.gTextSecondary)
                }
                Spacer()
                if let r = msg.readAt {
                    Text("看了 · \(formatTime(r))").font(.gCaption).foregroundColor(.gTextSecondary)
                }
            }
        }
        .padding(16)
        .gleanCard()
    }

    private func formatTime(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) ?? plain.date(from: iso) else { return iso }
        return date.formatted(.dateTime.month().day().hour().minute())
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48)).foregroundColor(.dAi)
            Text("还没有留下什么").font(.gH3)
            Text("等你打卡后，我会把想说的话放在这里").font(.gCaption).foregroundColor(.gTextSecondary)
        }
    }
}
