import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {

    @EnvironmentObject private var store: CollectionStore
    @EnvironmentObject private var socialStore: SocialStore
    @ObservedObject private var profileStore = ProfileStore.shared

    @State private var showingEditProfile = false
    @State private var bioExpanded = false
    /// Bumped by the COLLECTIONS count to scroll down to My Collections.
    @State private var collectionsScrollRequest = 0

    private static let myCollectionsAnchor = "myCollections"
    @State private var updatingVisibility: CollectionCategory?
    @State private var visibilityError: String?

    private var activeCategoryCount: Int {
        CollectionCategory.allCases.filter { store.count(for: $0) > 0 }.count
    }

    private var categoriesWithObjects: [CollectionCategory] {
        CollectionCategory.allCases.filter { store.count(for: $0) > 0 }
    }

    private var publicCategories: [CollectionCategory] {
        categoriesWithObjects.filter { profileStore.visibility(for: $0) == .isPublic }
    }

    private var hasHandle: Bool { !profileStore.profile.handle.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory
                    .ignoresSafeArea()

                ScrollViewReader { scroller in
                ScrollView {
                    VStack(spacing: 0) {
                        topBar
                        profileHeader
                        CloudAccountPanel()
                        socialActionSection
                        myCollectionsSection
                            .id(Self.myCollectionsAnchor)
                        sharedCollectionsSection
                        PastCollectionSection()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    // Keeps the layout readable on iPad and large phones.
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .refreshable { await profileStore.reload() }
                .onChange(of: collectionsScrollRequest) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        scroller.scrollTo(Self.myCollectionsAnchor, anchor: .top)
                    }
                }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(profileStore: profileStore)
            }
            .task { await profileStore.loadIfNeeded() }
            .onAppear {
                socialStore.seedSharedCollectionItems(from: store.items)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("PROFILE")
                .font(ArchiveTheme.display(32))
                .foregroundStyle(ArchiveTheme.ink)

            Spacer()

            NavigationLink {
                ProfileSettingsView(profileStore: profileStore)
            } label: {
                circleIcon("line.3.horizontal")
            }
            .buttonStyle(.plain)
            .disabled(profileStore.loadState != .loaded)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    private func circleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(ArchiveTheme.ink)
            .frame(width: 46, height: 46)
            .background(Color.white.opacity(0.72))
            .clipShape(Circle())
            .overlay {
                Circle().stroke(ArchiveTheme.catalogGray.opacity(0.15), lineWidth: 1)
            }
    }

    // MARK: - Profile Card (loading / error / loaded)

    @ViewBuilder
    private var profileHeader: some View {
        switch profileStore.loadState {
        case .idle, .loading:
            profileCardShell {
                HStack(spacing: 15) {
                    RoundedRectangle(cornerRadius: 23)
                        .fill(ArchiveTheme.paperTan.opacity(0.35))
                        .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(ArchiveTheme.catalogGray.opacity(0.15)).frame(width: 140, height: 16)
                        Capsule().fill(ArchiveTheme.catalogGray.opacity(0.12)).frame(width: 100, height: 11)
                        Capsule().fill(ArchiveTheme.catalogGray.opacity(0.10)).frame(width: 180, height: 11)
                    }
                    Spacer(minLength: 0)
                    ProgressView()
                        .tint(ArchiveTheme.collectedRed)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading profile")
            }

        case .failed(let message):
            profileCardShell {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                    Text("COULDN'T LOAD YOUR PROFILE")
                        .font(ArchiveTheme.label(11))
                        .tracking(0.7)
                        .foregroundStyle(ArchiveTheme.ink)
                    Text(message)
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await profileStore.reload() }
                    } label: {
                        Text("TRY AGAIN")
                            .font(ArchiveTheme.label(11))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 22)
                            .frame(height: 40)
                            .background(ArchiveTheme.collectedRed, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }

        case .loaded:
            profileCard
        }
    }

    private func profileCardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .background(Color.white.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .overlay {
                RoundedRectangle(cornerRadius: 25)
                    .stroke(ArchiveTheme.catalogGray.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: ArchiveTheme.ink.opacity(0.06), radius: 14, y: 6)
    }

    private var profileCard: some View {
        let profile = profileStore.profile
        let subtitle = [profileStore.displayHandle, profile.location]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return profileCardShell {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 15) {
                    Button {
                        showingEditProfile = true
                    } label: {
                        ProfileAvatarView(
                            image: profileStore.avatar,
                            initials: profileStore.initials,
                            size: 76
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 24, height: 24)
                                .background(ArchiveTheme.cabinet, in: Circle())
                                .overlay { Circle().stroke(Color.white, lineWidth: 2) }
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change profile photo")

                    // Name, handle and bio sit together beside the photo.
                    VStack(alignment: .leading, spacing: 6) {
                    Button {
                        showingEditProfile = true
                    } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name.isEmpty ? "Add your name" : profile.name)
                            .font(ArchiveTheme.heading(21))
                            .foregroundStyle(profile.name.isEmpty ? ArchiveTheme.catalogGray : ArchiveTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(subtitle.isEmpty ? "Add a handle so friends can find you" : subtitle)
                            .font(ArchiveTheme.body(12))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                            .lineLimit(1)

                        if profile.bio.isEmpty {
                            Text("Add a short bio")
                                .font(ArchiveTheme.body(12))
                                .foregroundStyle(ArchiveTheme.catalogGray.opacity(0.7))
                                .padding(.top, 3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit profile")
                    .accessibilityValue(profile.name)

                    // Long bios show two lines with "more"; tap to read the rest.
                    if !profile.bio.isEmpty {
                        bioText(profile.bio)
                    }
                    }
                    .padding(.top, 2)
                }

                Rectangle()
                    .fill(ArchiveTheme.catalogGray.opacity(0.15))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    // Each count opens what it counts, like Instagram.
                    NavigationLink {
                        ArchiveSearchView()
                    } label: {
                        ProfileStat(value: store.activeItems.count, label: "OBJECTS")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(store.activeItems.count) objects")
                    .accessibilityHint("Opens all your objects")
                    statDivider
                    Button {
                        collectionsScrollRequest += 1
                    } label: {
                        ProfileStat(value: activeCategoryCount, label: "COLLECTIONS")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(activeCategoryCount) collections")
                    .accessibilityHint("Scrolls to My Collections")
                    statDivider
                    NavigationLink {
                        FriendsView()
                    } label: {
                        ProfileStat(value: socialStore.friends.count, label: "FRIENDS")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(socialStore.friends.count) friends")
                    .accessibilityHint("Opens your friends list")
                }
            }
        }
    }

    private func bioText(_ bio: String) -> some View {
        // Roughly when two lines aren't enough to show the whole bio.
        let isLong = bio.count > 50 || bio.contains("\n")
        return Button {
            guard isLong else { return }
            withAnimation(.easeInOut(duration: 0.2)) { bioExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(bio)
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.ink.opacity(0.82))
                    .lineLimit(bioExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if isLong {
                    Text(bioExpanded ? "less" : "more")
                        .font(ArchiveTheme.heading(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isLong)
        .accessibilityLabel(bio)
        .accessibilityHint(isLong ? (bioExpanded ? "Shows less of your bio" : "Shows your full bio") : "")
    }

    private var statDivider: some View {
        Rectangle()
            .fill(ArchiveTheme.catalogGray.opacity(0.15))
            .frame(width: 1, height: 34)
    }

    // MARK: - Edit Profile / Share Profile / Find Friends

    private var shareMessage: String {
        let name = profileStore.profile.name.isEmpty ? "my" : "\(profileStore.profile.name)'s"
        return "See \(name) collection on MONO."
    }

    private var socialActionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Laid out like Instagram: two text buttons, then a small
            // "discover people" icon button at the end.
            HStack(spacing: 8) {
                Button { showingEditProfile = true } label: {
                    actionLabel("EDIT PROFILE", systemImage: nil, primary: false)
                }
                .buttonStyle(.plain)

                if let url = profileStore.shareURL {
                    // The share sheet also has Copy, so no separate button.
                    ShareLink(
                        item: url,
                        subject: Text("My MONO profile"),
                        message: Text(shareMessage)
                    ) {
                        actionLabel("SHARE PROFILE", systemImage: nil, primary: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    // No handle yet, so there's no link to share.
                    Button { showingEditProfile = true } label: {
                        actionLabel("SHARE PROFILE", systemImage: nil, primary: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Add a handle first to share your profile")
                }

                NavigationLink {
                    FriendsView()
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ArchiveTheme.ink)
                        .frame(width: 44, height: 40)
                        .background(Color.white.opacity(0.76))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ArchiveTheme.catalogGray.opacity(0.15), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Find friends")
            }
            .disabled(profileStore.loadState != .loaded)

            if profileStore.loadState == .loaded && !hasHandle {
                Text("Add a handle to share your profile.")
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .padding(.horizontal, 3)
            }
        }
        .padding(.top, 14)
    }

    private func actionLabel(_ title: String, systemImage: String?, primary: Bool) -> some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
            .font(ArchiveTheme.label(11))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(primary ? Color.white : ArchiveTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(primary ? ArchiveTheme.collectedRed : Color.white.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if !primary {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ArchiveTheme.catalogGray.opacity(0.15), lineWidth: 1)
                }
            }
    }

    // MARK: - My Collections (Profile → Collection, public / private)

    private var myCollectionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("MY COLLECTIONS")
                    .font(ArchiveTheme.heading(18))
                    .foregroundStyle(ArchiveTheme.ink)
                Spacer()
                if !categoriesWithObjects.isEmpty {
                    Text("\(publicCategories.count) PUBLIC")
                        .font(ArchiveTheme.label(10))
                        .tracking(0.7)
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
            }
            .padding(.top, 26)
            .padding(.horizontal, 3)

            if categoriesWithObjects.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 27))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                    Text("NO COLLECTIONS YET")
                        .font(ArchiveTheme.label(11))
                        .foregroundStyle(ArchiveTheme.ink)
                    Text("Add your first object with the + button.\nYour collections will show up here.")
                        .font(ArchiveTheme.body(12))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(Color.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(categoriesWithObjects) { category in
                    myCollectionRow(category)
                }

                Text(visibilityError ?? "Private collections are only visible to you. Public ones appear when you share your profile.")
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(visibilityError == nil ? ArchiveTheme.catalogGray : ArchiveTheme.collectedRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3)
            }
        }
    }

    private func myCollectionRow(_ category: CollectionCategory) -> some View {
        let count = store.count(for: category)
        return HStack(spacing: 12) {
            NavigationLink {
                ShelfDetailView(category: category)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(ArchiveTheme.paperTan.opacity(0.45))
                        Image(systemName: category.systemImage)
                            .font(.system(size: 21))
                            .foregroundStyle(ArchiveTheme.ink)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(category.title)
                            .font(ArchiveTheme.heading(16))
                            .foregroundStyle(ArchiveTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(count) OBJECT\(count == 1 ? "" : "S")")
                            .font(ArchiveTheme.label(9))
                            .tracking(0.5)
                            .foregroundStyle(ArchiveTheme.catalogGray)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this collection")

            visibilityMenu(for: category)
        }
        .padding(14)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(ArchiveTheme.catalogGray.opacity(0.10), lineWidth: 1)
        }
    }

    private func visibilityMenu(for category: CollectionCategory) -> some View {
        let current = profileStore.visibility(for: category)
        let selection = Binding<CollectionVisibility>(
            get: { profileStore.visibility(for: category) },
            set: { newValue in setVisibility(newValue, for: category) }
        )

        return Menu {
            Picker("Who can see this", selection: selection) {
                ForEach(CollectionVisibility.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            HStack(spacing: 5) {
                if updatingVisibility == category {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: current.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(current.title.uppercased())
                    .font(ArchiveTheme.label(9))
                    .tracking(0.6)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(current == .isPublic ? Color.white : ArchiveTheme.ink)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                current == .isPublic ? ArchiveTheme.collectedRed : ArchiveTheme.ivory,
                in: Capsule()
            )
        }
        .disabled(updatingVisibility != nil)
        .accessibilityLabel("\(category.title) is \(current.title.lowercased())")
        .accessibilityHint("Change who can see this collection")
    }

    private func setVisibility(_ visibility: CollectionVisibility, for category: CollectionCategory) {
        guard visibility != profileStore.visibility(for: category) else { return }
        updatingVisibility = category
        visibilityError = nil
        Task { @MainActor in
            do {
                try await profileStore.setVisibility(visibility, for: category)
                Haptics.selection()
            } catch {
                visibilityError = "Couldn't update \(category.title). \(error.localizedDescription)"
            }
            updatingVisibility = nil
        }
    }

    // MARK: - Shared Collections

    private var sharedCollectionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("SHARED COLLECTIONS")
                    .font(ArchiveTheme.heading(18))
                    .foregroundStyle(ArchiveTheme.ink)

                Spacer()

                NavigationLink {
                    CreateSharedCollectionView()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArchiveTheme.collectedRed)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.72))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Create a shared collection")
            }
            .padding(.top, 26)
            .padding(.horizontal, 3)

            if socialStore.sharedCollections.isEmpty {
                NavigationLink {
                    CreateSharedCollectionView()
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 27))
                            .foregroundStyle(ArchiveTheme.collectedRed)
                        Text("CREATE A SHARED COLLECTION")
                            .font(ArchiveTheme.label(11))
                            .foregroundStyle(ArchiveTheme.ink)
                        Text("Collect together with your friends.")
                            .font(ArchiveTheme.body(12))
                            .foregroundStyle(ArchiveTheme.catalogGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(Color.white.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(socialStore.sharedCollections) { collection in
                    NavigationLink {
                        SharedCollectionDetailView(collectionID: collection.id)
                    } label: {
                        sharedCollectionRow(collection)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sharedCollectionRow(_ collection: SharedCollection) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: [ArchiveTheme.collectedRed, ArchiveTheme.paperTan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 23))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 5) {
                Text(collection.name)
                    .font(ArchiveTheme.heading(16))
                    .foregroundStyle(ArchiveTheme.ink)
                    .lineLimit(1)

                // memberIDs already includes the current user.
                Text("\(collection.memberIDs.count) MEMBERS · \(collection.itemIDs.count) OBJECTS")
                    .font(ArchiveTheme.label(9))
                    .tracking(0.5)
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .lineLimit(1)

                HStack(spacing: -7) {
                    ProfileAvatarView(
                        image: profileStore.avatar,
                        initials: "ME",
                        size: 25
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7.5)
                            .stroke(ArchiveTheme.ivory, lineWidth: 2)
                    }

                    ForEach(Array(socialStore.members(of: collection).prefix(3))) { member in
                        SocialAvatarView(user: member, size: 25)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7.5)
                                    .stroke(ArchiveTheme.ivory, lineWidth: 2)
                            }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArchiveTheme.catalogGray)
        }
        .padding(14)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(ArchiveTheme.catalogGray.opacity(0.10), lineWidth: 1)
        }
    }
}

// MARK: - Settings (hamburger menu)

private struct ProfileSettingsView: View {
    @EnvironmentObject private var store: CollectionStore
    @ObservedObject var profileStore: ProfileStore

    @State private var showingEditProfile = false
    @State private var linkCopied = false
    @State private var importingCSV = false
    @State private var importMessage: String?
    @AppStorage(Haptics.settingKey) private var hapticsEnabled = true
    @AppStorage(AppTourReplay.key) private var replayTourRequested = false

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                Button { showingEditProfile = true } label: {
                    settingsRow("Edit profile", systemImage: "person.crop.circle")
                }

                Button(action: copyLink) {
                    settingsRow(
                        linkCopied ? "Link copied" : "Copy profile link",
                        systemImage: linkCopied ? "checkmark" : "link",
                        detail: profileStore.shareURL == nil ? "Add a handle first" : nil
                    )
                }
            } header: {
                sectionHeader("ACCOUNT")
            }

            Section {
                Picker(selection: $profileStore.defaultVisibility) {
                    ForEach(CollectionVisibility.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    settingsRow(
                        "Default visibility",
                        systemImage: profileStore.defaultVisibility.systemImage,
                        detail: "For collections you haven't set yourself"
                    )
                }
                .pickerStyle(.menu)
            } header: {
                sectionHeader("PRIVACY")
            } footer: {
                Text("You can still change each collection under My Collections on your profile.")
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            Section {
                Toggle(isOn: $hapticsEnabled) {
                    settingsRow("Haptics", systemImage: "iphone.radiowaves.left.and.right", detail: "Small vibrations when you tap")
                }
                .tint(ArchiveTheme.collectedRed)

                Button {
                    // AppRootView watches this and plays the tour.
                    replayTourRequested = true
                } label: {
                    settingsRow("Replay app tour", systemImage: "play.circle", detail: "See the 5-step intro again")
                }
            } header: {
                sectionHeader("APP")
            }

            Section {
                ShareLink(item: store.archiveURL) {
                    settingsRow("Export archive (JSON)", systemImage: "square.and.arrow.up")
                }

                Button { importingCSV = true } label: {
                    settingsRow("Import from CSV", systemImage: "square.and.arrow.down")
                }
            } header: {
                sectionHeader("ARCHIVE DATA")
            } footer: {
                Text("Your objects and memories live only on this phone. Export a copy before switching devices; photos aren't included. CSV columns: title, category, creator, year, price, condition, rarity, meaning, note, date, place, place_type, with, memory_note.")
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            Section {
                HStack {
                    settingsRow("Version", systemImage: "info.circle")
                    Spacer()
                    Text(appVersion)
                        .font(ArchiveTheme.body(13))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
            } header: {
                sectionHeader("ABOUT")
            }
        }
        .scrollContentBackground(.hidden)
        .background(ArchiveTheme.ivory.ignoresSafeArea())
        .tint(ArchiveTheme.ink)
        .navigationTitle("SETTINGS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(profileStore: profileStore)
        }
        .fileImporter(
            isPresented: $importingCSV,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            importCSV(result)
        }
        .alert(
            "Import",
            isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ArchiveTheme.label(10))
            .tracking(0.8)
            .foregroundStyle(ArchiveTheme.catalogGray)
    }

    private func settingsRow(_ title: String, systemImage: String, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(ArchiveTheme.ink)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ArchiveTheme.body(15))
                    .foregroundStyle(ArchiveTheme.ink)
                if let detail {
                    Text(detail)
                        .font(ArchiveTheme.body(11))
                        .foregroundStyle(ArchiveTheme.catalogGray)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func copyLink() {
        guard let url = profileStore.shareURL else {
            showingEditProfile = true
            return
        }
        UIPasteboard.general.string = url.absoluteString
        Haptics.light()
        withAnimation { linkCopied = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation { linkCopied = false }
        }
    }

    private func importCSV(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let imported = try CSVImporter.importFile(at: url)
                store.importItems(imported.items, moments: imported.moments)
                var message = "Added \(imported.items.count) objects and \(imported.moments.count) memories."
                if !imported.skippedRows.isEmpty {
                    let rows = imported.skippedRows.map(String.init).joined(separator: ", ")
                    message += " Skipped rows without a title: \(rows)."
                }
                importMessage = message
            } catch {
                importMessage = error.localizedDescription
            }
        case .failure(let error):
            importMessage = error.localizedDescription
        }
    }
}

// MARK: - Statistics

private struct ProfileStat: View {

    let value: Int

    let label: String

    var body: some View {

        VStack(spacing: 3) {

            Text("\(value)")

                .font(ArchiveTheme.heading(20))

                .foregroundStyle(ArchiveTheme.ink)

            Text(label)

                .font(ArchiveTheme.label(10))

                .foregroundStyle(ArchiveTheme.catalogGray)

                .tracking(0.6)

        }

        .frame(maxWidth: .infinity)

    }

}

// MARK: - Edit Profile

private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileStore: ProfileStore

    // Edits go into a draft, so CANCEL really cancels.
    @State private var name: String
    @State private var handle: String
    @State private var location: String
    @State private var bio: String

    @State private var avatarPreview: UIImage?
    @State private var avatarChange: ProfileStore.AvatarChange = .keep
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    @State private var handleStatus: HandleStatus = .unchanged
    @State private var isSaving = false
    @State private var saveError: String?

    private static let bioLimit = 150

    enum HandleStatus: Equatable {
        case unchanged
        case invalid(String)
        case checking
        case available
        case taken
        case failed
    }

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
        let profile = profileStore.profile
        _name = State(initialValue: profile.name)
        _handle = State(initialValue: profile.handle)
        _location = State(initialValue: profile.location)
        _bio = State(initialValue: profile.bio)
        _avatarPreview = State(initialValue: profileStore.avatar)
    }

    private var normalizedHandle: String { HandleRules.normalized(handle) }

    private var canSave: Bool {
        guard !isSaving, !isLoadingPhoto else { return false }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch handleStatus {
        case .unchanged, .available: return true
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArchiveTheme.ivory
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        avatarEditor

                        EditProfileField(
                            title: "NAME",
                            placeholder: "Your name",
                            text: $name
                        )
                        .textContentType(.name)

                        handleField

                        EditProfileField(
                            title: "LOCATION",
                            placeholder: "City (optional)",
                            text: $location
                        )

                        bioField

                        if let saveError {
                            Label(saveError, systemImage: "exclamationmark.triangle")
                                .font(ArchiveTheme.body(12))
                                .foregroundStyle(ArchiveTheme.collectedRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)

                if isSaving {
                    Color.black.opacity(0.08).ignoresSafeArea()
                    ProgressView("Saving…")
                        .font(ArchiveTheme.body(13))
                        .padding(20)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("EDIT PROFILE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                        .foregroundStyle(ArchiveTheme.catalogGray)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SAVE", action: save)
                        .font(ArchiveTheme.label(13))
                        .foregroundStyle(canSave ? ArchiveTheme.collectedRed : ArchiveTheme.catalogGray)
                        .disabled(!canSave)
                }
            }
            .task(id: handle) { await checkHandle() }
            .task(id: photoItem) { await loadPhoto() }
        }
        .interactiveDismissDisabled(isSaving)
        .presentationDetents([.large])
    }

    // MARK: Avatar

    private var avatarEditor: some View {
        VStack(spacing: 12) {
            ZStack {
                ProfileAvatarView(
                    image: avatarPreview,
                    initials: initials(for: name),
                    size: 104
                )
                if isLoadingPhoto {
                    RoundedRectangle(cornerRadius: 31)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 104, height: 104)
                    ProgressView().tint(.white)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(avatarPreview == nil ? "ADD PHOTO" : "CHANGE PHOTO")
                        .font(ArchiveTheme.label(10))
                        .foregroundStyle(ArchiveTheme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.78), in: Capsule())
                }
                .disabled(isLoadingPhoto || isSaving)

                if avatarPreview != nil {
                    Button {
                        avatarPreview = nil
                        avatarChange = .remove
                        photoItem = nil
                    } label: {
                        Text("REMOVE")
                            .font(ArchiveTheme.label(10))
                            .foregroundStyle(ArchiveTheme.collectedRed)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingPhoto || isSaving)
                }
            }

            if let photoError {
                Text(photoError)
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(ArchiveTheme.collectedRed)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        isLoadingPhoto = true
        photoError = nil
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self),
                  let prepared = AvatarImage.prepare(data),
                  let image = UIImage(data: prepared) else {
                photoError = ProfileServiceError.avatarUnreadable.localizedDescription
                return
            }
            avatarPreview = image
            avatarChange = .replace(prepared)
        } catch {
            photoError = ProfileServiceError.avatarUnreadable.localizedDescription
        }
    }

    private func initials(for name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "M" : letters.map(String.init).joined().uppercased()
    }

    // MARK: Handle

    private var handleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HANDLE")
                .font(ArchiveTheme.label(11))
                .foregroundStyle(ArchiveTheme.catalogGray)
                .tracking(0.8)

            HStack(spacing: 2) {
                Text("@")
                    .font(ArchiveTheme.body(15))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                TextField("yourhandle", text: $handle)
                    .font(ArchiveTheme.body(15))
                    .foregroundStyle(ArchiveTheme.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .onChange(of: handle) { _, newValue in
                        // Strip a typed "@" and capitals as the user types.
                        let cleaned = HandleRules.normalized(newValue)
                        if cleaned != newValue { handle = cleaned }
                    }
                handleStatusIcon
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(handleBorderColor, lineWidth: 1)
            }

            if let message = handleMessage {
                Text(message)
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(handleMessageColor)
            }
        }
    }

    @ViewBuilder
    private var handleStatusIcon: some View {
        switch handleStatus {
        case .checking:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .accessibilityLabel("Handle available")
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(ArchiveTheme.collectedRed)
                .accessibilityLabel("Handle not available")
        case .unchanged, .failed:
            EmptyView()
        }
    }

    private var handleMessage: String? {
        switch handleStatus {
        case .unchanged: return nil
        case .invalid(let message): return message
        case .checking: return "Checking…"
        case .available: return "\(HandleRules.display(normalizedHandle)) is available."
        case .taken: return "\(HandleRules.display(normalizedHandle)) is already taken."
        case .failed: return "Couldn't check this handle. Check your connection."
        }
    }

    private var handleMessageColor: Color {
        switch handleStatus {
        case .available: return Color.green
        case .invalid, .taken, .failed: return ArchiveTheme.collectedRed
        default: return ArchiveTheme.catalogGray
        }
    }

    private var handleBorderColor: Color {
        switch handleStatus {
        case .invalid, .taken: return ArchiveTheme.collectedRed.opacity(0.6)
        default: return Color.clear
        }
    }

    private func checkHandle() async {
        let candidate = normalizedHandle
        if candidate == profileStore.profile.handle && !candidate.isEmpty {
            handleStatus = .unchanged
            return
        }
        if let problem = HandleRules.problem(with: candidate) {
            handleStatus = .invalid(problem)
            return
        }
        handleStatus = .checking
        // Wait until the user pauses typing.
        try? await Task.sleep(nanoseconds: 450_000_000)
        guard !Task.isCancelled else { return }
        do {
            let available = try await profileStore.isHandleAvailable(candidate)
            guard !Task.isCancelled else { return }
            handleStatus = available ? .available : .taken
        } catch {
            guard !Task.isCancelled else { return }
            handleStatus = .failed
        }
    }

    // MARK: Bio

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BIO")
                    .font(ArchiveTheme.label(11))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .tracking(0.8)
                Spacer()
                Text("\(bio.count)/\(Self.bioLimit)")
                    .font(ArchiveTheme.label(10))
                    .foregroundStyle(ArchiveTheme.catalogGray)
            }

            TextEditor(text: $bio)
                .font(ArchiveTheme.body(15))
                .foregroundStyle(ArchiveTheme.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 115)
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: bio) { _, newValue in
                    if newValue.count > Self.bioLimit {
                        bio = String(newValue.prefix(Self.bioLimit))
                    }
                }
        }
    }

    // MARK: Save

    private func save() {
        guard canSave else { return }
        isSaving = true
        saveError = nil
        let updated = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            handle: normalizedHandle,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarFileName: profileStore.profile.avatarFileName
        )
        let change = avatarChange
        Task { @MainActor in
            do {
                try await profileStore.save(updated, avatarChange: change)
                Haptics.light()
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
                if (error as? ProfileServiceError) == .handleTaken {
                    handleStatus = .taken
                }
            }
        }
    }
}

private struct EditProfileField: View {

    let title: String
    var placeholder: String = ""
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ArchiveTheme.label(11))
                .foregroundStyle(ArchiveTheme.catalogGray)
                .tracking(0.8)

            TextField(placeholder, text: $text)
                .font(ArchiveTheme.body(15))
                .foregroundStyle(ArchiveTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(CollectionStore())
        .environmentObject(SocialStore())
        .environmentObject(CloudProfileStore())
}
