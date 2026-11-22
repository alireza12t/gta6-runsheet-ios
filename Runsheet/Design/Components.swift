import SwiftUI

// MARK: Liquid Glass with a material fallback

extension View {
    /// Native Liquid Glass on iOS 26+, a thin material with a hairline edge before that.
    @ViewBuilder
    func rsGlass<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            // The shadow sits on its own backing shape. Shadowing the material itself renders it
            // offscreen, which shows up as a pale box around the control on iOS 18.
            self
                .background(.regularMaterial, in: shape)
                .background(tint?.opacity(0.25) ?? .clear, in: shape)
                .background { shape.fill(RS.card.opacity(0.5)).shadow(color: .black.opacity(0.14), radius: 12, y: 5) }
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func rsGlassCapsule(interactive: Bool = false) -> some View { rsGlass(in: Capsule(), interactive: interactive) }

    func rsCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RS.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A bar behind the status bar so scrolled content doesn't run under the clock.
    func rsStatusBarScrim() -> some View {
        self.safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0).background(.bar) }
    }

    /// Before iOS 26 the tab bar is clear over the map, so pins draw through it. Give it a bar there.
    @ViewBuilder
    func rsSolidTabBarBeforeGlass() -> some View {
        if #available(iOS 26, *) { self } else { self.toolbarBackground(.visible, for: .tabBar) }
    }

    /// Hide the tab bar on scroll where iOS 26 supports it.
    @ViewBuilder
    func rsMinimizeTabBar() -> some View {
        if #available(iOS 26, *) { self.tabBarMinimizeBehavior(.onScrollDown) } else { self }
    }
}

/// Small helper for the glass map controls: groups morph together on iOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content
    var body: some View {
        if #available(iOS 26, *) { GlassEffectContainer(spacing: spacing) { content } } else { content }
    }
}

// MARK: Buttons

struct RSButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(kind == .primary ? RS.onAccent : RS.text)
            .background(kind == .primary ? RS.accentFill : RS.fill2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Round icon button. Glass where available.
struct GlassIconButton: View {
    let symbol: String
    var label: String
    var tint: Color = RS.text
    var size: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .rsGlass(in: Circle(), interactive: true)
        .accessibilityLabel(label)
    }
}

// MARK: Tags

struct StatusTag: View {
    let label: String
    let status: BoardStatus
    var body: some View {
        Text(label)
            .font(.mono(10.5, .bold))
            .kerning(0.6)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7).padding(.vertical, 4)
            .foregroundStyle(status.fg)
            .background(status.bg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SourceTag: View {
    let count: Int
    var body: some View {
        Text("\(count) SOURCE\(count == 1 ? "" : "S")")
            .font(.mono(10.5, .bold))
            .kerning(0.6)
            .fixedSize()
            .padding(.horizontal, 7).padding(.vertical, 4)
            .foregroundStyle(RS.grey)
            .background(RS.greyBg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = RS.text2
    init(_ text: String, color: Color = RS.text2) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(.system(size: 12, weight: .semibold)).kerning(0.6).foregroundStyle(color)
    }
}

// MARK: Segmented control with a sliding pill

struct SegPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let title: (T) -> String
    var subtitle: ((T) -> String)? = nil
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { o in
                let on = o == selection
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.25)) { selection = o }
                } label: {
                    HStack(spacing: 2) {
                        Text(title(o)).font(.system(size: 15, weight: on ? .semibold : .medium))
                        if let subtitle { Text(subtitle(o)).font(.system(size: 11, weight: .medium)).foregroundStyle(RS.text2) }
                    }
                    .monospacedDigit()
                    .foregroundStyle(RS.text)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(RS.segOn)
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RS.fill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: Chips

struct Chip: View {
    let title: String
    var color: Color? = nil
    var count: String? = nil
    var on: Bool
    var glass = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 9, height: 9) }
                Text(title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                if let count { Text(count).font(.mono(12)).foregroundStyle(RS.text.opacity(0.7)) }
            }
            .foregroundStyle(RS.text)
            .padding(.horizontal, 12).frame(height: 34)
            .background {
                if on { Capsule().fill(RS.card); Capsule().fill(RS.accent.opacity(0.16)) }
                else if !glass || !Chip.nativeGlass { Capsule().fill(RS.card) }
            }
            .overlay(Capsule().strokeBorder(on ? RS.accent : RS.line, lineWidth: on ? 1.5 : 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(GlassIf(on: glass && !on))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    static var nativeGlass: Bool { if #available(iOS 26, *) { true } else { false } }

    /// Glass chips only with native Liquid Glass; a material inside a scroll view draws a band on iOS 18.
    private struct GlassIf: ViewModifier {
        let on: Bool
        func body(content: Content) -> some View {
            if on && Chip.nativeGlass { content.rsGlass(in: Capsule()) } else { content }
        }
    }
}

/// Wraps children onto new lines, like CSS flex-wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0; var y: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var y: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + s.width > width {
                y += rows[rows.count - 1].height + spacing
                rows.append(Row(y: y))
            }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + s.width
            r.height = max(r.height, s.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows
    }
}

// MARK: Progress

struct ProgressBar: View {
    let fraction: Double
    var height: CGFloat = 6
    var body: some View {
        let done = fraction >= 1
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(RS.fill2)
                Capsule().fill(done ? RS.green : RS.accent)
                    .frame(width: max(height, g.size.width * min(1, max(0, fraction))))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.5, bounce: 0.2), value: fraction)
    }
}

/// Flighty-style progress line: a track with a moving dot.
struct RunLine: View {
    let index: Int
    let total: Int
    var body: some View {
        let f = total == 0 ? 0 : Double(index) / Double(total)
        HStack(spacing: 10) {
            Text("\(index)").font(.mono(13, .semibold)).foregroundStyle(RS.text).contentTransition(.numericText())
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(RS.fill2).frame(height: 4)
                    Capsule().fill(RS.accent).frame(width: max(0, w * f), height: 4)
                    Circle().fill(RS.accent)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(RS.card, lineWidth: 3))
                        .offset(x: w * f - 7)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
            Text("\(total)").font(.mono(13, .semibold)).foregroundStyle(RS.text2)
        }
        .animation(.spring(duration: 0.6, bounce: 0.3), value: index)
    }
}

// MARK: Check

struct CheckButton: View {
    let on: Bool
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(on ? Color.clear : RS.fill2, lineWidth: 2)
                    .background(Circle().fill(on ? RS.accent : .clear))
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RS.onAccent)
                    .scaleEffect(on ? 1 : 0.3)
                    .opacity(on ? 1 : 0)
            }
            .frame(width: 26, height: 26)
            .animation(.spring(duration: 0.3, bounce: 0.5), value: on)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "Done" : "Not done")
    }
}

// MARK: Toast

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(RS.text)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .rsGlassCapsule()
    }
}
