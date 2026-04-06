import SwiftUI

/// The headline feature for address entry: a single multiline text field
/// that parses freeform address text into structured fields via AI or regex.
///
/// After a 0.3s debounce, the parser runs and a labeled preview of the
/// parsed result appears below the input. Each field is styled according
/// to its confidence level and is tappable to manually correct.
///
/// A "Edit fields individually" link switches to structured mode with
/// four separate TextFields for street, city, state, and zip.
struct FreeformAddressInput: View {

    // MARK: - Configuration

    let initialText: String?
    let onSave: (ParsedAddress) -> Void
    let onCancel: () -> Void

    // MARK: - State

    @State private var freeformText: String
    @State private var parsedAddress: ParsedAddress?
    @State private var usedAI: Bool = false
    @State private var isParsing: Bool = false
    @State private var isStructuredMode: Bool = false
    @State private var visibleFieldCount: Int = 0
    @State private var editingField: AddressField?

    // Structured mode fields
    @State private var streetText: String = ""
    @State private var cityText: String = ""
    @State private var stateText: String = ""
    @State private var zipText: String = ""

    // Inline correction
    @State private var correctionText: String = ""
    @FocusState private var correctionFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Debounce
    @State private var debounceTask: Task<Void, Never>?

    private let parser = AddressParser()

    // MARK: - Types

    enum AddressField: Hashable {
        case street, city, state, zip
    }

    // MARK: - Init

    init(
        initialText: String? = nil,
        onSave: @escaping (ParsedAddress) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialText = initialText
        self.onSave = onSave
        self.onCancel = onCancel
        self._freeformText = State(initialValue: initialText ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KSpacing.xl) {
                    if isStructuredMode {
                        structuredModeContent
                    } else {
                        freeformModeContent
                    }
                }
                .padding(.horizontal, KSpacing.l)
                .padding(.top, KSpacing.l)
            }
            .navigationTitle("Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAddress()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Freeform Mode

    @ViewBuilder
    private var freeformModeContent: some View {
        VStack(alignment: .leading, spacing: KSpacing.s) {
            Text("ADDRESS")
                .font(.labelCaps)
                .tracking(0.5)
                .foregroundStyle(Color.textTertiary)

            TextEditor(text: $freeformText)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .frame(minHeight: 72)
                .scrollContentBackground(.hidden)
                .padding(KSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: KRadius.m)
                        .fill(Color.surfaceBackground)
                )
                .onChange(of: freeformText) { _, newValue in
                    debounceParse(newValue)
                }
        }

        if isParsing {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        }

        if let parsed = parsedAddress {
            parsedPreview(parsed)
        }
    }

    // MARK: - Parsed Result Preview

    @ViewBuilder
    private func parsedPreview(_ parsed: ParsedAddress) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.m) {
            HStack {
                Text("PARSED RESULT")
                    .font(.labelCaps)
                    .tracking(0.5)
                    .foregroundStyle(Color.textTertiary)

                Spacer()

                if usedAI {
                    AISparkleIndicator()
                }
            }

            parsedFieldRow(
                label: "street",
                field: parsed.street,
                addressField: .street,
                index: 0
            )

            parsedFieldRow(
                label: "city",
                field: parsed.city,
                addressField: .city,
                index: 1
            )

            parsedFieldRow(
                label: "state",
                field: parsed.state,
                addressField: .state,
                index: 2
            )

            parsedFieldRow(
                label: "zip",
                field: parsed.postalCode,
                addressField: .zip,
                index: 3
            )

            Divider()
                .padding(.vertical, KSpacing.s)

            Button {
                switchToStructuredMode(from: parsed)
            } label: {
                HStack {
                    Text("Edit fields individually")
                        .font(.kBody)
                        .foregroundStyle(Color.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
    }

    // MARK: - Parsed Field Row

    @ViewBuilder
    private func parsedFieldRow(
        label: String,
        field: ParsedAddressField,
        addressField: AddressField,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            HStack(spacing: KSpacing.xs) {
                Text(label)
                    .font(.label)
                    .foregroundStyle(Color.textTertiary)

                if field.confidence == .low {
                    Text("?")
                        .font(.label)
                        .foregroundStyle(Color.accentSlateBlue)
                }
            }

            if editingField == addressField {
                inlineCorrectionField(for: addressField, currentValue: field.value)
            } else {
                Text(field.value.isEmpty ? "--" : field.value)
                    .font(.kBody)
                    .foregroundStyle(fieldTextColor(for: field.confidence))
                    .padding(.horizontal, fieldHasBackground(field.confidence) ? KSpacing.xs : 0)
                    .padding(.vertical, fieldHasBackground(field.confidence) ? 2 : 0)
                    .background(
                        fieldHasBackground(field.confidence)
                            ? RoundedRectangle(cornerRadius: KRadius.s)
                                .fill(Color.accentSubtle)
                            : nil
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        correctionText = field.value
                        editingField = addressField
                        correctionFocused = true
                    }
            }
        }
        .opacity(index < visibleFieldCount ? 1 : 0)
        .animation(
            reduceMotion
                ? .default
                : .easeOut(duration: 0.2).delay(Double(index) * 0.05),
            value: visibleFieldCount
        )
    }

    // MARK: - Inline Correction

    @ViewBuilder
    private func inlineCorrectionField(for field: AddressField, currentValue: String) -> some View {
        TextField(fieldPlaceholder(for: field), text: $correctionText)
            .font(.kBody)
            .foregroundStyle(Color.textPrimary)
            .focused($correctionFocused)
            .padding(.horizontal, KSpacing.s)
            .padding(.vertical, KSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: KRadius.s)
                    .fill(Color.accentSubtle)
            )
            .onSubmit {
                applyCorrection(to: field)
            }
            .onChange(of: correctionFocused) { _, focused in
                if !focused {
                    applyCorrection(to: field)
                }
            }
    }

    // MARK: - Structured Mode

    @ViewBuilder
    private var structuredModeContent: some View {
        VStack(alignment: .leading, spacing: KSpacing.l) {
            Text("ADDRESS FIELDS")
                .font(.labelCaps)
                .tracking(0.5)
                .foregroundStyle(Color.textTertiary)

            structuredField(label: "Street", text: $streetText)
            structuredField(label: "City", text: $cityText)
            structuredField(label: "State", text: $stateText)
            structuredField(label: "ZIP", text: $zipText, keyboardType: .numbersAndPunctuation)

            Button {
                isStructuredMode = false
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.textTertiary)
                    Text("Back to freeform input")
                        .font(.kBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func structuredField(
        label: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            Text(label)
                .font(.label)
                .foregroundStyle(Color.textTertiary)

            TextField(label, text: text)
                .font(.kBody)
                .foregroundStyle(Color.textPrimary)
                .keyboardType(keyboardType)
                .padding(.horizontal, KSpacing.s)
                .padding(.vertical, KSpacing.s)
                .background(
                    RoundedRectangle(cornerRadius: KRadius.m)
                        .fill(Color.surfaceBackground)
                )
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        if isStructuredMode {
            return !streetText.isEmpty || !cityText.isEmpty || !stateText.isEmpty || !zipText.isEmpty
        }
        return parsedAddress != nil
    }

    private func fieldTextColor(for confidence: FieldConfidence) -> Color {
        switch confidence {
        case .high:
            return .textPrimary
        case .medium:
            return .textPrimary
        case .low:
            return .accentSlateBlue
        }
    }

    private func fieldHasBackground(_ confidence: FieldConfidence) -> Bool {
        confidence == .medium || confidence == .low
    }

    private func fieldPlaceholder(for field: AddressField) -> String {
        switch field {
        case .street: return "Street"
        case .city: return "City"
        case .state: return "State"
        case .zip: return "ZIP"
        }
    }

    // MARK: - Actions

    private func debounceParse(_ text: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                parsedAddress = nil
                visibleFieldCount = 0
                return
            }

            isParsing = true
            let (result, ai) = await parser.parse(trimmed)
            guard !Task.isCancelled else { return }

            isParsing = false
            parsedAddress = result
            usedAI = ai

            // Animate fields appearing with stagger
            visibleFieldCount = 0
            withAnimation {
                visibleFieldCount = 4
            }
        }
    }

    private func applyCorrection(to field: AddressField) {
        guard var parsed = parsedAddress else { return }
        let corrected = ParsedAddressField.high(correctionText)

        switch field {
        case .street: parsed.street = corrected
        case .city: parsed.city = corrected
        case .state: parsed.state = corrected
        case .zip: parsed.postalCode = corrected
        }

        parsedAddress = parsed
        editingField = nil
        correctionText = ""
    }

    private func switchToStructuredMode(from parsed: ParsedAddress) {
        streetText = parsed.street.value
        cityText = parsed.city.value
        stateText = parsed.state.value
        zipText = parsed.postalCode.value
        isStructuredMode = true
    }

    private func saveAddress() {
        let address: ParsedAddress
        if isStructuredMode {
            address = ParsedAddress(
                street: .high(streetText),
                city: .high(cityText),
                state: .high(stateText),
                postalCode: .high(zipText),
                countryCode: .high("")
            )
        } else if let parsed = parsedAddress {
            address = parsed
        } else {
            return
        }

        HapticManager.success()
        onSave(address)
    }
}
