import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var store: CollectionStore
    let onProfileTapped: () -> Void
    @State private var showPlan = false
    @State private var showingNewCollection = false
    @State private var showingDeletedCollections = false
    @State private var collectionPendingDeletion: PersonalCollection?
    @State private var confirmingSampleRemoval = false
    @State private var decidingSamples = false
    @State private var sampleError: String?

    init(onProfileTapped: @escaping () -> Void = {}) {
        self.onProfileTapped = onProfileTapped
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        archiveSummary
                        if store.defaultCleanupOffered { sampleCleanupOffer }
                        if !store.sampleUndo.isEmpty { sampleUndoNotice }

                        Text("YOUR COLLECTIONS")
                            .font(ArchiveTheme.label(11))
                            .tracking(1.1)
                            .foregroundStyle(ArchiveTheme.catalogGray)

                        if !store.catalogReady { ProgressView("Loading collections…") }
                        if let error = store.catalogError {
                            Text(error).font(ArchiveTheme.body(12)).foregroundStyle(ArchiveTheme.collectedRed)
                            Button("Retry sync") { store.retryCloudSync() }
                        }
                        LazyVStack(spacing: 16) {
                            ForEach(store.activeCollections) { collection in
                                NavigationLink {
                                    ShelfDetailView(category: collection.layout, collectionID: collection.id)
                                } label: {
                                    CollectionCard(category: collection.layout,
                                        itemCount: store.items(in: collection.id).count,
                                        items: Array(store.items(in: collection.id).prefix(3)),
                                        collectionName: collection.name)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete Collection", role: .destructive) { collectionPendingDeletion = collection }
                                }
                            }
                            if !store.unfiledItems.isEmpty {
                                NavigationLink {
                                    ShelfDetailView(category: .poster, showsUnfiled: true)
                                } label: {
                                    Label("Unfiled · \(store.unfiledItems.count) objects", systemImage: "tray")
                                        .font(ArchiveTheme.heading(16))
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                                        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button("CREATE A COLLECTION") { showingNewCollection = true }
                            .buttonStyle(.borderedProminent)
                            .tint(ArchiveTheme.collectedRed)
                            .disabled(!store.catalogReady)
                        Button("Recently deleted collections (\(store.deletedCollections.count))") {
                            showingDeletedCollections = true
                        }
                        .font(ArchiveTheme.body(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CollectionCategory.self) { category in
                ShelfDetailView(category: category)
            }
        }
        .foregroundStyle(ArchiveTheme.ink)
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $showingNewCollection) { NewPersonalCollectionSheet() }
        .sheet(isPresented: $showingDeletedCollections) { DeletedCollectionsSheet() }
        .confirmationDialog("Delete this collection?", isPresented: Binding(
            get: { collectionPendingDeletion != nil }, set: { if !$0 { collectionPendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Delete Collection", role: .destructive) {
                if let collection = collectionPendingDeletion { store.deletePersonalCollection(collection.id) }
                collectionPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { collectionPendingDeletion = nil }
        } message: {
            Text("Your objects and photos will be kept in Unfiled. Restore this collection from Recently deleted to undo.")
        }
        .confirmationDialog("Remove sample objects?", isPresented: $confirmingSampleRemoval, titleVisibility: .visible) {
            Button("Remove examples", role: .destructive) { decideSamples(remove: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your uploads and collections stay. Only the sample objects are removed.")
        }
        .sheet(isPresented: $showPlan) {
            ArchivePlanView(objectCount: store.items.count)
                .environment(\.colorScheme, .light)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var sampleCleanupOffer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ArchiveTheme.collectedRed)
                    .frame(width: 34, height: 34)
                    .background(ArchiveTheme.collectedRed.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Make it yours").font(ArchiveTheme.heading(16))
                    Text("\(store.defaultExampleCount) sample objects · Your uploads stay")
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
            }
            HStack(spacing: 10) {
                Button { confirmingSampleRemoval = true } label: {
                    HStack(spacing: 6) {
                        Text("REMOVE EXAMPLES")
                        Image(systemName: "trash")
                    }
                    .font(ArchiveTheme.label(9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(ArchiveTheme.collectedRed, in: Capsule())
                }
                .buttonStyle(.plain)
                Button { decideSamples(remove: false) } label: {
                    Text("KEEP EXAMPLES")
                        .font(ArchiveTheme.label(9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundStyle(ArchiveTheme.ink)
                        .background(.white.opacity(0.8), in: Capsule())
                        .overlay { Capsule().stroke(ArchiveTheme.catalogGray.opacity(0.2), lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
            if let sampleError { Text(sampleError).font(.caption).foregroundStyle(.red) }
            if decidingSamples { ProgressView("Saving…").font(.caption) }
        }
        .foregroundStyle(ArchiveTheme.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ArchiveTheme.collectedRed.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(ArchiveTheme.collectedRed.opacity(0.16), lineWidth: 1) }
        .disabled(decidingSamples)
    }

    private var sampleUndoNotice: some View {
        HStack {
            Text("Default examples removed").font(.caption)
            Spacer()
            Button("Undo") { store.undoSampleRemoval() }
            Button { store.dismissSampleUndo() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Dismiss undo")
        }.padding(14)
    }

    private func decideSamples(remove: Bool) {
        decidingSamples = true; sampleError = nil
        Task { @MainActor in
            defer { decidingSamples = false }
            do { try await store.completeSampleChoice(remove: remove) }
            catch { sampleError = error.localizedDescription }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("COLLECTION")
                    .font(ArchiveTheme.display(27))
                    .foregroundStyle(ArchiveTheme.ink)
                Text("OBJECTS WORTH KEEPING")
                    .font(ArchiveTheme.label(10))
                    .tracking(1.25)
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }
            Spacer()
            NavigationLink {
                ArchiveSearchView()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ArchiveTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search archive")
            Button(action: onProfileTapped) {
                Circle()
                    .fill(ArchiveTheme.collectedRed)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
    }

    private var archiveSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.activeItems.count)")
                    .font(ArchiveTheme.display(44))
                    .foregroundStyle(ArchiveTheme.ink)
                Text("OBJECTS")
                    .font(ArchiveTheme.label(11))
                    .foregroundStyle(ArchiveTheme.ink)
                    .tracking(1)
                Spacer()
                Text("\(store.activeCollections.count) COLLECTIONS")
                    .font(ArchiveTheme.label(10))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(ArchiveTheme.paperTan.opacity(0.45))
                    Capsule()
                        .fill(ArchiveTheme.collectedRed)
                        .frame(
                            width: geometry.size.width
                                * min(CGFloat(store.items.count) / 50, 1)
                        )
                }
            }
            .frame(height: 3)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT MILESTONE")
                        .font(ArchiveTheme.label(9))
                        .tracking(0.8)
                        .foregroundStyle(ArchiveTheme.catalogGray)
                    Text(milestoneText)
                        .font(ArchiveTheme.heading(13))
                        .foregroundStyle(ArchiveTheme.ink)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text("PERSONAL PLAN")
                        .font(ArchiveTheme.label(8))
                        .tracking(0.7)
                        .foregroundStyle(ArchiveTheme.catalogGray)

                    Button {
                        showPlan = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("UPGRADE")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(ArchiveTheme.label(9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .foregroundStyle(.white)
                        .background(ArchiveTheme.collectedRed, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Every object holds a story worth keeping.")
                .font(ArchiveTheme.body(13))
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
        .padding(18)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
    }

    private var milestoneText: String {
        let remaining = max(50 - store.items.count, 0)
        return remaining == 0
            ? "CURATOR I UNLOCKED"
            : "\(remaining) OBJECTS TO CURATOR I"
    }
}

private struct ArchivePlanView: View {
    @Environment(\.dismiss) private var dismiss
    let objectCount: Int
    @State private var showComingSoon = false

    private let goal = 50

    var body: some View {
        ZStack {
            ArchiveTheme.ivory.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ARCHIVE PLAN")
                                .font(ArchiveTheme.display(28))
                            Text("PERSONAL COLLECTION")
                                .font(ArchiveTheme.label(10))
                                .tracking(1)
                                .foregroundStyle(ArchiveTheme.catalogGray)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ArchiveTheme.ink)
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.8), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("CURATOR I")
                                .font(ArchiveTheme.heading(18))
                            Spacer()
                            Text("\(objectCount) / \(goal)")
                                .font(ArchiveTheme.label(11))
                                .foregroundStyle(ArchiveTheme.catalogGray)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(ArchiveTheme.paperTan.opacity(0.45))
                                Capsule()
                                    .fill(ArchiveTheme.collectedRed)
                                    .frame(
                                        width: geometry.size.width
                                            * min(CGFloat(objectCount) / CGFloat(goal), 1)
                                    )
                            }
                        }
                        .frame(height: 5)

                        Text(goalMessage)
                            .font(ArchiveTheme.body(13))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                    }
                    .padding(18)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 14) {
                        planFeature("Unlimited collection spaces", icon: "rectangle.stack")
                        planFeature("Custom shelf themes", icon: "paintpalette")
                        planFeature("Cloud backup and sync", icon: "icloud")
                    }

                    Button("UPGRADE PLAN") {
                        showComingSoon = true
                    }
                    .font(ArchiveTheme.label(11))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(ArchiveTheme.collectedRed, in: Capsule())
                    .buttonStyle(.plain)
                }
                .padding(22)
            }
        }
        .foregroundStyle(ArchiveTheme.ink)
        .environment(\.colorScheme, .light)
        .alert("Upgrade Coming Soon", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Plan upgrades are shown as a prototype in this version.")
        }
    }

    private var goalMessage: String {
        let remaining = max(goal - objectCount, 0)
        return remaining == 0
            ? "You unlocked the Curator I achievement."
            : "Add \(remaining) more objects to unlock Curator I."
    }

    private func planFeature(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ArchiveTheme.collectedRed)
                .frame(width: 24)
            Text(title)
                .font(ArchiveTheme.body(14))
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
    }
}


struct NewPersonalCollectionSheet: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var layout: CollectionCategory = .poster
    @State private var errorMessage: String?
    var onCreated: (PersonalCollection) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            Form {
                Section("Collection name") { TextField("e.g. Travel treasures", text: $name) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("New Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        do {
                            let collection = try store.createPersonalCollection(name: name, layout: layout)
                            onCreated(collection); dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.catalogReady)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .tint(ArchiveTheme.collectedRed)
    }
}

struct DeletedCollectionsSheet: View {
    @EnvironmentObject private var store: CollectionStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if store.deletedCollections.isEmpty {
                    Text("No deleted collections.")
                } else {
                    ForEach(store.deletedCollections) { collection in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(collection.name)
                                Text("Objects and photos have been kept.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") { store.restorePersonalCollection(collection.id) }
                        }
                    }
                }
            }
            .navigationTitle("Recently Deleted")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .environment(\.colorScheme, .light)
        .tint(ArchiveTheme.collectedRed)
    }
}

