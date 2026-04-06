import SwiftUI

/// Tap-to-edit overlay for a single field on the contact card.
///
/// Replaces the field's display text with a `TextField` in-place, using
/// the same position and size. The keyboard type adapts to the field category
/// (email keyboard for emails, phone pad for phones, default otherwise).
///
/// - Tap away or press Return to save.
/// - Press Escape to cancel.
struct InlineFieldEditor: View {

    // MARK: - Configuration

    let initialValue: String
    let fieldCategory: ContactFieldCategory
    let onSave: (String) -> Void
    let onCancel: () -> Void

    // MARK: - State

    @State private var editedValue: String
    @State private var isHighlighted = false
    @State private var showSaveFlash = false
    @FocusState private var isFocused: Bool

    // MARK: - Init

    init(
        initialValue: String,
        fieldCategory: ContactFieldCategory,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialValue = initialValue
        self.fieldCategory = fieldCategory
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedValue = State(initialValue: initialValue)
    }

    // MARK: - Body

    var body: some View {
        TextField("", text: $editedValue)
            .font(.kBody)
            .foregroundStyle(Color.textPrimary)
            .keyboardType(keyboardType)
            .autocorrectionDisabled(shouldDisableAutocorrection)
            .textInputAutocapitalization(autocapitalization)
            .focused($isFocused)
            .padding(.horizontal, KSpacing.s)
            .padding(.vertical, KSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: KRadius.m)
                    .fill(showSaveFlash ? Color.green.opacity(0.15) : Color.accentSubtle)
                    .opacity(isHighlighted || showSaveFlash ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: showSaveFlash)
            )
            .onAppear {
                isFocused = true
                withAnimation(.easeOut(duration: 0.15)) {
                    isHighlighted = true
                }
            }
            .onSubmit {
                save()
            }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
            .onChange(of: isFocused) { _, newValue in
                if !newValue {
                    save()
                }
            }
    }

    // MARK: - Helpers

    private var keyboardType: UIKeyboardType {
        switch fieldCategory {
        case .email:
            return .emailAddress
        case .phone:
            return .phonePad
        case .url:
            return .URL
        default:
            return .default
        }
    }

    private var shouldDisableAutocorrection: Bool {
        switch fieldCategory {
        case .email, .phone, .url:
            return true
        default:
            return false
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch fieldCategory {
        case .email, .url:
            return .never
        default:
            return .sentences
        }
    }

    private func save() {
        let trimmed = editedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        HapticManager.success()
        showSaveFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showSaveFlash = false
        }
        onSave(trimmed)
    }
}
