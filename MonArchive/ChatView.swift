import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var socialStore: SocialStore
    @EnvironmentObject private var collectionStore: CollectionStore

    private let context: ChatContext

    @State private var conversationID: UUID?
    @State private var messageText = ""
    @State private var attachedItemID: UUID?
    @State private var showingAttachmentPicker = false

    @FocusState private var messageFieldFocused: Bool

    init(friend: SocialUser) {
        context = .friend(friend)
    }

    init(sharedCollection: SharedCollection) {
        context = .sharedCollection(sharedCollection)
    }

    private var conversation: ChatConversation? {
        guard let conversationID else {
            return nil
        }

        return socialStore.conversations.first {
            $0.id == conversationID
        }
    }

    private var conversationMessages: [ChatMessage] {
        guard let conversation else {
            return []
        }

        return socialStore.messages(for: conversation)
    }

    private var title: String {
        switch context {
        case .friend(let user):
            return user.name.uppercased()

        case .sharedCollection(let collection):
            return collection.name.uppercased()
        }
    }

    private var subtitle: String {
        switch context {
        case .friend:
            return "FRIEND · ACTIVE NOW"

        case .sharedCollection(let collection):
            return
                "\(collection.memberIDs.count) MEMBERS · SHARED COLLECTION"
        }
    }

    private var attachedItem: CollectibleItem? {
        guard let attachedItemID else {
            return nil
        }

        return collectionStore.items.first {
            $0.id == attachedItemID
        }
    }

    var body: some View {
        ZStack {
            ArchiveTheme.ivory
                .ignoresSafeArea()

            messageList
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            ArchiveTheme.ivory,
            for: .navigationBar
        )
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(title)
                        .font(ArchiveTheme.heading(15))
                        .foregroundStyle(ArchiveTheme.ink)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(ArchiveTheme.label(8))
                        .foregroundStyle(
                            ArchiveTheme.catalogGray
                        )
                        .tracking(0.5)
                        .lineLimit(1)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Conversation details will connect here.
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ArchiveTheme.ink)
                }
                .accessibilityLabel("Conversation information")
            }
        }
        .sheet(isPresented: $showingAttachmentPicker) {
            ChatAttachmentPicker(
                selectedItemID: $attachedItemID
            )
            .environmentObject(collectionStore)
        }
        .onAppear {
            prepareConversation()
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    conversationBeginning

                    ForEach(conversationMessages) { message in
                        ChatMessageBubble(
                            message: message,
                            isCurrentUser:
                                message.senderID ==
                                socialStore.currentUserID,
                            senderName:
                                senderName(for: message),
                            attachedItem:
                                item(for: message.attachedItemID)
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToLastMessage(using: proxy)
            }
            .onChange(of: conversationMessages.count) {
                _, _ in

                scrollToLastMessage(using: proxy)
            }
        }
    }

    private var conversationBeginning: some View {
        VStack(spacing: 8) {
            Image(systemName: conversationIcon)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(
                    ArchiveTheme.collectedRed
                )
                .frame(width: 58, height: 58)
                .background(Color.white.opacity(0.74))
                .clipShape(Circle())

            Text(beginningTitle)
                .font(ArchiveTheme.heading(15))
                .foregroundStyle(ArchiveTheme.ink)

            Text(beginningMessage)
                .font(ArchiveTheme.body(12))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var conversationIcon: String {
        switch context {
        case .friend:
            return "message"

        case .sharedCollection:
            return "person.3"
        }
    }

    private var beginningTitle: String {
        switch context {
        case .friend(let user):
            return "YOU AND \(user.name.uppercased())"

        case .sharedCollection:
            return "SHARED COLLECTION CHAT"
        }
    }

    private var beginningMessage: String {
        switch context {
        case .friend:
            return
                "Share discoveries, collection notes, and objects."

        case .sharedCollection:
            return
                "Messages here are visible to every member."
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 8) {
            if let attachedItem {
                attachedItemPreview(attachedItem)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    showingAttachmentPicker = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(ArchiveTheme.ink)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.76))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach a collectible")

                TextField(
                    "Write a message...",
                    text: $messageText,
                    axis: .vertical
                )
                .font(ArchiveTheme.body(14))
                .foregroundStyle(ArchiveTheme.ink)
                .lineLimit(1...4)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.82))
                .clipShape(
                    RoundedRectangle(cornerRadius: 21)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 21)
                        .stroke(
                            ArchiveTheme.catalogGray.opacity(0.12),
                            lineWidth: 1
                        )
                }
                .focused($messageFieldFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(sendButtonColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(canSend == false)
                .accessibilityLabel("Send message")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            ArchiveTheme.ivory.opacity(0.97)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    ArchiveTheme.catalogGray.opacity(0.12)
                )
                .frame(height: 1)
        }
    }

    private func attachedItemPreview(
        _ item: CollectibleItem
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: item.colorA),
                        Color(hex: item.colorB)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: item.category.systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(ArchiveTheme.heading(12))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineLimit(1)

                Text("ATTACHED OBJECT")
                    .font(ArchiveTheme.label(8))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
                    .tracking(0.6)
            }

            Spacer()

            Button {
                attachedItemID = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        }
        .padding(10)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var canSend: Bool {
        messageText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty == false ||
        attachedItemID != nil
    }

    private var sendButtonColor: Color {
        canSend
            ? ArchiveTheme.collectedRed
            : ArchiveTheme.catalogGray.opacity(0.35)
    }

    // MARK: - Actions

    private func prepareConversation() {
        guard conversationID == nil else {
            return
        }

        switch context {
        case .friend(let user):
            conversationID = socialStore
                .directConversation(with: user)
                .id

        case .sharedCollection(let collection):
            conversationID = socialStore
                .conversation(for: collection)
                .id
        }
    }

    private func sendMessage() {
        guard let conversationID else {
            return
        }

        socialStore.sendMessage(
            text: messageText,
            conversationID: conversationID,
            attachedItemID: attachedItemID
        )

        messageText = ""
        attachedItemID = nil
        messageFieldFocused = true
    }

    private func senderName(
        for message: ChatMessage
    ) -> String {
        if message.senderID == socialStore.currentUserID {
            return "YOU"
        }

        return socialStore
            .user(withID: message.senderID)?
            .name
            .uppercased()
            ?? "COLLECTOR"
    }

    private func item(
        for itemID: UUID?
    ) -> CollectibleItem? {
        guard let itemID else {
            return nil
        }

        return collectionStore.items.first {
            $0.id == itemID
        }
    }

    private func scrollToLastMessage(
        using proxy: ScrollViewProxy
    ) {
        guard let lastMessage = conversationMessages.last else {
            return
        }

        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(
                    lastMessage.id,
                    anchor: .bottom
                )
            }
        }
    }
}

// MARK: - Chat Context

private enum ChatContext {
    case friend(SocialUser)
    case sharedCollection(SharedCollection)
}

// MARK: - Message Bubble

private struct ChatMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let senderName: String
    let attachedItem: CollectibleItem?

    var body: some View {
        VStack(
            alignment:
                isCurrentUser ? .trailing : .leading,
            spacing: 4
        ) {
            Text(
                "\(senderName) · \(formattedTime)"
            )
            .font(ArchiveTheme.label(8))
            .foregroundStyle(
                ArchiveTheme.catalogGray
            )
            .tracking(0.3)

            VStack(alignment: .leading, spacing: 9) {
                if message.body.isEmpty == false {
                    Text(message.body)
                        .font(ArchiveTheme.body(14))
                        .foregroundStyle(
                            ArchiveTheme.ink
                        )
                        .lineSpacing(2)
                }

                if let attachedItem {
                    ChatAttachedItemCard(
                        item: attachedItem
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(bubbleColor)
            .clipShape(
                RoundedRectangle(cornerRadius: 17)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(
                        bubbleBorderColor,
                        lineWidth: 1
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment:
                isCurrentUser ? .trailing : .leading
        )
        .padding(
            isCurrentUser ? .leading : .trailing,
            55
        )
    }

    private var formattedTime: String {
        message.sentAt.formatted(
            date: .omitted,
            time: .shortened
        )
    }

    private var bubbleColor: Color {
        isCurrentUser
            ? ArchiveTheme.collectedRed.opacity(0.10)
            : Color.white.opacity(0.78)
    }

    private var bubbleBorderColor: Color {
        isCurrentUser
            ? ArchiveTheme.collectedRed.opacity(0.22)
            : ArchiveTheme.catalogGray.opacity(0.10)
    }
}

// MARK: - Attached Item Card

private struct ChatAttachedItemCard: View {
    let item: CollectibleItem

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: item.colorA),
                        Color(hex: item.colorB)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: item.category.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 46, height: 55)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(ArchiveTheme.heading(12))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineLimit(2)

                Text(item.creator.uppercased())
                    .font(ArchiveTheme.label(8))
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
                    .lineLimit(1)
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Attachment Picker

private struct ChatAttachmentPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var collectionStore: CollectionStore

    @Binding var selectedItemID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(collectionStore.items) { item in
                            Button {
                                selectedItemID = item.id
                                dismiss()
                            } label: {
                                attachmentRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("ATTACH OBJECT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") {
                        dismiss()
                    }
                    .foregroundStyle(
                        ArchiveTheme.catalogGray
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func attachmentRow(
        _ item: CollectibleItem
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: item.colorA),
                        Color(hex: item.colorB)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: item.category.systemImage)
                    .foregroundStyle(Color.white)
            }
            .frame(width: 48, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(ArchiveTheme.heading(14))
                    .foregroundStyle(ArchiveTheme.ink)

                Text(
                    item.year.map { "\(item.creator) · \(String($0))" } ?? item.creator
                )
                .font(ArchiveTheme.body(11))
                .foregroundStyle(
                    ArchiveTheme.catalogGray
                )
            }

            Spacer()

            Image(systemName: "plus.circle")
                .foregroundStyle(
                    ArchiveTheme.collectedRed
                )
        }
        .padding(12)
        .background(Color.white.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    let socialStore = SocialStore()
    let collectionStore = CollectionStore()

    NavigationStack {
        ChatView(
            friend: socialStore.friends[0]
        )
        .environmentObject(socialStore)
        .environmentObject(collectionStore)
    }
}
