import SwiftUI

/// Live preview of parsed contact fields with confidence-based styling.
///
/// Shows each non-empty field from a `ParsedContact` with its label and value,
/// styled according to confidence level. Fields animate in with an opacity +
/// stagger effect. Each field is tappable to manually correct its value.
struct ParsePreviewView: View {
    let parsedContact: ParsedContact
    let usedAI: Bool

    /// Tracks which field is currently being edited inline.
    @State private var editingField: EditableField?
    @State private var editText: String = ""
    @State private var visibleFieldCount: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Callback when the user manually corrects a field.
    var onFieldCorrected: ((EditableField, String) -> Void)?

    var body: some View {
        let fields = buildDisplayFields()

        VStack(alignment: .leading, spacing: KSpacing.l) {
            if usedAI {
                AISparkleIndicator()
            }

            if fields.isEmpty {
                hintView
            } else {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    fieldRow(field, index: index)
                }
            }
        }
        .onChange(of: fields.count) { _, newCount in
            animateFieldsIn(count: newCount)
        }
        .onAppear {
            animateFieldsIn(count: fields.count)
        }
    }

    // MARK: - Hint View

    private var hintView: some View {
        Text("Type or paste contact info above to see a preview")
            .font(.label)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Field Row

    @ViewBuilder
    private func fieldRow(_ field: DisplayField, index: Int) -> some View {
        VStack(alignment: .leading, spacing: KSpacing.xs) {
            Text(field.label)
                .font(.label)
                .foregroundStyle(Color.textTertiary)

            if editingField == field.editableField {
                inlineEditor(for: field)
            } else {
                fieldValue(field)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        beginEditing(field)
                    }
            }
        }
        .padding(.horizontal, KSpacing.s)
        .padding(.vertical, KSpacing.xs)
        .background(backgroundForConfidence(field.confidence))
        .clipShape(RoundedRectangle(cornerRadius: KRadius.s))
        .opacity(index < visibleFieldCount ? 1 : 0)
        .animation(
            reduceMotion
                ? .default
                : .easeOut(duration: 0.2).delay(Double(index) * 0.05),
            value: visibleFieldCount
        )
    }

    @ViewBuilder
    private func fieldValue(_ field: DisplayField) -> some View {
        Text(field.value)
            .font(.kBody)
            .foregroundStyle(foregroundForConfidence(field.confidence))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func inlineEditor(for field: DisplayField) -> some View {
        HStack(spacing: KSpacing.s) {
            TextField(field.label, text: $editText)
                .font(.kBody)
                .textFieldStyle(.plain)
                .onSubmit {
                    commitEdit(for: field)
                }

            Button {
                commitEdit(for: field)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentSlateBlue)
                    .font(.system(size: 20, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Confidence Styling

    private func foregroundForConfidence(_ confidence: FieldConfidence) -> Color {
        switch confidence {
        case .high:
            return .textPrimary
        case .medium:
            return .textPrimary
        case .low:
            return .accentSlateBlue
        }
    }

    private func backgroundForConfidence(_ confidence: FieldConfidence) -> Color {
        switch confidence {
        case .high:
            return .clear
        case .medium:
            return .accentSubtle
        case .low:
            return .accentSubtle
        }
    }

    // MARK: - Inline Editing

    private func beginEditing(_ field: DisplayField) {
        editingField = field.editableField
        editText = field.value
    }

    private func commitEdit(for field: DisplayField) {
        let correctedValue = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !correctedValue.isEmpty {
            onFieldCorrected?(field.editableField, correctedValue)
        }
        editingField = nil
        editText = ""
    }

    // MARK: - Field Animation

    private func animateFieldsIn(count: Int) {
        visibleFieldCount = 0
        withAnimation {
            visibleFieldCount = count
        }
    }

    // MARK: - Display Field Model

    private func buildDisplayFields() -> [DisplayField] {
        var fields: [DisplayField] = []

        if !parsedContact.namePrefix.value.isEmpty {
            fields.append(DisplayField(
                label: "prefix",
                value: parsedContact.namePrefix.value,
                confidence: parsedContact.namePrefix.confidence,
                editableField: .namePrefix
            ))
        }

        if !parsedContact.givenName.value.isEmpty {
            fields.append(DisplayField(
                label: "first name",
                value: parsedContact.givenName.value,
                confidence: parsedContact.givenName.confidence,
                editableField: .givenName
            ))
        }

        if !parsedContact.familyName.value.isEmpty {
            fields.append(DisplayField(
                label: "last name",
                value: parsedContact.familyName.value,
                confidence: parsedContact.familyName.confidence,
                editableField: .familyName
            ))
        }

        if !parsedContact.jobTitle.value.isEmpty {
            fields.append(DisplayField(
                label: "job title",
                value: parsedContact.jobTitle.value,
                confidence: parsedContact.jobTitle.confidence,
                editableField: .jobTitle
            ))
        }

        if !parsedContact.organization.value.isEmpty {
            fields.append(DisplayField(
                label: "company",
                value: parsedContact.organization.value,
                confidence: parsedContact.organization.confidence,
                editableField: .organization
            ))
        }

        if let address = parsedContact.address {
            if !address.street.value.isEmpty {
                fields.append(DisplayField(label: "street", value: address.street.value,
                                            confidence: address.street.confidence, editableField: .street))
            }
            if !address.city.value.isEmpty {
                fields.append(DisplayField(label: "city", value: address.city.value,
                                            confidence: address.city.confidence, editableField: .city))
            }
            if !address.state.value.isEmpty {
                fields.append(DisplayField(label: "state", value: address.state.value,
                                            confidence: address.state.confidence, editableField: .state))
            }
            if !address.postalCode.value.isEmpty {
                fields.append(DisplayField(label: "zip", value: address.postalCode.value,
                                            confidence: address.postalCode.confidence, editableField: .postalCode))
            }
        }

        for (index, phone) in parsedContact.phoneNumbers.enumerated() where !phone.value.isEmpty {
            fields.append(DisplayField(
                label: "phone",
                value: phone.value,
                confidence: phone.confidence,
                editableField: .phone(index)
            ))
        }

        for (index, email) in parsedContact.emailAddresses.enumerated() where !email.value.isEmpty {
            fields.append(DisplayField(
                label: "email",
                value: email.value,
                confidence: email.confidence,
                editableField: .email(index)
            ))
        }

        return fields
    }
}

// MARK: - Supporting Types

/// Identifies which field is being edited for correction.
enum EditableField: Equatable {
    case namePrefix
    case givenName
    case familyName
    case jobTitle
    case organization
    case street
    case city
    case state
    case postalCode
    case phone(Int)
    case email(Int)
}

/// A display-ready representation of a single parsed field.
private struct DisplayField: Identifiable {
    let label: String
    let value: String
    let confidence: FieldConfidence
    let editableField: EditableField

    var id: String {
        "\(editableField)-\(label)-\(value)"
    }
}
