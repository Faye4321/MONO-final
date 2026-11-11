import SwiftUI

// Onboarding contributed by Crystal: splash, welcome, sign-in, required first
// object and guided tour. Adapted to use the app's tab bar and Create flow.

// New accounts: sign up → setup welcome → 1 what you collect → 2 first
// object (required) → first-object payoff → 3 tour (skippable) → all set.
enum AppEntryRoute {
    case splash
    case welcome
    case login
    case signUp
    case setupWelcome
    case preferences
    case firstUpload
    case firstUploadDone
    case tour
    case allSet
    case app
}

/// The collection types the user picked during setup. Used to default the
/// Create category and to order Picked for You.
enum CollectingPreferences {
    static let storageKey = "mono.collects"

    static func categories(from raw: String) -> [CollectionCategory] {
        raw.split(separator: ",").compactMap { CollectionCategory(rawValue: String($0)) }
    }

    static func raw(from categories: [CollectionCategory]) -> String {
        categories.map(\.rawValue).joined(separator: ",")
    }
}

struct AppRootView: View {
    @AppStorage("mono.didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var route: AppEntryRoute = .splash
    @State private var selectedTab: AppTab = .explore
    @State private var newMemberName = ""
    /// Set from Settings ▸ Replay app tour.
    @AppStorage(AppTourReplay.key) private var replayTourRequested = false
    @State private var isReplayingTour = false

    var body: some View {
        ZStack {
            BrandColor.archiveIvory.ignoresSafeArea()

            switch route {
            case .splash:
                MonoSplashView {
                    transition(to: didCompleteOnboarding ? .app : .welcome)
                }
            case .welcome:
                WelcomeView(
                    onLogin: { transition(to: .login) },
                    onCreateAccount: { transition(to: .signUp) }
                )
            case .login:
                AuthenticationView(mode: .login, onBack: { transition(to: .welcome) }) { _ in
                    // Replace this closure with the team's authentication service.
                    didCompleteOnboarding = true
                    transition(to: .app)
                }
            case .signUp:
                AuthenticationView(mode: .signUp, onBack: { transition(to: .welcome) }) { name in
                    newMemberName = name
                    // Saves the name to the ME page and suggests a handle from it.
                    Task { await ProfileStore.shared.applySignUp(name: name) }
                    transition(to: .setupWelcome)
                }
            case .setupWelcome:
                SetupWelcomeView(name: newMemberName) {
                    transition(to: .preferences)
                }
            case .preferences:
                CollectingPreferencesView {
                    transition(to: .firstUpload)
                }
            case .firstUpload:
                FirstObjectView {
                    transition(to: .firstUploadDone)
                }
            case .firstUploadDone:
                FirstObjectDoneView(
                    onTour: { transition(to: .tour) },
                    onSkip: { transition(to: .allSet) }
                )
            case .tour:
                GuidedAppTourView(
                    selection: $selectedTab,
                    onComplete: finishTour,
                    onSkip: finishTour
                )
            case .allSet:
                AllSetView {
                    didCompleteOnboarding = true
                    selectedTab = .explore
                    transition(to: .app)
                }
            case .app:
                RootTabView(selection: $selectedTab)
                    .transition(.opacity)
            }
        }
        .tint(BrandColor.collectedRed)
        .onChange(of: replayTourRequested) { _, requested in
            guard requested else { return }
            replayTourRequested = false
            isReplayingTour = true
            transition(to: .tour)
        }
    }

    /// A replayed tour goes straight back into the app; the first one
    /// continues to the "You're all set" page.
    private func finishTour() {
        if isReplayingTour {
            isReplayingTour = false
            selectedTab = .me
            transition(to: .app)
        } else {
            transition(to: .allSet)
        }
    }

    private func transition(to next: AppEntryRoute) {
        withAnimation(.easeInOut(duration: 0.42)) {
            route = next
        }
    }
}

private struct MonoSplashView: View {
    let onFinished: () -> Void
    @State private var archProgress: CGFloat = 0
    @State private var objectProgress: CGFloat = 0
    @State private var dotProgress: CGFloat = 0
    @State private var showsWordmark = false
    @State private var captionOpacity = 0.0

    var body: some View {
        VStack(spacing: 30) {
            MonoLogoView(
                size: 154,
                archProgress: archProgress,
                objectProgress: objectProgress,
                dotProgress: dotProgress,
                showsWordmark: showsWordmark
            )

            Text("A PLACE FOR THINGS YOU KEEP")
                .monoLabel(10, tracking: 1.8)
                .foregroundStyle(BrandColor.catalogGray)
                .opacity(captionOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard archProgress == 0 else { return }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.68)) {
                dotProgress = 0.22
            }
            try? await Task.sleep(for: .milliseconds(380))

            withAnimation(.easeInOut(duration: 0.95)) {
                dotProgress = 1
                archProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(600))

            withAnimation(.spring(response: 0.58, dampingFraction: 0.78)) {
                objectProgress = 1
            }
            try? await Task.sleep(for: .milliseconds(420))

            withAnimation(.easeOut(duration: 0.48)) {
                showsWordmark = true
                captionOpacity = 1
            }
            try? await Task.sleep(for: .milliseconds(1050))
            onFinished()
        }
    }
}

private struct WelcomeView: View {
    let onLogin: () -> Void
    let onCreateAccount: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        MonoWordmark(size: 38)
                        Spacer()
                        Text("PRIVATE BY DEFAULT")
                            .monoLabel(9, tracking: 1.2)
                            .foregroundStyle(BrandColor.catalogGray)
                    }

                    Spacer(minLength: max(64, proxy.size.height * 0.12))

                    MonoLogoView(size: min(190, proxy.size.width * 0.50))
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 54)

                    Text("Keep what\nyou love.")
                        .monoTitle(min(58, proxy.size.width * 0.15), tracking: -1.8)
                        .foregroundStyle(BrandColor.inkBlack)

                    Text("Catalog your collection, make something new from it, and share only what you choose.")
                        .monoBody(17)
                        .foregroundStyle(BrandColor.catalogGray)
                        .lineSpacing(5)
                        .padding(.top, 20)
                        .frame(maxWidth: 520, alignment: .leading)

                    Spacer(minLength: 48)

                    MonoPrimaryButton(title: "CREATE AN ACCOUNT", action: onCreateAccount)
                    Button(action: onLogin) {
                        Text("I ALREADY HAVE AN ACCOUNT")
                            .monoLabel(11, tracking: 1.0)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.inkBlack)
                }
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 26)
                .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private enum AuthenticationMode {
    case login
    case signUp

    var title: String { self == .login ? "Welcome back." : "Begin your archive." }
    var eyebrow: String { self == .login ? "MEMBER LOGIN" : "NEW COLLECTOR" }
    var button: String { self == .login ? "LOG IN" : "CREATE ACCOUNT" }
}

private struct AuthenticationView: View {
    let mode: AuthenticationMode
    let onBack: () -> Void
    /// Called with the trimmed display name (empty when logging in).
    let onSuccess: (String) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var attemptedSubmit = false
    @FocusState private var focusedField: AuthField?

    private var isValid: Bool {
        let validIdentity = mode == .login || name.trimmingCharacters(in: .whitespaces).count >= 2
        return validIdentity && email.contains("@") && password.count >= 6
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MonoBackButton(action: onBack)
                Text(mode.eyebrow)
                    .monoLabel()
                    .foregroundStyle(BrandColor.collectedRed)
                    .padding(.top, 50)
                Text(mode.title)
                    .monoTitle(43, tracking: -1.1)
                    .padding(.top, 8)
                Text(mode == .login ? "Return to the objects and people you follow." : "One account. Every object, story, and collection in its place.")
                    .monoBody(16)
                    .foregroundStyle(BrandColor.catalogGray)
                    .lineSpacing(4)
                    .padding(.top, 14)

                VStack(spacing: 18) {
                    if mode == .signUp {
                        MonoTextField(label: "DISPLAY NAME", placeholder: "How should we call you?", text: $name, focus: $focusedField, field: .name)
                            .textContentType(.name)
                    }
                    MonoTextField(label: "EMAIL", placeholder: "you@example.com", text: $email, focus: $focusedField, field: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    // `.password` rather than `.newPassword`: the strong-password
                    // AutoFill that `.newPassword` triggers can block typing,
                    // especially in the Simulator.
                    MonoTextField(label: "PASSWORD", placeholder: "At least 6 characters", text: $password, isSecure: true, focus: $focusedField, field: .password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.top, 42)

                if attemptedSubmit && !isValid {
                    Text("Please complete every field with a valid email and a password of at least 6 characters.")
                        .monoBody(12)
                        .foregroundStyle(BrandColor.collectedRed)
                        .padding(.top, 14)
                }

                MonoPrimaryButton(title: mode.button) {
                    attemptedSubmit = true
                    focusedField = nil
                    guard isValid else { return }
                    Haptics.light()
                    onSuccess(mode == .signUp ? name.trimmingCharacters(in: .whitespaces) : "")
                }
                .padding(.top, 34)

                Text(mode == .login ? "Demo note: authentication is ready to connect to your team's backend." : "By continuing, you agree to MONO's Terms and Privacy Policy.")
                    .monoBody(11)
                    .foregroundStyle(BrandColor.catalogGray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private enum AuthField {
    case name
    case email
    case password
}

private struct MonoTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var focus: FocusState<AuthField?>.Binding
    let field: AuthField

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .monoLabel(10, tracking: 1.1)
                .foregroundStyle(BrandColor.catalogGray)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused(focus, equals: field)
            .monoBody(16)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(BrandColor.inkBlack.opacity(0.10), lineWidth: 1)
            }
            // Tapping anywhere in the box, not just on the text line, focuses it.
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                focus.wrappedValue = field
            }
        }
    }
}

struct MonoPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .monoLabel(11, tracking: 1.0)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(BrandColor.archiveIvory)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(BrandColor.inkBlack, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(MonoPressButtonStyle())
    }
}

struct MonoBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.70), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BrandColor.inkBlack)
        .accessibilityLabel("Back")
    }
}

private struct MonoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Setup

/// "SETTING UP YOUR ARCHIVE · 2 OF 3" with a segmented bar, shown on every
/// setup step so it is clear this is onboarding, not the app itself.
private struct OnboardingProgress: View {
    let step: Int
    private let total = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SETTING UP YOUR ARCHIVE · \(step) OF \(total)")
                .monoLabel(9, tracking: 1.1)
                .foregroundStyle(BrandColor.catalogGray)
            HStack(spacing: 4) {
                ForEach(1...total, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? BrandColor.collectedRed : BrandColor.inkBlack.opacity(0.12))
                        .frame(height: 3)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setting up your archive, step \(step) of \(total)")
    }
}

private struct SetupWelcomeView: View {
    let name: String
    let onBegin: () -> Void

    private var greeting: String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Welcome." : "Welcome, \(first)."
    }

    private let steps = [
        "Tell us what you collect",
        "Add your first object",
        "A quick look around"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoWordmark(size: 34)

            Spacer(minLength: 40)

            Text(greeting)
                .monoTitle(46, tracking: -1.4)
                .foregroundStyle(BrandColor.inkBlack)
            Text("Let's set up your archive — 3 quick steps.")
                .monoBody(17)
                .foregroundStyle(BrandColor.catalogGray)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 16) {
                        Text("\(index + 1)")
                            .monoHeading(15)
                            .foregroundStyle(BrandColor.collectedRed)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle().stroke(BrandColor.collectedRed.opacity(0.4), lineWidth: 1)
                            }
                        Text(step)
                            .monoBody(16)
                            .foregroundStyle(BrandColor.inkBlack)
                    }
                }
            }
            .padding(.top, 40)

            Spacer(minLength: 40)

            MonoPrimaryButton(title: "LET'S BEGIN", action: onBegin)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }
}

private struct CollectingPreferencesView: View {
    @AppStorage(CollectingPreferences.storageKey) private var collectsRaw = ""
    @State private var selected: [CollectionCategory] = []
    let onContinue: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgress(step: 1)

            Text("What do you collect?")
                .monoTitle(36, tracking: -0.9)
                .foregroundStyle(BrandColor.inkBlack)
                .padding(.top, 34)
            Text("Pick all that apply. We'll set up Create and your picks around them.")
                .monoBody(15)
                .foregroundStyle(BrandColor.catalogGray)
                .lineSpacing(3)
                .padding(.top, 10)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CollectionCategory.allCases) { category in
                    tile(for: category)
                }
            }
            .padding(.top, 30)

            Spacer(minLength: 30)

            MonoPrimaryButton(title: "CONTINUE") {
                collectsRaw = CollectingPreferences.raw(from: selected)
                onContinue()
            }
            .disabled(selected.isEmpty)
            .opacity(selected.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .onAppear {
            selected = CollectingPreferences.categories(from: collectsRaw)
        }
    }

    private func tile(for category: CollectionCategory) -> some View {
        let isSelected = selected.contains(category)
        return Button {
            Haptics.selection()
            if isSelected {
                selected.removeAll { $0 == category }
            } else {
                selected.append(category)
            }
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 24, weight: .light))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? BrandColor.collectedRed : BrandColor.catalogGray.opacity(0.5))
                }
                Text(category.title)
                    .monoHeading(15)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(BrandColor.inkBlack)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(Color.white.opacity(isSelected ? 0.95 : 0.6), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? BrandColor.collectedRed : BrandColor.inkBlack.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// New accounts must add one object before entering the app. Uses the
// regular Create flow so the object, and its optional memory, is saved.
private struct FirstObjectView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                OnboardingProgress(step: 2)
                Text("This becomes the first page of your collection journey.")
                    .monoBody(13)
                    .foregroundStyle(BrandColor.catalogGray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            CreateFlowView(onSaved: onComplete)
        }
        .background(BrandColor.archiveIvory.ignoresSafeArea())
    }
}

/// The payoff after the first object: show it, and offer the tour.
private struct FirstObjectDoneView: View {
    @EnvironmentObject private var store: CollectionStore
    let onTour: () -> Void
    let onSkip: () -> Void

    private var firstObject: CollectibleItem? {
        store.items.last { $0.isUserCreated }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgress(step: 2)

            Spacer(minLength: 24)

            if let item = firstObject {
                VStack(alignment: .leading, spacing: 12) {
                    ArtworkView(item: item)
                        .frame(width: 190, height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
                    Text(item.title)
                        .monoHeading(18)
                    Text(item.category.shelfLabel)
                        .monoLabel(9, tracking: 1.0)
                        .foregroundStyle(BrandColor.catalogGray)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 24)

            Text("Your archive has begun.")
                .monoTitle(36, tracking: -0.9)
                .foregroundStyle(BrandColor.inkBlack)
            Label("It's now on your collection calendar.", systemImage: "calendar")
                .monoBody(15)
                .foregroundStyle(BrandColor.catalogGray)
                .padding(.top, 10)

            MonoPrimaryButton(title: "TAKE A 30-SECOND TOUR", action: onTour)
                .padding(.top, 30)
            Button(action: onSkip) {
                Text("SKIP")
                    .monoLabel(11, tracking: 1.0)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BrandColor.inkBlack)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }
}

private struct AllSetView: View {
    let onEnter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 40)

            MonoLogoView(size: 120)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 40)

            Text("You're all set.")
                .monoTitle(46, tracking: -1.4)
                .foregroundStyle(BrandColor.inkBlack)
            Text("Explore is your home. Add more objects anytime from Create.")
                .monoBody(17)
                .foregroundStyle(BrandColor.catalogGray)
                .lineSpacing(4)
                .padding(.top, 14)

            MonoPrimaryButton(title: "ENTER MONO", action: onEnter)
                .padding(.top, 40)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }
}

// MARK: - Guided Tour

enum AppTourReplay {
    static let key = "mono.replayTourRequested"
}

private struct FeatureTourItem: Identifiable {
    let id = UUID()
    let tab: AppTab
    let eyebrow: String
    let title: String
    let body: String
    var tip: TourTip? = nil
}

/// A small how-to shown under a tour step, e.g. how to delete an object.
private struct TourTip {
    let systemImage: String
    let title: String
    let text: String
}

private struct GuidedAppTourView: View {
    @Binding var selection: AppTab
    let onComplete: () -> Void
    let onSkip: () -> Void
    @State private var page = 0

    private let barHeight: CGFloat = 64

    private let items = [
        FeatureTourItem(tab: .explore, eyebrow: "01 · EXPLORE", title: "Start with what feels relevant.", body: "Discover picks worth adding, and revisit your collection journey month by month."),
        FeatureTourItem(
            tab: .collection,
            eyebrow: "02 · COLLECTION",
            title: "Everything you keep, organized.",
            body: "Every object in your archive, on its own shelf.",
            tip: TourTip(
                systemImage: "hand.point.up.left",
                title: "TO DELETE AN OBJECT",
                text: "Open its shelf, press and hold the object, then tap Delete Item. Its memories are deleted too."
            )
        ),
        FeatureTourItem(tab: .create, eyebrow: "03 · CREATE", title: "Add the next object.", body: "Photograph, edit, and record the details and memories that make each piece yours."),
        FeatureTourItem(tab: .lab, eyebrow: "04 · LAB", title: "Turn objects into compositions.", body: "Cut out pieces from your archive and arrange them into shareable journal-like collages."),
        FeatureTourItem(tab: .me, eyebrow: "05 · ME", title: "Your collection, your story.", body: "See what you've gathered, where it came from, and the journey behind it.")
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let tabWidth = width / CGFloat(items.count)
            let barTop = proxy.size.height - barHeight
            let insets = proxy.safeAreaInsets
            // The tour draws its own tab bar over the system one, so the
            // spotlight lines up exactly whatever style the system bar uses.
            let target = CGRect(
                x: tabWidth * CGFloat(page) + 4,
                y: barTop + 4,
                width: tabWidth - 8,
                height: barHeight - 8
            )

            ZStack {
                RootTabView(selection: $selection)
                    .allowsHitTesting(false)

                BrandColor.archiveIvory
                    .frame(width: width, height: barHeight + insets.bottom)
                    .position(x: width / 2, y: barTop + (barHeight + insets.bottom) / 2)

                TourTabBar(tabs: items.map(\.tab), highlighted: items[page].tab)
                    .frame(width: width, height: barHeight)
                    .position(x: width / 2, y: barTop + barHeight / 2)

                SpotlightDimmer(target: target, insets: insets)

                HStack(alignment: .top) {
                    OnboardingProgress(step: 3)
                        .frame(maxWidth: 220)
                        .padding(12)
                        .background(BrandColor.archiveIvory, in: RoundedRectangle(cornerRadius: 14))
                    Spacer()
                    Button(action: onSkip) {
                        Text("SKIP")
                            .monoLabel(11, tracking: 1.0)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(BrandColor.archiveIvory, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.inkBlack)
                    .accessibilityLabel("Skip tour")
                }
                .padding(.horizontal, 18)
                .frame(width: width)
                .position(x: width / 2, y: 40)

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text(items[page].eyebrow)
                            .monoLabel(10, tracking: 1.2)
                            .foregroundStyle(BrandColor.collectedRed)
                        Spacer()
                        Text("\(page + 1) / \(items.count)")
                            .monoLabel(10)
                            .foregroundStyle(BrandColor.catalogGray)
                    }
                    Text(items[page].title)
                        .monoTitle(28, tracking: -0.6)
                    Text(items[page].body)
                        .monoBody(14)
                        .foregroundStyle(BrandColor.catalogGray)
                        .lineSpacing(3)
                    if let tip = items[page].tip {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: tip.systemImage)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(BrandColor.collectedRed)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .monoLabel(9, tracking: 1.0)
                                    .foregroundStyle(BrandColor.collectedRed)
                                Text(tip.text)
                                    .monoBody(13)
                                    .foregroundStyle(BrandColor.inkBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityElement(children: .combine)
                    }
                    HStack(spacing: 7) {
                        Image(systemName: "hand.tap")
                        Text("TAP THE HIGHLIGHTED TAB")
                    }
                    .monoLabel(10, tracking: 0.9)
                    .foregroundStyle(BrandColor.inkBlack)
                }
                .padding(22)
                .background(BrandColor.archiveIvory, in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.75), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.18), radius: 28, y: 12)
                .padding(.horizontal, 22)
                // Pinned just above the highlighted tab, so a taller step
                // (like the delete tip) never covers it on small iPhones.
                .frame(width: width, height: max(barTop - 46, 0), alignment: .bottom)
                .position(x: width / 2, y: max(barTop - 46, 0) / 2)

                Button {
                    Haptics.selection()
                    selection = items[page].tab
                    if page == items.count - 1 {
                        onComplete()
                    } else {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            page += 1
                        }
                    }
                } label: {
                    Color.clear
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
                .frame(width: target.width, height: target.height)
                .position(x: target.midX, y: target.midY)
                .accessibilityLabel("Open \(items[page].tab.title)")
            }
            .onAppear { selection = items[page].tab }
            .onChange(of: page) { _, newValue in
                selection = items[newValue].tab
            }
        }
    }
}

// The tab bar drawn during the tour, matching the app's tabs.
private struct TourTabBar: View {
    let tabs: [AppTab]
    let highlighted: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Group {
                    if tab == .create {
                        CreateTabButton(isSelected: tab == highlighted)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 19, weight: .medium))
                            Text(tab.title)
                                .monoLabel(8, tracking: 0.4)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(tab == highlighted ? BrandColor.collectedRed : BrandColor.inkBlack)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BrandColor.inkBlack.opacity(0.08))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct SpotlightDimmer: View {
    let target: CGRect
    var insets = EdgeInsets()

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                // Extend past the safe area so the status bar and home
                // indicator areas are dimmed too.
                path.addRect(CGRect(
                    x: 0,
                    y: -insets.top,
                    width: proxy.size.width,
                    height: proxy.size.height + insets.top + insets.bottom
                ))
                path.addRoundedRect(
                    in: target.insetBy(dx: -3, dy: -3),
                    cornerSize: CGSize(width: 24, height: 24)
                )
            }
            .fill(Color.black.opacity(0.64), style: FillStyle(eoFill: true))

            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.92), lineWidth: 2)
                .frame(width: target.width + 6, height: target.height + 6)
                .position(x: target.midX, y: target.midY)
                .shadow(color: .white.opacity(0.38), radius: 9)

            Image(systemName: "arrow.down")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .position(x: target.midX, y: target.minY - 22)
                .symbolEffect(.bounce, options: .repeating)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Onboarding") {
    AppRootView()
        .environmentObject(CollectionStore())
}
