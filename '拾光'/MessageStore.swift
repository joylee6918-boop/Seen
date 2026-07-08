import Foundation
import SwiftUI
import Combine

// 全局消息队列 — 收 Claude 的留言, 弹窗显示给她看.
// 同时维护历史留言列表, 留言盒页面展示. 本地用 JSON 文件持久化, 启动增量同步.
@MainActor
class MessageStore: ObservableObject {
    @Published var queue: [MessageData] = []      // 待弹的未读队列
    @Published var current: MessageData? = nil    // 当前弹窗显示的
    @Published var history: [MessageData] = []    // 全部历史留言 (留言盒展示)
    @Published var archivedMessageIDs: Set<Int> = []  // 本地归档, 不影响服务端留言

    // reaction — 每次打卡服务端返回的即时反应. 跟留言完全分开:
    // 不入队列, 不持久化, 跟随打卡动作浮 4 秒自动消失. 同步成功才点亮.
    @Published var reaction: String? = nil
    @Published var lastSyncAt: Date? = nil        // 最近一次成功把数据推上去的时间
    @Published var todaySummary: String? = nil    // 本地生成的今日摘要, 首页/AI 页共用
    private var reactionTask: Task<Void, Never>? = nil

    var hasUnread: Bool { current != nil || !queue.isEmpty }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("purr_messages.json")
    }()

    private let archiveURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("purr_archived_messages.json")
    }()

    init() {
        loadFromDisk()
        loadArchiveFromDisk()
    }

    // MARK: - 持久化
    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let msgs = try? JSONDecoder().decode([MessageData].self, from: data) else { return }
        history = msgs.sorted { $0.id > $1.id }  // 最新在前
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL)
    }

    private func loadArchiveFromDisk() {
        guard let data = try? Data(contentsOf: archiveURL),
              let ids = try? JSONDecoder().decode(Set<Int>.self, from: data) else { return }
        archivedMessageIDs = ids
    }

    private func saveArchiveToDisk() {
        guard let data = try? JSONEncoder().encode(archivedMessageIDs) else { return }
        try? FileManager.default.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: archiveURL)
    }

    func isArchived(_ msg: MessageData) -> Bool {
        archivedMessageIDs.contains(msg.id)
    }

    func archive(_ msg: MessageData) {
        archivedMessageIDs.insert(msg.id)
        saveArchiveToDisk()
    }

    func unarchive(_ msg: MessageData) {
        archivedMessageIDs.remove(msg.id)
        saveArchiveToDisk()
    }

    // MARK: - 增量同步 (启动/进页面时调)
    func syncFromServer() async {
        let latestId = history.first?.id ?? 0
        do {
            let newMsgs: [MessageData]
            if latestId > 0 {
                newMsgs = try await CloudSync.shared.fetchMessagesAfter(id: latestId)
            } else {
                // 首次: 拉全部历史
                newMsgs = try await CloudSync.shared.fetchAllMessages(limit: 50)
            }
            if !newMsgs.isEmpty {
                // 合并去重, 按 id 降序
                var existing = Set(history.map { $0.id })
                for m in newMsgs where !existing.contains(m.id) {
                    history.insert(m, at: 0)
                    existing.insert(m.id)
                }
                // 更新已存在的 (readAt 可能变了)
                for m in newMsgs {
                    if let idx = history.firstIndex(where: { $0.id == m.id }) {
                        history[idx] = m
                    }
                }
                history.sort { $0.id > $1.id }
                saveToDisk()
            }
        } catch {
            print("[MessageStore] sync fail: \(error)")
        }
    }

    // MARK: - 弹窗队列
    /// 塞一条进来 (打卡响应附带的 message)
    func enqueue(_ msg: MessageData) {
        guard current?.id != msg.id, !queue.contains(where: { $0.id == msg.id }) else {
            addToHistory(msg)
            return
        }
        queue.append(msg)
        addToHistory(msg)
        showNext()
    }

    /// 塞多条 (启动拉取的未读)
    func enqueue(_ msgs: [MessageData]) {
        for m in msgs {
            addToHistory(m)
            guard current?.id != m.id, !queue.contains(where: { $0.id == m.id }) else { continue }
            queue.append(m)
        }
        showNext()
    }

    /// 她点"看到了" — 标已读 + 弹下一条
    func dismissCurrent() {
        if let c = current {
            Task { try? await CloudSync.shared.markMessagesRead(ids: [c.id]) }
            // 更新本地 history 的 readAt
            if let idx = history.firstIndex(where: { $0.id == c.id }) {
                let updated = MessageData(id: c.id, text: c.text, createdAt: c.createdAt,
                                          readAt: ISO8601DateFormatter().string(from: Date()))
                history[idx] = updated
                saveToDisk()
            }
        }
        current = nil
        showNext()
    }

    private func addToHistory(_ msg: MessageData) {
        if let idx = history.firstIndex(where: { $0.id == msg.id }) {
            history[idx] = msg
            saveToDisk()
        } else {
            history.insert(msg, at: 0)
            saveToDisk()
        }
    }

    private func showNext() {
        guard current == nil, !queue.isEmpty else { return }
        current = queue.removeFirst()
    }

    // MARK: - Reaction (即时反应, 跟随打卡)
    /// 打卡同步成功后调: 把 reaction 浮出来, message 入留言盒.
    func apply(_ result: SyncResult) {
        lastSyncAt = Date()
        if let r = result.reaction, !r.isEmpty {
            showReaction(r)
        }
        if let m = result.message {
            enqueue(m)
        }
    }

    func showReaction(_ text: String) {
        reaction = text
        reactionTask?.cancel()
        reactionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run { self?.reaction = nil }
        }
    }

    func dismissReaction() {
        reactionTask?.cancel()
        reaction = nil
    }
}
