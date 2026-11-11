import SwiftUI

import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {

    @EnvironmentObject private var store: CollectionStore

    @EnvironmentObject private var socialStore: SocialStore

    @AppStorage("profile.name")

    private var profileName = "Shuning Xu"

    @AppStorage("profile.handle")

    private var profileHandle = "@shuningcollects"

    @AppStorage("profile.location")

    private var profileLocation = "Los Angeles"

    @AppStorage("profile.bio")

    private var profileBio =

        "Collecting vinyl, movie posters, and objects worth keeping."

    @State private var showingEditProfile = false
    @State private var importingCSV = false
    @State private var importMessage: String?

    private var uploadedCount: Int {
        store.activeItems.filter(\.isUserCreated).count
    }

    private var activeCategoryCount: Int {

        CollectionCategory.allCases.filter {

            store.count(for: $0) > 0

        }.count

    }

    private var initials: String {

        let parts = profileName

            .split(separator: " ")

            .prefix(2)

        let result = parts.compactMap { $0.first }

        return result.isEmpty

            ? "M"

            : result.map(String.init).joined().uppercased()

    }

    var body: some View {

        NavigationStack {

            ZStack {

                ArchiveTheme.ivory

                    .ignoresSafeArea()

                ScrollView {

                    VStack(spacing: 0) {

                        topBar

                        profileCard
                        socialActionSection
                        sharedCollectionsSection
                        friendsCollectionsSection
                        PastCollectionSection()
                        archiveSection
                    }

                    .padding(.horizontal, 18)

                    .padding(.bottom, 32)

                }

                .scrollIndicators(.hidden)

            }

            .toolbar(.hidden, for: .navigationBar)
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
            .sheet(isPresented: $showingEditProfile) {

                EditProfileView(

                    name: $profileName,

                    handle: $profileHandle,

                    location: $profileLocation,

                    bio: $profileBio

                )

            }
            .onAppear {
                socialStore.seedSharedCollectionItems(
                    from: store.items
                )
            }

        }

    }

    private var topBar: some View {

        HStack {

            Text("PROFILE")

                .font(ArchiveTheme.display(32))

                .foregroundStyle(ArchiveTheme.ink)

            Spacer()

            Button {

                showingEditProfile = true

            } label: {

                Image(systemName: "pencil")

                    .font(.system(size: 17, weight: .medium))

                    .foregroundStyle(ArchiveTheme.ink)

                    .frame(width: 46, height: 46)

                    .background(Color.white.opacity(0.72))

                    .clipShape(Circle())

                    .overlay {

                        Circle()

                            .stroke(

                                ArchiveTheme.catalogGray.opacity(0.15),

                                lineWidth: 1

                            )

                    }

            }

            .buttonStyle(.plain)

            .accessibilityLabel("Edit profile")

        }

        .padding(.top, 18)

        .padding(.bottom, 16)

    }

    private var profileCard: some View {

        VStack(spacing: 18) {

            HStack(spacing: 15) {

                ZStack(alignment: .bottomTrailing) {

                    ZStack {

                        RoundedRectangle(cornerRadius: 23)

                            .fill(

                                LinearGradient(

                                    colors: [

                                        ArchiveTheme.paperTan.opacity(0.65),

                                        ArchiveTheme.collectedRed.opacity(0.92)

                                    ],

                                    startPoint: .topLeading,

                                    endPoint: .bottomTrailing

                                )

                            )

                        Text(initials)

                            .font(ArchiveTheme.heading(23))

                            .foregroundStyle(Color.white)

                    }

                    .frame(width: 76, height: 76)

                    Circle()

                        .fill(ArchiveTheme.cabinet)

                        .frame(width: 18, height: 18)

                        .overlay {

                            Circle()

                                .stroke(Color.white, lineWidth: 3)

                        }

                        .offset(x: 3, y: 3)

                }

                VStack(alignment: .leading, spacing: 4) {

                    Text(profileName)

                        .font(ArchiveTheme.heading(21))

                        .foregroundStyle(ArchiveTheme.ink)

                        .lineLimit(1)

                    Text("\(profileHandle) · \(profileLocation)")

                        .font(ArchiveTheme.body(12))

                        .foregroundStyle(ArchiveTheme.catalogGray)

                        .lineLimit(1)

                    Text(profileBio)

                        .font(ArchiveTheme.body(12))

                        .foregroundStyle(ArchiveTheme.ink.opacity(0.82))

                        .lineLimit(2)

                        .padding(.top, 3)

                }

                Spacer(minLength: 0)

            }

            Rectangle()

                .fill(ArchiveTheme.catalogGray.opacity(0.15))

                .frame(height: 1)

            HStack(spacing: 0) {

                ProfileStat(
                    value: store.activeItems.count,
                    label: "OBJECTS"
                )

                statDivider

                ProfileStat(

                    value: activeCategoryCount,

                    label: "COLLECTIONS"

                )

                statDivider

                ProfileStat(

                    value: socialStore.friends.count,

                    label: "FRIENDS"

                )

            }

        }

        .padding(18)

        .background(Color.white.opacity(0.76))

        .clipShape(RoundedRectangle(cornerRadius: 25))

        .overlay {

            RoundedRectangle(cornerRadius: 25)

                .stroke(

                    ArchiveTheme.catalogGray.opacity(0.10),

                    lineWidth: 1

                )

        }

        .shadow(

            color: ArchiveTheme.ink.opacity(0.06),

            radius: 14,

            y: 6

        )

    }

    private var statDivider: some View {

        Rectangle()

            .fill(ArchiveTheme.catalogGray.opacity(0.15))

            .frame(width: 1, height: 34)

    }

    private var socialActionSection: some View {

        HStack(spacing: 10) {

            ShareLink(
                item: "Explore my MonArchive collection. \(store.items.count) objects across \(activeCategoryCount) collections."
            ) {

                Label(

                    "SHARE",

                    systemImage: "square.and.arrow.up"

                )

                .font(ArchiveTheme.label(11))

                .foregroundStyle(Color.white)

                .frame(maxWidth: .infinity)

                .frame(height: 48)

                .background(ArchiveTheme.collectedRed)

                .clipShape(

                    RoundedRectangle(cornerRadius: 15)

                )

            }

            NavigationLink {

                FriendsView()

            } label: {

                Label(

                    "FRIENDS",

                    systemImage: "person.2"

                )

                .font(ArchiveTheme.label(11))

                .foregroundStyle(ArchiveTheme.ink)

                .frame(maxWidth: .infinity)

                .frame(height: 48)

                .background(Color.white.opacity(0.76))

                .clipShape(

                    RoundedRectangle(cornerRadius: 15)

                )

                .overlay {

                    RoundedRectangle(cornerRadius: 15)

                        .stroke(

                            ArchiveTheme.catalogGray.opacity(0.15),

                            lineWidth: 1

                        )

                }

            }

            .buttonStyle(.plain)

        }

        .padding(.top, 14)

    }

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

                        SharedCollectionDetailView(

                            collectionID: collection.id

                        )

                    } label: {

                        sharedCollectionRow(collection)

                    }

                    .buttonStyle(.plain)

                }

            }

        }

    }

    private func sharedCollectionRow(

        _ collection: SharedCollection

    ) -> some View {

        HStack(spacing: 14) {

            ZStack {

                RoundedRectangle(cornerRadius: 13)

                    .fill(

                        LinearGradient(

                            colors: [

                                ArchiveTheme.collectedRed,

                                ArchiveTheme.paperTan

                            ],

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

                Text(

                    "\(collection.memberIDs.count + 1) MEMBERS · \(collection.itemIDs.count) OBJECTS"

                )

                .font(ArchiveTheme.label(9))

                .tracking(0.5)

                .foregroundStyle(ArchiveTheme.catalogGray)

                HStack(spacing: -7) {

                    ZStack {

                        Circle()

                            .fill(ArchiveTheme.ink)

                        Text("ME")

                            .font(ArchiveTheme.label(7))

                            .foregroundStyle(ArchiveTheme.ivory)

                    }

                    .frame(width: 25, height: 25)

                    .overlay {

                        Circle()

                            .stroke(ArchiveTheme.ivory, lineWidth: 2)

                    }

                    ForEach(

                        Array(

                            socialStore

                                .members(of: collection)

                                .prefix(3)

                        )

                    ) { member in

                        SocialAvatarView(

                            user: member,

                            size: 25

                        )

                        .overlay {

                            Circle()

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

                .stroke(

                    ArchiveTheme.catalogGray.opacity(0.10),

                    lineWidth: 1

                )

        }

    }

    private var friendsCollectionsSection: some View {

        VStack(spacing: 12) {

            HStack {

                Text("FRIENDS' COLLECTIONS")

                    .font(ArchiveTheme.heading(18))

                    .foregroundStyle(ArchiveTheme.ink)

                Spacer()

                NavigationLink {

                    FriendsView()

                } label: {

                    Text("VIEW ALL")

                        .font(ArchiveTheme.label(10))

                        .foregroundStyle(ArchiveTheme.collectedRed)

                }

            }

            .padding(.top, 26)

            .padding(.horizontal, 3)

            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: 12) {

                    ForEach(socialStore.friends) { friend in

                        NavigationLink {

                            FriendProfileView(user: friend)

                        } label: {

                            VStack(alignment: .leading, spacing: 11) {

                                HStack {

                                    SocialAvatarView(

                                        user: friend,

                                        size: 46

                                    )

                                    Spacer()

                                    Image(systemName: "arrow.up.right")

                                        .font(.system(size: 11))

                                        .foregroundStyle(

                                            ArchiveTheme.catalogGray

                                        )

                                }

                                Text(friend.name)

                                    .font(ArchiveTheme.heading(16))

                                    .foregroundStyle(ArchiveTheme.ink)

                                Text(friend.handle)

                                    .font(ArchiveTheme.body(11))

                                    .foregroundStyle(

                                        ArchiveTheme.catalogGray

                                    )

                                Text(

                                    "\(friend.objectCount) OBJECTS · \(friend.collectionCount) COLLECTIONS"

                                )

                                .font(ArchiveTheme.label(9))

                                .foregroundStyle(

                                    ArchiveTheme.collectedRed

                                )

                                .lineLimit(1)

                            }

                            .frame(width: 155, alignment: .leading)

                            .padding(15)

                            .background(Color.white.opacity(0.72))

                            .clipShape(

                                RoundedRectangle(cornerRadius: 17)

                            )

                            .overlay {

                                RoundedRectangle(cornerRadius: 17)

                                    .stroke(

                                        ArchiveTheme.catalogGray.opacity(0.10),

                                        lineWidth: 1

                                    )

                            }

                        }

                        .buttonStyle(.plain)

                    }

                }

            }

        }

    }
}

// MARK: - Archive Data

extension ProfileView {
    var archiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ARCHIVE DATA")
                .font(ArchiveTheme.heading(18))
                .foregroundStyle(ArchiveTheme.ink)
                .padding(.top, 24)
                .padding(.horizontal, 3)

            VStack(alignment: .leading, spacing: 14) {
                Text("Your objects and memories live only on this phone. Export a copy before switching devices. Photos are not included in the export.")
                    .font(ArchiveTheme.body(12))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .lineSpacing(3)

                ShareLink(item: store.archiveURL) {
                    Label("EXPORT ARCHIVE (JSON)", systemImage: "square.and.arrow.up")
                        .font(ArchiveTheme.label(11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(ArchiveTheme.ink, in: Capsule())
                }

                Button {
                    importingCSV = true
                } label: {
                    Label("IMPORT FROM CSV", systemImage: "square.and.arrow.down")
                        .font(ArchiveTheme.label(11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(ArchiveTheme.ink)
                        .background(ArchiveTheme.ivory, in: Capsule())
                }
                .buttonStyle(.plain)

                Text("Columns: title, category, creator, year, price, condition, rarity, meaning, note, date, place, place_type, with, memory_note. Rows with the same date, place and people become one memory.")
                    .font(ArchiveTheme.body(11))
                    .foregroundStyle(ArchiveTheme.catalogGray)
                    .lineSpacing(2)
            }
            .padding(18)
            .background(Color.white.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 25))
        }
    }
}

extension ProfileView {
    func importCSV(_ result: Result<URL, Error>) {
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

    @Binding var name: String

    @Binding var handle: String

    @Binding var location: String

    @Binding var bio: String

    var body: some View {

        NavigationStack {

            ZStack {

                ArchiveTheme.ivory

                    .ignoresSafeArea()

                ScrollView {

                    VStack(spacing: 18) {

                        EditProfileField(

                            title: "NAME",

                            text: $name

                        )

                        EditProfileField(

                            title: "HANDLE",

                            text: $handle

                        )

                        EditProfileField(

                            title: "LOCATION",

                            text: $location

                        )

                        VStack(alignment: .leading, spacing: 8) {

                            Text("BIO")

                                .font(ArchiveTheme.label(11))

                                .foregroundStyle(ArchiveTheme.catalogGray)

                                .tracking(0.8)

                            TextEditor(text: $bio)

                                .font(ArchiveTheme.body(15))

                                .foregroundStyle(ArchiveTheme.ink)

                                .scrollContentBackground(.hidden)

                                .padding(10)

                                .frame(minHeight: 115)

                                .background(Color.white.opacity(0.78))

                                .clipShape(

                                    RoundedRectangle(cornerRadius: 16)

                                )

                        }

                    }

                    .padding(20)

                }

            }

            .navigationTitle("EDIT PROFILE")

            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("CANCEL") {

                        dismiss()

                    }

                    .foregroundStyle(ArchiveTheme.catalogGray)

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("SAVE") {

                        dismiss()

                    }

                    .font(ArchiveTheme.label(13))

                    .foregroundStyle(ArchiveTheme.collectedRed)

                }

            }

        }

        .presentationDetents([.medium, .large])

    }

}

private struct EditProfileField: View {

    let title: String

    @Binding var text: String

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(title)

                .font(ArchiveTheme.label(11))

                .foregroundStyle(ArchiveTheme.catalogGray)

                .tracking(0.8)

            TextField("", text: $text)

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

}

