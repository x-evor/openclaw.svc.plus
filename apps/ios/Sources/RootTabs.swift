import OpenClawKit
import SwiftUI

struct RootTabs: View {
    private enum AppTab: Hashable {
        case home
        case overview
        case account
        case settings
    }

    @Environment(NodeAppModel.self) private var appModel
    @Environment(VoiceWakeManager.self) private var voiceWake

    @State private var selectedTab: AppTab = .home
    @State private var showChatSheet: Bool = false
    @State private var chatUnavailableMessage: String?
    @State private var voiceWakeToastText: String?
    @State private var toastDismissTask: Task<Void, Never>?

    var body: some View {
        TabView(selection: self.$selectedTab) {
            HomeHubTab(
                openChat: { self.openChat() },
                openOverview: { self.selectedTab = .overview },
                openAccount: { self.selectedTab = .account },
                openSettings: { self.selectedTab = .settings })
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            MonitoringOverviewTab(
                openChat: { self.openChat() },
                openSettings: { self.selectedTab = .settings })
                .tabItem {
                    Label("总览", systemImage: "waveform.path.ecg")
                }
                .tag(AppTab.overview)

            AccountLoginTab(
                openChat: { self.openChat() },
                openOverview: { self.selectedTab = .overview })
                .tabItem {
                    Label("账号登录", systemImage: "person.crop.circle")
                }
                .tag(AppTab.account)

            SettingsTab()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(self.appModel.seamColor)
        .sheet(isPresented: self.$showChatSheet) {
            ChatSheet(
                gateway: self.appModel.operatorSession,
                sessionKey: self.appModel.chatSessionKey,
                agentName: self.appModel.activeAgentName,
                userAccent: self.appModel.seamColor)
        }
        .alert("当前无法进入对话", isPresented: self.chatUnavailableBinding) {
            Button("查看总览") {
                self.selectedTab = .overview
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text(self.chatUnavailableMessage ?? "请先连接网关。")
        }
        .overlay(alignment: .top) {
            if let voiceWakeToastText, !voiceWakeToastText.isEmpty {
                VoiceWakeToast(command: voiceWakeToastText)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: self.voiceWake.lastTriggeredCommand) { _, newValue in
            guard let newValue else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            self.toastDismissTask?.cancel()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                self.voiceWakeToastText = trimmed
            }

            self.toastDismissTask = Task {
                try? await Task.sleep(nanoseconds: 2_300_000_000)
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.voiceWakeToastText = nil
                    }
                }
            }
        }
        .onChange(of: self.appModel.openChatRequestID) { _, _ in
            self.openChat()
        }
        .onDisappear {
            self.toastDismissTask?.cancel()
            self.toastDismissTask = nil
        }
    }

    private var chatUnavailableBinding: Binding<Bool> {
        Binding(
            get: { self.chatUnavailableMessage != nil },
            set: { shouldPresent in
                if !shouldPresent {
                    self.chatUnavailableMessage = nil
                }
            })
    }

    private func openChat() {
        if self.appModel.gatewayServerName == nil {
            self.chatUnavailableMessage = "请先在总览页完成网关连接，再进入对话。"
            return
        }
        self.showChatSheet = true
    }
}

private struct HomeHubTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(VoiceWakeManager.self) private var voiceWake
    @AppStorage(VoiceWakePreferences.enabledKey) private var voiceWakeEnabled: Bool = false

    let openChat: () -> Void
    let openOverview: () -> Void
    let openAccount: () -> Void
    let openSettings: () -> Void

    var body: some View {
        SeriesPageContainer(
            title: "首页",
            breadcrumb: nil,
            centerLabel: self.gatewayLabel,
            primaryAction: .init(icon: "plus", action: self.openChat),
            secondaryAction: .init(icon: "list.bullet", action: self.openOverview))
        {
            VStack(spacing: 20) {
                SeriesHeroCard(
                    accent: self.appModel.seamColor,
                    icon: "bubble.left.and.bubble.right",
                    eyebrow: self.isConnected ? "会话已就绪" : "准备开始",
                    title: self.heroTitle,
                    subtitle: self.heroSubtitle)

                LazyVGrid(columns: Self.gridColumns, spacing: 14) {
                    SeriesActionCard(
                        title: "进入对话",
                        subtitle: self.isConnected ? "继续当前会话" : "连接后开始",
                        icon: "bubble.left",
                        tint: self.appModel.seamColor,
                        action: self.openChat)
                    SeriesActionCard(
                        title: "状态总览",
                        subtitle: self.isConnected ? "查看监控和使用状态" : "查看可用节点",
                        icon: "waveform.path.ecg",
                        tint: .mint,
                        action: self.openOverview)
                    SeriesActionCard(
                        title: "账号登录",
                        subtitle: "统一账户入口",
                        icon: "person.crop.circle",
                        tint: .indigo,
                        action: self.openAccount)
                    SeriesActionCard(
                        title: "设置",
                        subtitle: "偏好与高级配置",
                        icon: "gearshape",
                        tint: .orange,
                        action: self.openSettings)
                }

                SeriesSection(title: "当前状态") {
                    VStack(spacing: 12) {
                        SeriesMetricRow(title: "连接状态", value: self.appModel.gatewayStatusText)
                        SeriesMetricRow(title: "默认代理", value: self.appModel.activeAgentName)
                        SeriesMetricRow(
                            title: "语音唤醒",
                            value: self.voiceWakeEnabled ? self.voiceWake.statusText : "已关闭")
                    }
                }
            }
        }
    }

    private static let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var isConnected: Bool {
        self.appModel.gatewayServerName != nil
    }

    private var heroTitle: String {
        if self.isConnected {
            return self.appModel.gatewayServerName ?? "已连接"
        }
        return "开始连接"
    }

    private var heroSubtitle: String {
        if self.isConnected {
            return self.appModel.gatewayRemoteAddress ?? self.appModel.gatewayStatusText
        }
        return "在总览页连接网关后，即可使用对话和监控能力。"
    }

    private var gatewayLabel: String {
        let label = (self.appModel.gatewayServerName ?? "未连接").trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? "未连接" : label
    }
}

private struct MonitoringOverviewTab: View {
    @Environment(NodeAppModel.self) private var appModel
    @Environment(GatewayConnectionController.self) private var gatewayController

    @State private var connectingGatewayID: String?

    let openChat: () -> Void
    let openSettings: () -> Void

    var body: some View {
        SeriesPageContainer(
            title: "总览",
            breadcrumb: "首页",
            centerLabel: self.gatewayLabel,
            primaryAction: .init(icon: "plus", action: self.openChat),
            secondaryAction: .init(icon: "gearshape", action: self.openSettings))
        {
            VStack(spacing: 20) {
                SeriesHeroCard(
                    accent: self.statusTint,
                    icon: self.statusIcon,
                    eyebrow: "运行状态",
                    title: self.statusTitle,
                    subtitle: self.statusSubtitle)

                SeriesSection(title: "监控概览") {
                    VStack(spacing: 12) {
                        SeriesMetricRow(title: "网关状态", value: self.appModel.gatewayStatusText)
                        SeriesMetricRow(title: "当前地址", value: self.appModel.gatewayRemoteAddress ?? "未分配")
                        SeriesMetricRow(title: "可用代理", value: "\(self.appModel.gatewayAgents.count)")
                        SeriesMetricRow(title: "已发现节点", value: "\(self.gatewayController.gateways.count)")
                    }
                }

                SeriesSection(title: "快速操作") {
                    VStack(spacing: 12) {
                        SeriesPrimaryButton(
                            title: self.appModel.gatewayServerName == nil ? "连接最近节点" : "重新发现节点",
                            tint: self.appModel.seamColor)
                        {
                            if self.appModel.gatewayServerName == nil {
                                Task { await self.gatewayController.connectLastKnown() }
                            } else {
                                self.gatewayController.restartDiscovery()
                            }
                        }

                        Button("打开高级连接设置") {
                            self.openSettings()
                        }
                        .font(.headline)
                        .foregroundStyle(.primary)
                    }
                }

                if !self.gatewayController.gateways.isEmpty {
                    SeriesSection(title: "已发现节点") {
                        VStack(spacing: 12) {
                            ForEach(self.gatewayController.gateways.prefix(4)) { gateway in
                                SeriesGatewayRow(
                                    gateway: gateway,
                                    isCurrent: gateway.stableID == self.appModel.connectedGatewayID,
                                    isConnecting: self.connectingGatewayID == gateway.stableID)
                                {
                                    self.connectingGatewayID = gateway.stableID
                                    Task {
                                        await self.gatewayController.connect(gateway)
                                        await MainActor.run {
                                            if self.connectingGatewayID == gateway.stableID {
                                                self.connectingGatewayID = nil
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var gatewayLabel: String {
        let label = (self.appModel.gatewayServerName ?? "监控").trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? "监控" : label
    }

    private var statusTitle: String {
        self.appModel.gatewayServerName ?? "当前离线"
    }

    private var statusSubtitle: String {
        self.appModel.gatewayRemoteAddress ?? self.appModel.gatewayStatusText
    }

    private var statusTint: Color {
        switch GatewayStatusBuilder.build(appModel: self.appModel) {
        case .connected: .green
        case .connecting: .yellow
        case .error: .red
        case .disconnected: .gray
        }
    }

    private var statusIcon: String {
        switch GatewayStatusBuilder.build(appModel: self.appModel) {
        case .connected: "waveform.path.ecg"
        case .connecting: "dot.radiowaves.left.and.right"
        case .error: "exclamationmark.triangle"
        case .disconnected: "bolt.slash"
        }
    }
}

private struct AccountLoginTab: View {
    private enum LoginPhase {
        case idle
        case submitting
        case unavailable
    }

    @AppStorage("accounts.serviceURL") private var serviceURL: String = "https://accounts.svc.plus"
    @AppStorage("accounts.username") private var username: String = ""
    @State private var password: String = ""
    @State private var phase: LoginPhase = .idle
    @State private var feedbackText: String = "请先登录"

    let openChat: () -> Void
    let openOverview: () -> Void

    var body: some View {
        SeriesPageContainer(
            title: "账号登录",
            breadcrumb: "首页",
            centerLabel: "账号",
            primaryAction: .init(icon: "plus", action: self.openChat),
            secondaryAction: .init(icon: "list.bullet", action: self.openOverview))
        {
            VStack(spacing: 22) {
                VStack(spacing: 16) {
                    Image(systemName: "cloud")
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(.indigo)

                    Text("账号登录")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(self.feedbackText)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)

                SeriesInputField(title: "服务地址", text: self.$serviceURL, systemImage: "server.rack")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                SeriesInputField(title: "邮箱或账号", text: self.$username, systemImage: "person")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SeriesSecureInputField(title: "密码", text: self.$password, systemImage: "lock")

                SeriesPrimaryButton(
                    title: self.phase == .submitting ? "登录中…" : "登录",
                    tint: .indigo,
                    disabled: self.phase == .submitting || self.username.isEmpty || self.password.isEmpty)
                {
                    self.submit()
                }

                if self.phase == .unavailable {
                    Text("当前版本先保留统一登录入口，服务端认证将在后续版本接入。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
        }
    }

    private func submit() {
        self.phase = .submitting
        self.feedbackText = "正在校验账户…"

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                self.phase = .unavailable
                self.feedbackText = "请先登录"
            }
        }
    }
}

private struct SeriesHeaderAction {
    let icon: String
    let action: () -> Void
}

private struct SeriesPageContainer<Content: View>: View {
    let title: String
    let breadcrumb: String?
    let centerLabel: String
    let primaryAction: SeriesHeaderAction
    let secondaryAction: SeriesHeaderAction
    let content: Content

    init(
        title: String,
        breadcrumb: String?,
        centerLabel: String,
        primaryAction: SeriesHeaderAction,
        secondaryAction: SeriesHeaderAction,
        @ViewBuilder content: () -> Content)
    {
        self.title = title
        self.breadcrumb = breadcrumb
        self.centerLabel = centerLabel
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SeriesHeader(
                        title: self.title,
                        breadcrumb: self.breadcrumb,
                        centerLabel: self.centerLabel,
                        primaryAction: self.primaryAction,
                        secondaryAction: self.secondaryAction)
                        .padding(.bottom, 28)

                    self.content
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(SeriesPalette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct SeriesHeader: View {
    let title: String
    let breadcrumb: String?
    let centerLabel: String
    let primaryAction: SeriesHeaderAction
    let secondaryAction: SeriesHeaderAction

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let breadcrumb {
                        HStack(spacing: 8) {
                            Text(breadcrumb)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                            Text(self.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    } else {
                        Text(self.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                Text(self.centerLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                SeriesActionCapsule(primaryAction: self.primaryAction, secondaryAction: self.secondaryAction)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct SeriesActionCapsule: View {
    let primaryAction: SeriesHeaderAction
    let secondaryAction: SeriesHeaderAction

    var body: some View {
        HStack(spacing: 0) {
            Button(action: self.primaryAction.action) {
                Image(systemName: self.primaryAction.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 54, height: 54)
            }

            Button(action: self.secondaryAction.action) {
                Image(systemName: self.secondaryAction.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 54, height: 54)
            }
        }
        .foregroundStyle(.white)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [SeriesPalette.actionStart, SeriesPalette.actionEnd],
                        startPoint: .leading,
                        endPoint: .trailing))
        )
        .shadow(color: SeriesPalette.actionEnd.opacity(0.24), radius: 14, y: 8)
    }
}

private struct SeriesHeroCard: View {
    let accent: Color
    let icon: String
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(self.accent.opacity(0.12))
                    .frame(width: 82, height: 82)

                Image(systemName: self.icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(self.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(self.eyebrow)
                    .font(.headline)
                    .foregroundStyle(self.accent)
                Text(self.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(self.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            self.accent.opacity(0.18),
                            SeriesPalette.surface,
                            SeriesPalette.surface,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(SeriesPalette.stroke, lineWidth: 1)
        }
    }
}

private struct SeriesActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(self.tint.opacity(0.12))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: self.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(self.tint)
                    }

                Spacer(minLength: 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text(self.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(self.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(SeriesPalette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(SeriesPalette.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SeriesSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(self.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 0) {
                self.content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(SeriesPalette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(SeriesPalette.stroke, lineWidth: 1)
            }
        }
    }
}

private struct SeriesMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(self.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(self.value)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SeriesGatewayRow: View {
    let gateway: GatewayDiscoveryModel.DiscoveredGateway
    let isCurrent: Bool
    let isConnecting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SeriesPalette.accentSoft)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "server.rack")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.indigo)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(self.gateway.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if self.isCurrent {
                            Text("当前")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule(style: .continuous).fill(SeriesPalette.accentSoft))
                        }
                    }
                    Text(self.gateway.tailnetDns ?? self.gateway.lanHost ?? self.gateway.debugID)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if self.isConnecting {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct SeriesInputField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(self.title)
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Image(systemName: self.systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("", text: self.$text)
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(SeriesPalette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(SeriesPalette.strokeStrong, lineWidth: 1.5)
            }
        }
    }
}

private struct SeriesSecureInputField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(self.title)
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Image(systemName: self.systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                SecureField("", text: self.$text)
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(SeriesPalette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(SeriesPalette.strokeStrong, lineWidth: 1.5)
            }
        }
    }
}

private struct SeriesPrimaryButton: View {
    let title: String
    let tint: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Text(self.title)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(self.tint.opacity(self.disabled ? 0.45 : 0.95))
                )
        }
        .buttonStyle(.plain)
        .disabled(self.disabled)
    }
}

private enum SeriesPalette {
    static let canvas = Color(red: 0.96, green: 0.94, blue: 0.97)
    static let surface = Color.white.opacity(0.88)
    static let stroke = Color(red: 0.84, green: 0.82, blue: 0.90)
    static let strokeStrong = Color(red: 0.55, green: 0.53, blue: 0.60)
    static let accentSoft = Color(red: 0.88, green: 0.84, blue: 0.96)
    static let actionStart = Color(red: 0.43, green: 0.58, blue: 1.0)
    static let actionEnd = Color(red: 0.40, green: 0.34, blue: 0.96)
}
