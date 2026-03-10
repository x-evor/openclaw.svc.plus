import AppKit
import Observation
import OpenClawChatUI
import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case home
    case nodes
    case account
    case settings
    case help
    case about

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .home: "首页"
        case .nodes: "节点"
        case .account: "账号登录"
        case .settings: "设置"
        case .help: "帮助"
        case .about: "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .nodes: "link"
        case .account: "person.crop.circle.fill"
        case .settings: "gearshape.fill"
        case .help: "questionmark.circle.fill"
        case .about: "info.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .home: "默认工作台"
        case .nodes: "查看节点和连接状态"
        case .account: "管理账号与同步"
        case .settings: "偏好与本地能力"
        case .help: "文档与快速引导"
        case .about: "版本与构建信息"
        }
    }
}

enum WorkspaceInspectorPane: String, CaseIterable, Identifiable {
    case product
    case files
    case changes
    case preview

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .product: "产品"
        case .files: "全部文件"
        case .changes: "变更"
        case .preview: "预览"
        }
    }

    var systemImage: String {
        switch self {
        case .product: "doc.plaintext"
        case .files: "folder"
        case .changes: "chevron.left.chevron.right"
        case .preview: "globe"
        }
    }
}

@MainActor
struct MacWorkspaceView: View {
    @Bindable var state: AppState
    @State private var selectedSection: WorkspaceSection = .home
    @State private var selectedInspector: WorkspaceInspectorPane = .preview
    @State private var homeChatModel: OpenClawChatViewModel

    let updater: UpdaterProviding?
    private let initialSessionKey: String

    init(
        initialSessionKey: String,
        state: AppState = AppStateStore.shared,
        updater: UpdaterProviding? = nil,
        transport: any OpenClawChatTransport = MacGatewayChatTransport())
    {
        self.state = state
        self.updater = updater
        self.initialSessionKey = initialSessionKey
        self._homeChatModel = State(
            initialValue: OpenClawChatViewModel(sessionKey: initialSessionKey, transport: transport))
    }

    var body: some View {
        HStack(spacing: 0) {
            self.sidebar
            Divider()
            self.contentColumn
            Divider()
            self.inspectorColumn
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension MacWorkspaceView {
    private var sidebar: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer(minLength: 20)

            ForEach(WorkspaceSection.allCases) { section in
                self.sidebarButton(section)
            }

            Spacer(minLength: 20)
        }
        .frame(width: 128, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sidebarButton(_ section: WorkspaceSection) -> some View {
        let isSelected = self.selectedSection == section
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                self.selectedSection = section
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(isSelected ? self.sidebarSelectionColor : Color.clear)
                        .frame(width: 88, height: 48)

                    Image(systemName: section.systemImage)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(isSelected ? self.sidebarSelectionForeground : Color.primary.opacity(0.72))
                }

                Text(section.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 96)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var contentColumn: some View {
        VStack(spacing: 0) {
            self.contentHeader
            Divider()
            self.contentBody
        }
        .frame(minWidth: 780, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var contentHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.selectedSection.title)
                    .font(.system(size: 28, weight: .semibold))
                Text(self.selectedSection.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if self.selectedSection == .home {
                Text(self.windowPrompt)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor)))
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private var contentBody: some View {
        switch self.selectedSection {
        case .home:
            OpenClawChatView(
                viewModel: self.homeChatModel,
                showsSessionSwitcher: true,
                userAccent: self.sidebarSelectionForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .nodes:
            InstancesSettings()
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .account:
            AccountSettings(state: self.state)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .settings:
            GeneralSettings(state: self.state)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .help:
            WorkspaceHelpView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        case .about:
            AboutSettings(updater: self.updater)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var inspectorColumn: some View {
        VStack(spacing: 0) {
            self.inspectorHeader
            Divider()
            self.inspectorBody
        }
        .frame(width: 360, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var inspectorHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(WorkspaceInspectorPane.allCases) { pane in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            self.selectedInspector = pane
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: pane.systemImage)
                                .font(.system(size: 14, weight: .medium))
                            Text(pane.title)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(self.selectedInspector == pane ? Color.primary.opacity(0.08) : Color.clear))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                TextField("搜索或输入网址", text: .constant(""))
                    .textFieldStyle(.plain)
                Button {} label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var inspectorBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            self.inspectorCard(
                title: self.selectedInspector.title,
                subtitle: self.inspectorSubtitle)
            {
                ForEach(self.inspectorRows, id: \.title) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .font(.body)
                    }
                    if row.title != self.inspectorRows.last?.title {
                        Divider()
                    }
                }
            }

            self.inspectorCard(title: "状态", subtitle: "当前桌面工作台概览") {
                self.statusLine("连接模式", value: self.connectionModeLabel)
                Divider()
                self.statusLine("账号", value: self.state.authStatus.statusLabel)
                Divider()
                self.statusLine("工作会话", value: self.initialSessionKey)
                Divider()
                self.statusLine("Dock", value: self.state.showDockIcon ? "显示" : "自动")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private func inspectorCard(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor)))
    }

    private func statusLine(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.callout)
                .multilineTextAlignment(.trailing)
        }
    }

    private var sidebarSelectionColor: Color {
        (ColorHexSupport.color(fromHex: self.state.seamColorHex) ?? .accentColor).opacity(0.18)
    }

    private var sidebarSelectionForeground: Color {
        ColorHexSupport.color(fromHex: self.state.seamColorHex) ?? .accentColor
    }

    private var windowPrompt: String {
        switch self.state.connectionMode {
        case .local:
            "已连接本地 XWorkmate"
        case .remote:
            "已连接远端 XWorkmate"
        case .unconfigured:
            "请先连接你的 XWorkmate 网关"
        }
    }

    private var connectionModeLabel: String {
        switch self.state.connectionMode {
        case .local: "本地"
        case .remote: "远端"
        case .unconfigured: "未配置"
        }
    }

    private var inspectorSubtitle: String {
        switch self.selectedInspector {
        case .product: "当前工作区摘要"
        case .files: "文件与资源入口"
        case .changes: "最近活动与变更"
        case .preview: "上下文与预览面板"
        }
    }

    private var inspectorRows: [(title: String, value: String)] {
        switch self.selectedInspector {
        case .product:
            [
                ("当前页面", self.selectedSection.title),
                ("定位", self.selectedSection.subtitle),
                ("产品名", "XWorkmate"),
            ]
        case .files:
            [
                ("工作区", AgentWorkspace.defaultTemplate()),
                ("会话", self.initialSessionKey),
                ("节点模式", self.connectionModeLabel),
            ]
        case .changes:
            [
                ("最近操作", "启动进入三栏工作台"),
                ("导航", self.selectedSection.title),
                ("账号状态", self.state.authStatus.statusLabel),
            ]
        case .preview:
            [
                ("预览状态", "暂无预览链接"),
                ("提示", "右侧预览区已保留，后续可继续接入文件和网页预览"),
                ("当前窗口", "XWorkmate"),
            ]
        }
    }
}

private struct WorkspaceHelpView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                Text("帮助")
                    .font(.largeTitle.weight(.semibold))

                Text("从这里快速进入文档、重新运行引导，或者直接打开项目主页。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                self.helpCard(
                    title: "快速开始",
                    subtitle: "重新打开首次引导或进入文档站点。")
                {
                    Button("重新运行引导") {
                        OnboardingController.shared.restart()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("打开 GitHub") {
                        if let url = URL(string: "https://github.com/openclaw/openclaw") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                self.helpCard(
                    title: "连接建议",
                    subtitle: "本地模式适合直接把这台 Mac 当作网关；远端模式适合连接已有主机。")
                {
                    Text("如果你刚启动 XWorkmate，优先检查“节点”页里的连接状态，再决定是否登录账号。")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func helpCard(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
    }
}
