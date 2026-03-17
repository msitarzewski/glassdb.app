//
//  SQLHighlighter.swift
//  glassdb
//
//  SQL syntax highlighting + basic linting for the query editor.
//  Produces NSAttributedString for use with UITextView on visionOS.
//

import UIKit

// MARK: - Token Types

enum SQLTokenKind {
    case keyword
    case function
    case string
    case number
    case comment
    case identifier
    case operator_
    case punctuation
    case plain
    case error
}

struct SQLToken {
    let kind: SQLTokenKind
    let range: Range<String.Index>
}

// MARK: - Lint Diagnostic

struct SQLDiagnostic: Identifiable {
    let id = UUID()
    let range: Range<String.Index>
    let message: String
}

// MARK: - Highlighter

struct SQLHighlighter {

    // MARK: Keywords

    private static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "IS", "NULL",
        "AS", "ON", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "CROSS",
        "FULL", "NATURAL", "USING", "ORDER", "BY", "ASC", "DESC",
        "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
        "CREATE", "ALTER", "DROP", "TABLE", "DATABASE", "INDEX", "VIEW",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT",
        "IF", "EXISTS", "DEFAULT", "AUTO_INCREMENT", "UNIQUE",
        "GRANT", "REVOKE", "SHOW", "DESCRIBE", "DESC", "EXPLAIN", "USE",
        "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "SAVEPOINT",
        "CASE", "WHEN", "THEN", "ELSE", "END",
        "LIKE", "BETWEEN", "ESCAPE", "TRUE", "FALSE",
        "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "MEDIUMINT",
        "VARCHAR", "CHAR", "TEXT", "BLOB", "DATE", "DATETIME",
        "TIMESTAMP", "FLOAT", "DOUBLE", "DECIMAL", "BOOLEAN", "JSON",
        "NOT", "NULL", "UNSIGNED", "SIGNED",
        "TRUNCATE", "RENAME", "LOCK", "UNLOCK", "FLUSH",
        "WITH", "RECURSIVE", "TEMPORARY", "REPLACE",
    ]

    private static let functions: Set<String> = [
        "COUNT", "SUM", "AVG", "MIN", "MAX", "NOW", "CURDATE", "CURTIME",
        "CONCAT", "SUBSTRING", "SUBSTR", "LENGTH", "TRIM", "UPPER", "LOWER",
        "COALESCE", "IFNULL", "NULLIF", "CAST", "CONVERT",
        "DATE_FORMAT", "DATE_ADD", "DATE_SUB", "DATEDIFF",
        "ABS", "CEIL", "FLOOR", "ROUND", "MOD", "RAND",
        "GROUP_CONCAT", "JSON_EXTRACT", "JSON_ARRAYAGG",
        "ROW_NUMBER", "RANK", "DENSE_RANK", "LEAD", "LAG",
        "OVER", "PARTITION",
    ]

    // MARK: Tokenizer

    static func tokenize(_ sql: String) -> [SQLToken] {
        var tokens: [SQLToken] = []
        var i = sql.startIndex

        while i < sql.endIndex {
            let c = sql[i]

            // Whitespace — skip
            if c.isWhitespace {
                i = sql.index(after: i)
                continue
            }

            // Single-line comment: -- ...
            if c == "-", let next = sql.index(i, offsetBy: 1, limitedBy: sql.endIndex),
               next < sql.endIndex, sql[next] == "-" {
                let start = i
                if let newline = sql[i...].firstIndex(where: { $0 == "\n" }) {
                    i = sql.index(after: newline)
                    tokens.append(SQLToken(kind: .comment, range: start..<i))
                } else {
                    tokens.append(SQLToken(kind: .comment, range: start..<sql.endIndex))
                    i = sql.endIndex
                }
                continue
            }

            // Block comment: /* ... */
            if c == "/", let next = sql.index(i, offsetBy: 1, limitedBy: sql.endIndex),
               next < sql.endIndex, sql[next] == "*" {
                let start = i
                i = sql.index(i, offsetBy: 2)
                while i < sql.endIndex {
                    if sql[i] == "*",
                       let next2 = sql.index(i, offsetBy: 1, limitedBy: sql.endIndex),
                       next2 < sql.endIndex, sql[next2] == "/" {
                        i = sql.index(i, offsetBy: 2)
                        break
                    }
                    i = sql.index(after: i)
                }
                tokens.append(SQLToken(kind: .comment, range: start..<i))
                continue
            }

            // String literal: 'text' (handles escaped quotes '')
            if c == "'" {
                let start = i
                i = sql.index(after: i)
                var closed = false
                while i < sql.endIndex {
                    if sql[i] == "'" {
                        let afterQuote = sql.index(after: i)
                        if afterQuote < sql.endIndex, sql[afterQuote] == "'" {
                            i = sql.index(after: afterQuote) // skip ''
                        } else {
                            i = afterQuote
                            closed = true
                            break
                        }
                    } else {
                        i = sql.index(after: i)
                    }
                }
                tokens.append(SQLToken(kind: closed ? .string : .error, range: start..<i))
                continue
            }

            // Backtick identifier: `name`
            if c == "`" {
                let start = i
                i = sql.index(after: i)
                var closed = false
                while i < sql.endIndex {
                    if sql[i] == "`" {
                        i = sql.index(after: i)
                        closed = true
                        break
                    }
                    i = sql.index(after: i)
                }
                tokens.append(SQLToken(kind: closed ? .identifier : .error, range: start..<i))
                continue
            }

            // Double-quoted identifier: "name"
            if c == "\"" {
                let start = i
                i = sql.index(after: i)
                var closed = false
                while i < sql.endIndex {
                    if sql[i] == "\"" {
                        i = sql.index(after: i)
                        closed = true
                        break
                    }
                    i = sql.index(after: i)
                }
                tokens.append(SQLToken(kind: closed ? .identifier : .error, range: start..<i))
                continue
            }

            // Number
            if c.isNumber || (c == "." && i < sql.endIndex) {
                let start = i
                if c.isNumber {
                    while i < sql.endIndex, sql[i].isNumber || sql[i] == "." {
                        i = sql.index(after: i)
                    }
                    tokens.append(SQLToken(kind: .number, range: start..<i))
                    continue
                }
            }

            // Word (keyword, function, or plain identifier)
            if c.isLetter || c == "_" || c == "@" {
                let start = i
                while i < sql.endIndex, sql[i].isLetter || sql[i].isNumber || sql[i] == "_" || sql[i] == "." || sql[i] == "@" {
                    i = sql.index(after: i)
                }
                let word = String(sql[start..<i])
                let upper = word.uppercased()
                if keywords.contains(upper) {
                    tokens.append(SQLToken(kind: .keyword, range: start..<i))
                } else if functions.contains(upper) {
                    tokens.append(SQLToken(kind: .function, range: start..<i))
                } else {
                    tokens.append(SQLToken(kind: .plain, range: start..<i))
                }
                continue
            }

            // Operators
            if "<>=!+-*/%".contains(c) {
                let start = i
                i = sql.index(after: i)
                if i < sql.endIndex, "=><".contains(sql[i]) {
                    i = sql.index(after: i)
                }
                tokens.append(SQLToken(kind: .operator_, range: start..<i))
                continue
            }

            // Punctuation
            if "(),;.".contains(c) {
                let start = i
                i = sql.index(after: i)
                tokens.append(SQLToken(kind: .punctuation, range: start..<i))
                continue
            }

            // Unknown character — advance
            i = sql.index(after: i)
        }

        return tokens
    }

    // MARK: Lint

    static func lint(_ sql: String, tokens: [SQLToken]? = nil) -> [SQLDiagnostic] {
        let toks = tokens ?? tokenize(sql)
        var diagnostics: [SQLDiagnostic] = []

        for token in toks {
            if token.kind == .error {
                diagnostics.append(SQLDiagnostic(
                    range: token.range,
                    message: "Unterminated string or identifier"
                ))
            }
        }

        return diagnostics
    }

    // MARK: Attributed String

    static func highlight(_ sql: String, fontSize: CGFloat = 14) -> NSAttributedString {
        let tokens = tokenize(sql)
        let attr = NSMutableAttributedString(
            string: sql,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor.white,
            ]
        )

        for token in tokens {
            let nsRange = NSRange(token.range, in: sql)
            let color: UIColor
            switch token.kind {
            case .keyword:
                color = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
                attr.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold), range: nsRange)
            case .function:
                color = UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)
            case .string:
                color = UIColor.systemGreen
            case .number:
                color = UIColor.systemOrange
            case .comment:
                color = UIColor(white: 0.55, alpha: 1.0)
            case .identifier:
                color = UIColor(red: 0.4, green: 0.8, blue: 0.8, alpha: 1.0)
            case .operator_:
                color = UIColor.white
            case .punctuation:
                color = UIColor(white: 0.6, alpha: 1.0)
            case .error:
                color = UIColor.systemRed
                attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
                attr.addAttribute(.underlineColor, value: UIColor.systemRed, range: nsRange)
            case .plain:
                color = UIColor.white
            }
            attr.addAttribute(.foregroundColor, value: color, range: nsRange)
        }

        // Lint diagnostics — add wavy underline on errors
        let diagnostics = lint(sql, tokens: tokens)
        for diag in diagnostics {
            let nsRange = NSRange(diag.range, in: sql)
            attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.patternDot.union(.single).rawValue, range: nsRange)
            attr.addAttribute(.underlineColor, value: UIColor.systemRed, range: nsRange)
        }

        return attr
    }
}
