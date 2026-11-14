import SwiftUI

struct OutputColorHeadBlock: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject var state: PanelSectionState
    @ObservedObject private var service = OutputColorService.shared
    var body: some View {
        ExpandableRow(icon: "swatchpalette", iconActive: false, label: "色彩模式",
                      subtitle: service.snapshots[display.displayID]?.current?.summary,
                      isExpanded: state.openBinding(\.outputColorOpenIDs, display.displayID))
            .task { service.reload(display.displayID) }
            .onReceive(NotificationCenter.default.publisher(for: .crispPanelDidOpen)) { _ in service.reload(display.displayID) }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in service.reload(display.displayID) }
    }
}

struct OutputColorBodyBlock: View {
    @ObservedObject var display: DisplayInfo
    @ObservedObject private var service = OutputColorService.shared
    var body: some View {
        let id = display.displayID
        let snapshot = service.snapshots[id]
        VStack(alignment: .leading, spacing: 4) {
            ForEach(snapshot?.modes ?? []) { mode in
                Button {
                    Task { await service.apply(mode, to: id) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.formatKey == snapshot?.current?.formatKey ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mode.formatKey == snapshot?.current?.formatKey ? Color.accentColor : Color.secondary)
                            .frame(width: 18)
                        Text("\(mode.depth)-bit").font(.body)
                        Spacer(minLength: 2)
                        badge(mode.hdr, tint: .green)
                        badge(mode.encoding, tint: mode.encoding == "RGB" ? .green : .orange)
                        badge(mode.range, tint: mode.range == "全范围" ? .green : .red)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(service.pendingDisplay != nil)
                .accessibilityLabel("\(mode.depth) bit，\(mode.hdr)，\(mode.encoding)，\(mode.range)")
            }
            if snapshot?.current == nil {
                Text("当前连接未提供可用的输出色彩模式。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("仅列出保持当前分辨率和刷新率的模式。切换后需确认，否则 15 秒后恢复。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let count = snapshot?.otherTimingCount, count > 0 {
                    Text("另有 \(count) 种格式需要其他刷新率。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if service.pendingDisplay == id {
                HStack {
                    Text("\(service.secondsRemaining) 秒后恢复").font(.caption)
                    Spacer()
                    Button("恢复") { service.revert() }
                    Button("保留") { service.keep() }.buttonStyle(.borderedProminent).disabled(!service.verified)
                }
            }
            if let error = service.errors[id] {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.horizontal, 10).padding(.bottom, 6)
    }
    private func badge(_ text: String, tint: Color) -> some View {
        Text(text).font(.system(size: 9)).foregroundStyle(.secondary)
            .padding(.horizontal, 3).padding(.vertical, 2)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 3))
    }
}
