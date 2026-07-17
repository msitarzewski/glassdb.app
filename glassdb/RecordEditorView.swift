//
//  RecordEditorView.swift
//  glassdb
//
//  Full-screen modal for editing a single database row.
//  Staging model: edits highlighted, batched, applied on explicit save.
//

import SwiftUI
import GlassDBKit

// MARK: - Staged Edit Model

struct StagedEdit: Identifiable {
    let id = UUID()
    let columnIndex: Int
    let columnName: String
    let columnType: String
    let isPrimaryKey: Bool
    let isNullable: Bool
    let isUnsigned: Bool
    let isGenerated: Bool
    let defaultValue: String?
    let originalValue: DatabaseValue
    var editText: String
    var isNull: Bool
    var useDefault: Bool

    var isModified: Bool {
        if isGenerated { return false }
        if useDefault { return false }
        if isNull != originalValue.isNull { return true }
        if isNull { return false }
        return editText != originalValue.displayString
    }

    var typeLower: String { columnType.lowercased() }
    var isJSON: Bool { typeLower == "json" }
    var isLargeText: Bool { typeLower.contains("text") || typeLower.contains("blob") }
    var isBool: Bool { typeLower.contains("bool") || typeLower == "tinyint" || typeLower.hasPrefix("tinyint(1)") }
    var isBinary: Bool { typeLower.contains("binary") || typeLower.contains("blob") || typeLower.hasPrefix("bit") }

    func boundValue() throws -> DatabaseValue {
        if isGenerated {
            throw RecordValueError.invalidValue(column: columnName, expected: "a server-generated value that cannot be edited")
        }
        if isNull { return .null }
        let value = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseType = typeLower.split(separator: "(", maxSplits: 1).first.map(String.init) ?? typeLower

        if isBool {
            switch value.lowercased() {
            case "1", "true": return .bool(true)
            case "0", "false": return .bool(false)
            default: throw RecordValueError.invalidValue(column: columnName, expected: "true, false, 1, or 0")
            }
        }
        if ["tinyint", "smallint", "mediumint", "int", "integer", "bigint"].contains(baseType) {
            if isUnsigned, let parsed = UInt64(value) { return .uint(parsed) }
            if !isUnsigned, let parsed = Int64(value) { return .int(parsed) }
            throw RecordValueError.invalidValue(column: columnName, expected: isUnsigned ? "an unsigned integer" : "an integer")
        }
        if ["decimal", "numeric"].contains(baseType) {
            guard Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) != nil else {
                throw RecordValueError.invalidValue(column: columnName, expected: "an exact decimal number")
            }
            return .decimal(value)
        }
        if ["float", "double", "real"].contains(baseType) {
            guard let parsed = Double(value), parsed.isFinite else {
                throw RecordValueError.invalidValue(column: columnName, expected: "a finite number")
            }
            return .double(parsed)
        }
        if baseType == "json" {
            guard (try? JSONSerialization.jsonObject(with: Data(value.utf8))) != nil else {
                throw RecordValueError.invalidValue(column: columnName, expected: "valid JSON")
            }
            return .json(value)
        }
        if baseType == "bit" {
            let bits = value.filter { !$0.isWhitespace }
            guard !bits.isEmpty, bits.allSatisfy({ $0 == "0" || $0 == "1" }) else {
                throw RecordValueError.invalidValue(column: columnName, expected: "a sequence of 0 and 1 bits")
            }
            var padded = bits
            let remainder = padded.count % 8
            if remainder != 0 { padded = String(repeating: "0", count: 8 - remainder) + padded }
            var bytes = Data()
            var index = padded.startIndex
            while index < padded.endIndex {
                let end = padded.index(index, offsetBy: 8)
                guard let byte = UInt8(padded[index..<end], radix: 2) else {
                    throw RecordValueError.invalidValue(column: columnName, expected: "a sequence of 0 and 1 bits")
                }
                bytes.append(byte)
                index = end
            }
            return .bit(bytes)
        }
        if isBinary {
            guard let data = Data(base64Encoded: value) else {
                throw RecordValueError.invalidValue(column: columnName, expected: "Base64-encoded binary data")
            }
            return .data(data)
        }
        let temporalKind: DatabaseTemporalValue.Kind?
        switch baseType {
        case "date": temporalKind = .date
        case "time": temporalKind = .time
        case "datetime": temporalKind = .dateTime
        case "timestamp": temporalKind = .timestamp
        case "year": temporalKind = .year
        default: temporalKind = nil
        }
        if let temporalKind {
            return .temporal(DatabaseTemporalValue(rawValue: value, kind: temporalKind))
        }
        return .string(editText)
    }
}

enum RecordValueError: LocalizedError {
    case invalidValue(column: String, expected: String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let column, let expected):
            return "‘\(column)’ must contain \(expected)."
        }
    }
}

// MARK: - Record Editor

struct RecordEditorView: View {
    enum RecordEditorMode {
        case edit(rowIndex: Int, originalRow: [DatabaseValue])
        case add
    }

    let columns: [ColumnInfo]
    let mode: RecordEditorMode
    let onSave: ([StagedEdit], RecordEditorMode) -> Void
    let onDiscard: () -> Void

    private var isAddMode: Bool {
        if case .add = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .edit(let rowIndex, _): return "Edit Row \(rowIndex + 1)"
        case .add: return "Add Row"
        }
    }

    @State private var edits: [StagedEdit] = []
    @State private var jsonErrors: [Int: String] = [:]

    private var hasChanges: Bool {
        edits.contains(where: \.isModified)
    }

    private var changeCount: Int {
        edits.filter(\.isModified).count
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(edits.enumerated()), id: \.element.id) { idx, edit in
                    fieldSection(edit: edit, index: idx)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDiscard() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAddMode ? "Insert" : "Apply \(changeCount > 0 ? "(\(changeCount))" : "")") {
                        if isAddMode {
                            onSave(edits.filter { !$0.useDefault }, mode)
                        } else {
                            onSave(edits.filter(\.isModified), mode)
                        }
                    }
                    .disabled(isAddMode ? jsonErrors.isEmpty == false : (!hasChanges || !jsonErrors.isEmpty))
                }
            }
        }
        .onAppear { initializeEdits() }
    }

    // MARK: - Field Section

    @ViewBuilder
    private func fieldSection(edit: StagedEdit, index: Int) -> some View {
        Section {
            if edit.isGenerated {
                LabeledContent("Value", value: "GENERATED BY SERVER")
            } else if isAddMode && edit.useDefault {
                LabeledContent("Value", value: edit.defaultValue.map { "DEFAULT (\($0))" } ?? "DEFAULT")
                Button("Provide Value") {
                    edits[index].useDefault = false
                    edits[index].isNull = false
                }
                if edit.isNullable {
                    Button("Insert NULL") {
                        edits[index].useDefault = false
                        edits[index].isNull = true
                    }
                }
            } else if edit.isBool {
                boolField(edit: edit, index: index)
            } else if edit.isJSON {
                jsonField(edit: edit, index: index)
            } else if edit.isLargeText {
                largeTextField(edit: edit, index: index)
            } else {
                standardField(edit: edit, index: index)
            }

            // "Set to NULL" only — typing clears NULL automatically
            if edit.isNullable && !edit.isPrimaryKey && !edit.isNull {
                Button("Set to NULL", role: .destructive) {
                    edits[index].isNull = true
                    edits[index].useDefault = false
                    edits[index].editText = ""
                    jsonErrors.removeValue(forKey: index)
                }
                .font(.caption)
            }

            if isAddMode && !edit.useDefault {
                Button("Use Column Default") {
                    edits[index].useDefault = true
                    edits[index].isNull = true
                    edits[index].editText = ""
                    jsonErrors.removeValue(forKey: index)
                }
                .font(.caption)
            }

            if let jsonErr = jsonErrors[index] {
                Label(jsonErr, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            HStack(spacing: 6) {
                Text(edit.columnName)
                if edit.isPrimaryKey {
                    Image(systemName: "key.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                if edit.isGenerated {
                    Text("GENERATED")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(edit.columnType)
                    .foregroundStyle(.secondary)
                Spacer()
                if edit.isModified {
                    Text("Modified")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Standard Field

    private func standardField(edit: StagedEdit, index: Int) -> some View {
        TextField(
            edit.columnName,
            text: fieldBinding(index: index),
            prompt: edit.isNull ? Text("NULL") : nil
        )
        .font(.system(.body, design: .monospaced))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(.asciiCapable)
    }

    // MARK: - Large Text Field

    private func largeTextField(edit: StagedEdit, index: Int) -> some View {
        TextField(
            edit.columnName,
            text: fieldBinding(index: index),
            prompt: edit.isNull ? Text("NULL") : nil,
            axis: .vertical
        )
        .font(.system(.body, design: .monospaced))
        .lineLimit(3...10)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .keyboardType(.asciiCapable)
    }

    // MARK: - Boolean Field

    private func boolField(edit: StagedEdit, index: Int) -> some View {
        Toggle(
            edit.isNull ? "NULL" : (edit.editText == "1" || edit.editText.lowercased() == "true" ? "true" : "false"),
            isOn: Binding(
                get: {
                    if edit.isNull { return false }
                    return edit.editText == "1" || edit.editText.lowercased() == "true"
                },
                set: { val in
                    edits[index].editText = val ? "1" : "0"
                    edits[index].isNull = false
                    edits[index].useDefault = false
                }
            )
        )
    }

    // MARK: - JSON Field

    @ViewBuilder
    private func jsonField(edit: StagedEdit, index: Int) -> some View {
        if edit.isNull {
            TextField(
                edit.columnName,
                text: fieldBinding(index: index),
                prompt: Text("NULL")
            )
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(.asciiCapable)
        } else {
            TextEditor(text: fieldBinding(index: index))
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120, maxHeight: 300)

            HStack {
                Button("Format") { formatJSON(index: index) }
                Button("Validate") { validateJSON(edits[index].editText, index: index) }
            }
            .font(.caption)
        }
    }

    // MARK: - Bindings

    private func fieldBinding(index: Int) -> Binding<String> {
        Binding(
            get: { edits[index].isNull ? "" : edits[index].editText },
            set: { newText in
                edits[index].editText = newText
                edits[index].isNull = false
                edits[index].useDefault = false
            }
        )
    }

    // MARK: - JSON Helpers

    private func validateJSON(_ text: String, index: Int) {
        guard !text.isEmpty else {
            jsonErrors.removeValue(forKey: index)
            return
        }
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8))
            jsonErrors.removeValue(forKey: index)
        } catch {
            jsonErrors[index] = error.localizedDescription
        }
    }

    private func formatJSON(index: Int) {
        let text = edits[index].editText
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: formatted, encoding: .utf8) else {
            return
        }
        edits[index].editText = str
    }

    // MARK: - Init

    private func initializeEdits() {
        jsonErrors.removeAll()
        switch mode {
        case .edit(_, let originalRow):
            edits = columns.enumerated().map { colIndex, col in
                let value = colIndex < originalRow.count ? originalRow[colIndex] : .null
                return StagedEdit(
                    columnIndex: colIndex,
                    columnName: col.name,
                    columnType: col.type,
                    isPrimaryKey: col.isPrimaryKey,
                    isNullable: col.isNullable,
                    isUnsigned: col.isUnsigned,
                    isGenerated: col.isGenerated,
                    defaultValue: col.defaultValue,
                    originalValue: value,
                    editText: editorText(for: value),
                    isNull: value.isNull,
                    useDefault: false
                )
            }
        case .add:
            edits = columns.enumerated().map { colIndex, col in
                StagedEdit(
                    columnIndex: colIndex,
                    columnName: col.name,
                    columnType: col.type,
                    isPrimaryKey: col.isPrimaryKey,
                    isNullable: col.isNullable,
                    isUnsigned: col.isUnsigned,
                    isGenerated: col.isGenerated,
                    defaultValue: col.defaultValue,
                    originalValue: .null,
                    editText: "",
                    isNull: true,
                    useDefault: true
                )
            }
        }
    }

    private func editorText(for value: DatabaseValue) -> String {
        switch value {
        case .data(let data): return data.base64EncodedString()
        case .bit(let data):
            return data.map { String($0, radix: 2).leftPadded(to: 8) }.joined()
        default: return value.isNull ? "" : value.displayString
        }
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        String(repeating: "0", count: max(0, length - count)) + self
    }
}
