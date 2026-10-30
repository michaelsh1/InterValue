import SwiftUI
import UIKit

// MARK: - UIViewRepresentable text field with a guaranteed Done toolbar

private struct NumberTextField: UIViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.textAlignment = .center
        tf.font = .systemFont(ofSize: 28, weight: .bold)
        tf.delegate = context.coordinator

        let bar = UIToolbar()
        bar.sizeToFit()
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done,
                                   target: context.coordinator,
                                   action: #selector(Coordinator.doneTapped))
        bar.items = [spacer, done]
        tf.inputAccessoryView = bar

        DispatchQueue.main.async { tf.becomeFirstResponder() }
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        if tf.text != text { tf.text = text }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NumberTextField
        init(_ parent: NumberTextField) { self.parent = parent }

        @objc func doneTapped() { parent.onCommit() }

        func textFieldDidEndEditing(_ textField: UITextField) { parent.onCommit() }

        func textField(_ tf: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            let current = tf.text ?? ""
            guard let r = Range(range, in: current) else { return false }
            let updated = current.replacingCharacters(in: r, with: string)
            let digits = updated.filter { $0.isNumber }
            guard digits.count <= 2 else { return false }
            parent.text = digits
            tf.text = digits
            return false
        }
    }
}

// MARK: - Direction-locked horizontal pan

/// A pan that only begins when the initial movement is mostly horizontal,
/// so vertical swipes fall through to the enclosing List / ScrollView.
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    /// Fires on every touch-down, before any pan is recognized.
    var onTouchDown: () -> Void
    var onBegan: () -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ pan: UIPanGestureRecognizer, context: Context) {
        context.coordinator.onTouchDown = onTouchDown
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let translation = pan.translation(in: pan.view).x
        switch pan.state {
        case .began:
            onBegan()
            onChanged(translation)
        case .changed:
            onChanged(translation)
        case .ended, .cancelled:
            onEnded(translation, pan.velocity(in: pan.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTouchDown: () -> Void = {}

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            onTouchDown()
            return true
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

// MARK: - Display-synced frame loop

/// Calls `onFrame` with the seconds elapsed since `run` on every display refresh,
/// until it returns false or `stop` is called.
private final class FrameTicker: NSObject {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0
    private var onFrame: (Double) -> Bool = { _ in false }

    var isRunning: Bool { link != nil }

    func run(_ onFrame: @escaping (Double) -> Bool) {
        stop()
        self.onFrame = onFrame
        start = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if !onFrame(link.targetTimestamp - start) { stop() }
    }
}

// MARK: - HorizontalNumberPicker

/// A horizontally scrolling number carousel with snap-to-center behavior.
/// The selected number is centered, large, bold and fully opaque;
/// numbers further from center are progressively smaller and more transparent.
/// Tap the center number to type a value directly (max 2 digits, clamped to 59).
struct HorizontalNumberPicker: View {
    let range: ClosedRange<Int>
    @Binding var selectedValue: Int
    let suffix: String

    private let itemWidth: CGFloat = 44
    private let itemHeight: CGFloat = 50
    /// Exponential velocity decay per second during a fling; higher stops sooner.
    /// 2.0 matches UIScrollView's normal deceleration rate (0.998 per ms).
    private let friction: CGFloat = 2.0

    @State private var dragOffset: CGFloat = 0
    @State private var isEditing = false
    @State private var inputText = ""
    /// Index the current drag / fling is measured from.
    @State private var origin = 0
    @State private var dragAnchor: CGFloat = 0
    @State private var ticker = FrameTicker()
    /// The last touch stopped a fling, so it shouldn't also open the editor.
    @State private var caughtFling = false

    private var values: [Int] { Array(range) }
    private var selectedIndex: Int { values.firstIndex(of: selectedValue) ?? 0 }
    /// Offsets (relative to `origin`) that put the first / last value at center.
    private var maxOffset: CGFloat { CGFloat(origin) * itemWidth }
    private var minOffset: CGFloat { -CGFloat(values.count - 1 - origin) * itemWidth }

    var body: some View {
        VStack(spacing: 2) {
            if isEditing {
                NumberTextField(text: $inputText, onCommit: commitInput)
                    .frame(height: itemHeight)
            } else {
                GeometryReader { geo in
                    let containerWidth = geo.size.width
                    // Offset so the selected item is always at the horizontal center
                    let baseOffset = containerWidth / 2 - itemWidth / 2 - CGFloat(selectedIndex) * itemWidth
                    let currentOffset = baseOffset + dragOffset

                    HStack(spacing: 0) {
                        ForEach(Array(values.enumerated()), id: \.element) { index, value in
                            let itemCenterX = currentOffset + CGFloat(index) * itemWidth + itemWidth / 2
                            let distance = abs(itemCenterX - containerWidth / 2)
                            numberItem(value: value, distance: distance)
                                .frame(width: itemWidth, height: itemHeight)
                                .onTapGesture {
                                    if value == selectedValue && !caughtFling {
                                        inputText = "\(selectedValue)"
                                        isEditing = true
                                    }
                                }
                        }
                    }
                    .offset(x: currentOffset)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        HorizontalPanGesture(
                            onTouchDown: catchFling,
                            onBegan: {
                                ticker.stop()
                                origin = selectedIndex
                                dragAnchor = dragOffset
                            },
                            onChanged: { move(to: rubberBanded(dragAnchor + $0)) },
                            onEnded: { translation, velocity in
                                fling(from: rubberBanded(dragAnchor + translation), velocity: velocity)
                            }
                        )
                    )
                }
                .frame(height: itemHeight)
            }

            Text(suffix)
                .font(.caption2)
                .fontWeight(.semibold)
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .onDisappear { ticker.stop() }
    }

    // MARK: - Motion

    /// Positions the wheel `x` points from `origin`, selecting whichever value is nearest center.
    private func move(to x: CGFloat) {
        let index = max(0, min(values.count - 1, origin - Int((x / itemWidth).rounded())))
        if index != selectedIndex {
            selectedValue = values[index]
            UISelectionFeedbackGenerator().selectionChanged()
        }
        dragOffset = x + CGFloat(index - origin) * itemWidth
    }

    /// Resists dragging past the first / last value.
    private func rubberBanded(_ x: CGFloat) -> CGFloat {
        if x > maxOffset { return maxOffset + (x - maxOffset) * 0.3 }
        if x < minOffset { return minOffset + (x - minOffset) * 0.3 }
        return x
    }

    private func fling(from x0: CGFloat, velocity v: CGFloat) {
        let k = friction
        let rest = x0 + v / k
        if x0 > maxOffset || x0 < minOffset || abs(v) < 100 {
            // Overscrolled or barely moving: spring onto the nearest value.
            let target = min(max((x0 / itemWidth).rounded() * itemWidth, minOffset), maxOffset)
            settle(from: x0, velocity: v, to: target)
        } else if rest > maxOffset || rest < minOffset {
            // Coast until the end of the range, then bounce off it.
            let edge = rest > maxOffset ? maxOffset : minOffset
            let tHit = -log(1 - (edge - x0) * k / v) / k
            let vHit = min(max(v - k * (edge - x0), -1000), 1000)
            animate(to: edge) { t in
                t < tHit
                    ? x0 + v / k * (1 - exp(-k * t))
                    : springDisplacement(0, vHit, at: t - tHit).map { edge + $0 }
            }
        } else {
            // Coast with friction, nudging the release speed so it comes to rest exactly on a value.
            let target = (rest / itemWidth).rounded() * itemWidth
            animate(to: target) { t in
                let remaining = (target - x0) * exp(-k * t)
                return abs(remaining) < 0.5 ? nil : target - remaining
            }
        }
    }

    /// A touch on a coasting wheel stops it on the nearest value; a pan that follows takes over from there.
    private func catchFling() {
        caughtFling = ticker.isRunning
        guard caughtFling else { return }
        origin = selectedIndex
        settle(from: dragOffset, velocity: 0, to: 0)
    }

    private func settle(from x0: CGFloat, velocity v: CGFloat, to target: CGFloat) {
        let v = min(max(v, -1000), 1000)
        animate(to: target) { t in springDisplacement(x0 - target, v, at: t).map { target + $0 } }
    }

    /// Damped spring displacement `t` seconds after starting `a` away at velocity `v`; nil once at rest.
    private func springDisplacement(_ a: CGFloat, _ v: CGFloat, at t: CGFloat) -> CGFloat? {
        let omega: CGFloat = 18, zeta: CGFloat = 0.7
        let omegaD = omega * sqrt(1 - zeta * zeta)
        let b = (v + zeta * omega * a) / omegaD
        let envelope = exp(-zeta * omega * t)
        guard envelope * (abs(a) + abs(b)) > 0.3 else { return nil }
        return envelope * (a * cos(omegaD * t) + b * sin(omegaD * t))
    }

    /// Drives the wheel along `position(t)` each frame until it returns nil, then lands on `final`.
    private func animate(to final: CGFloat, _ position: @escaping (CGFloat) -> CGFloat?) {
        ticker.run { t in
            guard let x = position(CGFloat(t)) else {
                move(to: final)
                return false
            }
            move(to: x)
            return true
        }
    }

    private func commitInput() {
        guard isEditing else { return }
        let parsed = Int(inputText) ?? selectedValue
        let clamped = min(max(parsed, range.lowerBound), min(range.upperBound, 59))

        selectedValue = clamped
        isEditing = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func numberItem(value: Int, distance: CGFloat) -> some View {
        // ratio: 0 = perfectly centered, 1 = at or beyond fade-out distance (2nd number)
        let ratio = min(distance / (itemWidth * 1.5), 1.0)
        let scale = 1.0 - ratio * 0.52
        let opacity = 1.0 - ratio

        Text("\(value)")
            .font(.system(size: 28, weight: ratio < 0.15 ? .bold : .regular, design: .rounded))
            .scaleEffect(scale)
            .opacity(opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    @Previewable @State var value = 30
    VStack(spacing: 24) {
        HorizontalNumberPicker(range: 0...59, selectedValue: $value, suffix: "min")
        HorizontalNumberPicker(range: 0...59, selectedValue: $value, suffix: "sec")
    }
    .padding()
    .background(Color(.systemBackground))
}
