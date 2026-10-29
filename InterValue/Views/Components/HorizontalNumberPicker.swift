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
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let translation = pan.translation(in: pan.view).x
        switch pan.state {
        case .changed:
            onChanged(translation)
        case .ended, .cancelled:
            onEnded(translation, pan.velocity(in: pan.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y)
        }
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

    @State private var dragOffset: CGFloat = 0
    @State private var isEditing = false
    @State private var inputText = ""

    private var values: [Int] { Array(range) }

    var body: some View {
        VStack(spacing: 2) {
            if isEditing {
                NumberTextField(text: $inputText, onCommit: commitInput)
                    .frame(height: itemHeight)
            } else {
                GeometryReader { geo in
                    let containerWidth = geo.size.width
                    let selectedIndex = values.firstIndex(of: selectedValue) ?? 0
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
                                    if value == selectedValue {
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
                            onChanged: { dragOffset = $0 },
                            onEnded: { translation, velocity in
                                // Blend in a fraction of release velocity for natural feel
                                let totalOffset = translation + velocity * 0.1
                                let indexDelta = Int((-totalOffset / itemWidth).rounded())
                                let clampedIndex = max(0, min(values.count - 1, selectedIndex + indexDelta))
                                let newValue = values[clampedIndex]
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                    dragOffset = 0
                                    selectedValue = newValue
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
