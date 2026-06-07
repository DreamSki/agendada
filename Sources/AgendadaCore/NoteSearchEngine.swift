import Foundation

/// The canonical search implementation for Agendada notes.
///
/// Design goals:
/// - keep structural filtering separate from text highlighting / occurrence navigation;
/// - preserve the existing simple syntax (`tag:`, `person:`, `has:`, `is:`, `date:`);
/// - add mature query semantics: phrases, OR, NOT, parentheses, field scoping, `#tag`, `@person`;
/// - make Smart Overview queries and transient list searches use the same parser/evaluator.
public enum NoteSearchEngine {
    public static func parse(_ rawText: String) -> NoteSearchQuery {
        let tokens = SearchTokenizer(rawText).tokens()
        var parser = SearchParser(tokens: tokens)
        let expression = parser.parse()
        return NoteSearchQuery(rawText: rawText, expression: expression.normalized)
    }

    public static func mergedQuery(savedQuery: String?, transientText: String) -> NoteSearchQuery {
        let parts = [savedQuery, transientText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parse(parts.joined(separator: " "))
    }

    public static func filter(_ notes: [Note], query rawText: String, now: Date = Date()) -> [Note] {
        filter(notes, query: parse(rawText), now: now)
    }

    public static func filter(_ notes: [Note], query: NoteSearchQuery, now: Date = Date()) -> [Note] {
        guard !query.isEmpty else { return notes }
        return notes.filter { matches($0, query: query, now: now) }
    }

    public static func matches(_ note: Note, query: NoteSearchQuery, now: Date = Date()) -> Bool {
        evaluate(query.expression, note: note, now: now)
    }

    public static func highlightText(for rawText: String) -> String {
        parse(rawText).highlightTerms.map(\.value).joined(separator: " ")
    }

    public static func occurrences(in notes: [Note], query rawText: String, now: Date = Date()) -> [SearchOccurrence] {
        occurrences(in: notes, query: parse(rawText), now: now)
    }

    public static func occurrences(in notes: [Note], query: NoteSearchQuery, now: Date = Date()) -> [SearchOccurrence] {
        let terms = query.highlightTerms
        guard !terms.isEmpty else { return [] }

        var result: [SearchOccurrence] = []
        var globalIndex = 0

        for note in notes {
            let titleTerms = terms.filter { $0.field == .any || $0.field == .title }
            let bodyTerms = terms.filter { $0.field == .any || $0.field == .body }
            let titleHits = sortedUniqueHits(in: note.title, terms: titleTerms)
            let bodyHits = sortedUniqueHits(in: note.bodyPlainText, terms: bodyTerms)
            var occurrenceIndexInNote = 0
            var bodyIndexInNote = 0

            for hit in titleHits {
                result.append(SearchOccurrence(
                    noteID: note.id,
                    noteTitle: note.title,
                    globalIndex: globalIndex,
                    occurrenceIndexInNote: occurrenceIndexInNote,
                    bodyIndexInNote: -1,
                    field: .title,
                    matchPosition: hit.position,
                    matchLength: hit.length,
                    excerpt: hit.excerpt
                ))
                globalIndex += 1
                occurrenceIndexInNote += 1
            }

            for hit in bodyHits {
                result.append(SearchOccurrence(
                    noteID: note.id,
                    noteTitle: note.title,
                    globalIndex: globalIndex,
                    occurrenceIndexInNote: occurrenceIndexInNote,
                    bodyIndexInNote: bodyIndexInNote,
                    field: .body,
                    matchPosition: hit.position,
                    matchLength: hit.length,
                    excerpt: hit.excerpt
                ))
                globalIndex += 1
                occurrenceIndexInNote += 1
                bodyIndexInNote += 1
            }
        }

        return result
    }

    private static func evaluate(_ expression: NoteSearchExpression, note: Note, now: Date) -> Bool {
        switch expression {
        case .empty:
            return true
        case let .predicate(predicate):
            return evaluate(predicate, note: note, now: now)
        case let .all(children):
            return children.allSatisfy { evaluate($0, note: note, now: now) }
        case let .any(children):
            return children.contains { evaluate($0, note: note, now: now) }
        case let .not(child):
            return !evaluate(child, note: note, now: now)
        }
    }

    private static func evaluate(_ predicate: NoteSearchPredicate, note: Note, now: Date) -> Bool {
        switch predicate {
        case let .text(term):
            return matchesText(term, note: note)
        case let .tag(value):
            return note.tags.contains { equivalent($0, value) }
        case let .person(value):
            return note.people.contains { equivalent($0, value) }
        case let .status(value):
            return matchesStatus(note.status, value: value)
        case let .has(kind):
            return matchesHasPredicate(kind, note: note)
        case let .is(kind):
            return matchesIsPredicate(kind, note: note)
        case let .date(kind):
            return matchesDatePredicate(kind, note: note, now: now)
        }
    }

    private static func matchesText(_ term: NoteSearchTextTerm, note: Note) -> Bool {
        switch term.field {
        case .any:
            let haystacks = [note.title, note.bodyPlainText] + note.tags + note.people
            return haystacks.contains { contains($0, term.value) }
        case .title:
            return contains(note.title, term.value)
        case .body:
            return contains(note.bodyPlainText, term.value)
        case .metadata:
            return (note.tags + note.people + [note.status.title, note.status.rawValue]).contains { contains($0, term.value) }
        }
    }

    private static func matchesStatus(_ status: NoteStatus, value: String) -> Bool {
        equivalent(status.rawValue, value) || equivalent(status.title, value) || {
            switch value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased() {
            case "open", "todo", "active", "进行中": return status == .open
            case "completed", "complete", "done", "已完成": return status == .completed
            case "closed", "archived", "archive", "已归档": return status == .closed
            case "trashed", "trash", "deleted", "废纸篓": return status == .trashed
            default: return false
            }
        }()
    }

    private static func matchesHasPredicate(_ kind: NoteSearchHasPredicate, note: Note) -> Bool {
        switch kind {
        case .tasks:
            return note.checklistSummary.hasOpenItems
        case .date:
            return note.scheduledDate != nil
        case .tags:
            return !note.tags.isEmpty
        case .people:
            return !note.people.isEmpty
        }
    }

    private static func matchesIsPredicate(_ kind: NoteSearchIsPredicate, note: Note) -> Bool {
        switch kind {
        case .focused:
            return note.isFocused
        case .starred:
            return note.isStarred
        case .brief:
            return note.isBrief
        case .open:
            return note.status == .open
        case .completed:
            return note.status == .completed
        case .closed:
            return note.status == .closed
        case .trashed:
            return note.status == .trashed
        }
    }

    private static func matchesDatePredicate(_ kind: NoteSearchDatePredicate, note: Note, now: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let date = note.scheduledDate else {
            return kind == .none
        }
        let day = calendar.startOfDay(for: date)

        switch kind {
        case .today:
            return day == today
        case .tomorrow:
            return day == calendar.safeDate(byAdding: .day, value: 1, to: today)
        case .yesterday:
            return day == calendar.safeDate(byAdding: .day, value: -1, to: today)
        case .upcoming:
            return day > today
        case .overdue:
            return day < today
        case .none:
            return false
        }
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(
            of: needle,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: haystack.startIndex..<haystack.endIndex,
            locale: .current
        ) != nil
    }

    private static func equivalent(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == .orderedSame
    }

    internal static func sortedUniqueHits(in text: String, terms: [NoteSearchTextTerm]) -> [SearchHit] {
        var hits: [SearchHit] = []
        var seen = Set<String>()

        for term in terms where !term.value.isEmpty {
            for hit in hitsForTerm(term.value, in: text) {
                let key = "\(hit.position):\(hit.length)"
                if seen.insert(key).inserted {
                    hits.append(hit)
                }
            }
        }

        return hits.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.length > $1.length
        }
    }

    internal static func hitsForTerm(_ term: String, in text: String) -> [SearchHit] {
        guard !term.isEmpty, !text.isEmpty else { return [] }

        var hits: [SearchHit] = []
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(
            of: term,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange,
            locale: .current
        ) {
            let nsRange = NSRange(range, in: text)
            hits.append(SearchHit(
                position: nsRange.location,
                length: nsRange.length,
                excerpt: excerpt(around: range, in: text)
            ))

            guard range.upperBound < text.endIndex else { break }
            searchRange = range.upperBound..<text.endIndex
        }

        return hits
    }

    internal static func excerpt(around range: Range<String.Index>, in text: String) -> String {
        let context = 30
        let lower = text.index(range.lowerBound, offsetBy: -context, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: context, limitedBy: text.endIndex) ?? text.endIndex
        var value = String(text[lower..<upper]).trimmingCharacters(in: .whitespacesAndNewlines)
        if lower > text.startIndex { value = "…" + value }
        if upper < text.endIndex { value += "…" }
        return value
    }

    // MARK: - Query Chips

    /// Parse `rawText` into read-only query chips for visual feedback in the search popover.
    /// Reuses ``SearchTokenizer`` so that field prefixes (`tag:`, `person:`, etc.) are
    /// already coalesced with their values.
    public static func chips(for rawText: String) -> [QueryChip] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tokens = SearchTokenizer(trimmed).tokens()
        var chips: [QueryChip] = []
        var index = 0

        while index < tokens.count {
            let token = tokens[index]

            switch token {
            case .not:
                // Coalesce NOT + next word/phrase into a single notKeyword chip
                if index + 1 < tokens.count {
                    let next = tokens[index + 1]
                    switch next {
                    case let .word(word):
                        let (label, _) = Self.chipLabelAndType(for: word)
                        chips.append(QueryChip(label: "NOT \(label)", chipType: .notKeyword))
                        index += 2
                        continue
                    case let .phrase(phrase):
                        chips.append(QueryChip(label: "NOT \"\(phrase)\"", chipType: .notKeyword))
                        index += 2
                        continue
                    case .leftParen:
                        // NOT before parenthesized group — emit standalone NOT chip
                        chips.append(QueryChip(label: "NOT", chipType: .notKeyword))
                        index += 1
                        continue
                    default:
                        chips.append(QueryChip(label: "NOT", chipType: .notKeyword))
                        index += 1
                        continue
                    }
                } else {
                    chips.append(QueryChip(label: "NOT", chipType: .notKeyword))
                    index += 1
                }

            case let .word(word):
                let (label, type) = Self.chipLabelAndType(for: word)
                chips.append(QueryChip(label: label, chipType: type))
                index += 1

            case let .phrase(phrase):
                chips.append(QueryChip(label: "\"\(phrase)\"", chipType: .keyword))
                index += 1

            case .leftParen, .rightParen, .and, .or:
                // Structural tokens — not rendered as chips
                index += 1
            }
        }

        return chips
    }

    /// Classify a coalesced word token into a (displayLabel, chipType) pair.
    private static func chipLabelAndType(for word: String) -> (label: String, type: QueryChipType) {
        // `#tag` shorthand
        if word.hasPrefix("#") {
            return (word, .tag)
        }
        // `@person` shorthand
        if word.hasPrefix("@") {
            return (word, .person)
        }

        guard let colon = word.firstIndex(of: ":") else {
            return (stripSurroundingQuotes(word), .keyword)
        }

        let key = word[..<colon].lowercased()
        let rawValue = String(word[word.index(after: colon)...])
        let value = stripSurroundingQuotes(rawValue)

        switch key {
        case "tag", "tags":
            return ("#\(value)", .tag)
        case "person", "people", "assignee", "owner":
            return ("@\(value)", .person)
        case "status":
            return (word, .status)
        case "has":
            return (word, .has)
        case "is":
            return (word, .is)
        case "date", "scheduled":
            return (word, .date)
        case "title", "body", "content", "meta", "metadata":
            return (word, .keyword)
        default:
            return (stripSurroundingQuotes(word), .keyword)
        }
    }

    private static func stripSurroundingQuotes(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return value }
        return String(value.dropFirst().dropLast())
    }
}

public struct NoteSearchQuery: Equatable, Sendable {
    public let rawText: String
    public let expression: NoteSearchExpression

    public var isEmpty: Bool { expression == .empty }

    public var highlightTerms: [NoteSearchTextTerm] {
        expression.positiveTextTerms
    }

    public init(rawText: String, expression: NoteSearchExpression) {
        self.rawText = rawText
        self.expression = expression
    }
}

public indirect enum NoteSearchExpression: Equatable, Sendable {
    case empty
    case predicate(NoteSearchPredicate)
    case all([NoteSearchExpression])
    case any([NoteSearchExpression])
    case not(NoteSearchExpression)

    var normalized: NoteSearchExpression {
        switch self {
        case .empty:
            return .empty
        case .predicate:
            return self
        case let .not(child):
            return .not(child.normalized)
        case let .all(children):
            let flattened = children.flatMap { child -> [NoteSearchExpression] in
                switch child.normalized {
                case .empty:
                    return []
                case let .all(grandchildren):
                    return grandchildren
                case let other:
                    return [other]
                }
            }
            if flattened.isEmpty { return .empty }
            if flattened.count == 1 { return flattened[0] }
            return .all(flattened)
        case let .any(children):
            let flattened = children.flatMap { child -> [NoteSearchExpression] in
                switch child.normalized {
                case .empty:
                    return []
                case let .any(grandchildren):
                    return grandchildren
                case let other:
                    return [other]
                }
            }
            if flattened.isEmpty { return .empty }
            if flattened.count == 1 { return flattened[0] }
            return .any(flattened)
        }
    }

    var positiveTextTerms: [NoteSearchTextTerm] {
        switch self {
        case .empty:
            return []
        case let .predicate(predicate):
            if case let .text(term) = predicate { return [term] }
            return []
        case let .all(children), let .any(children):
            return children.flatMap(\.positiveTextTerms).deduplicatedTextTerms()
        case .not:
            return []
        }
    }
}

public enum NoteSearchPredicate: Equatable, Sendable {
    case text(NoteSearchTextTerm)
    case tag(String)
    case person(String)
    case status(String)
    case has(NoteSearchHasPredicate)
    case `is`(NoteSearchIsPredicate)
    case date(NoteSearchDatePredicate)
}

public struct NoteSearchTextTerm: Equatable, Hashable, Sendable {
    public let value: String
    public let field: NoteSearchTextField
    public let isPhrase: Bool

    public init(value: String, field: NoteSearchTextField = .any, isPhrase: Bool = false) {
        self.value = value
        self.field = field
        self.isPhrase = isPhrase
    }
}

public enum NoteSearchTextField: String, Equatable, Hashable, Sendable {
    case any
    case title
    case body
    case metadata
}

public enum NoteSearchHasPredicate: String, Equatable, Sendable {
    case tasks
    case date
    case tags
    case people
}

public enum NoteSearchIsPredicate: String, Equatable, Sendable {
    case focused
    case starred
    case brief
    case open
    case completed
    case closed
    case trashed
}

public enum NoteSearchDatePredicate: String, Equatable, Sendable {
    case today
    case tomorrow
    case yesterday
    case upcoming
    case overdue
    case none
}

internal struct SearchHit: Equatable, Sendable {
    let position: Int
    let length: Int
    let excerpt: String
}

private enum SearchToken: Equatable {
    case word(String)
    case phrase(String)
    case leftParen
    case rightParen
    case and
    case or
    case not
}

private struct SearchTokenizer {
    let raw: String

    init(_ raw: String) {
        self.raw = raw
    }

    func tokens() -> [SearchToken] {
        var tokens: [SearchToken] = []
        var index = raw.startIndex

        while index < raw.endIndex {
            let char = raw[index]

            if char.isWhitespace {
                raw.formIndex(after: &index)
                continue
            }

            switch char {
            case "(":
                tokens.append(.leftParen)
                raw.formIndex(after: &index)
            case ")":
                tokens.append(.rightParen)
                raw.formIndex(after: &index)
            case "-":
                tokens.append(.not)
                raw.formIndex(after: &index)
            case "\"":
                raw.formIndex(after: &index)
                let start = index
                while index < raw.endIndex, raw[index] != "\"" {
                    raw.formIndex(after: &index)
                }
                tokens.append(.phrase(String(raw[start..<index])))
                if index < raw.endIndex { raw.formIndex(after: &index) }
            default:
                let start = index
                while index < raw.endIndex,
                      !raw[index].isWhitespace,
                      raw[index] != "(",
                      raw[index] != ")",
                      raw[index] != "\"" {
                    raw.formIndex(after: &index)
                }
                let word = String(raw[start..<index])
                tokens.append(Self.token(forWord: word))
            }
        }

        return Self.coalescingFieldPrefixes(tokens)
    }

    private static func token(forWord word: String) -> SearchToken {
        switch word.uppercased() {
        case "AND": return .and
        case "OR": return .or
        case "NOT": return .not
        default: return .word(word)
        }
    }

    private static func coalescingFieldPrefixes(_ tokens: [SearchToken]) -> [SearchToken] {
        var result: [SearchToken] = []
        var index = 0

        while index < tokens.count {
            if case let .word(prefix) = tokens[index], prefix.hasSuffix(":"), index + 1 < tokens.count {
                switch tokens[index + 1] {
                case let .word(value):
                    result.append(.word(prefix + value))
                    index += 2
                    continue
                case let .phrase(value):
                    result.append(.word(prefix + "\"" + value + "\""))
                    index += 2
                    continue
                default:
                    break
                }
            }
            result.append(tokens[index])
            index += 1
        }

        return result
    }
}

private struct SearchParser {
    private let tokens: [SearchToken]
    private var index = 0

    init(tokens: [SearchToken]) {
        self.tokens = tokens
    }

    mutating func parse() -> NoteSearchExpression {
        parseOr().normalized
    }

    private mutating func parseOr() -> NoteSearchExpression {
        var children = [parseAnd()]
        while match(.or) {
            children.append(parseAnd())
        }
        return children.count == 1 ? children[0] : .any(children)
    }

    private mutating func parseAnd() -> NoteSearchExpression {
        var children: [NoteSearchExpression] = []

        while index < tokens.count {
            if peek == .rightParen || peek == .or { break }
            _ = match(.and)
            if peek == .rightParen || peek == .or { break }
            children.append(parseUnary())
        }

        if children.isEmpty { return .empty }
        return children.count == 1 ? children[0] : .all(children)
    }

    private mutating func parseUnary() -> NoteSearchExpression {
        if match(.not) {
            return .not(parseUnary())
        }

        if match(.leftParen) {
            let expression = parseOr()
            _ = match(.rightParen)
            return expression
        }

        guard index < tokens.count else { return .empty }
        let token = tokens[index]
        index += 1
        return expression(for: token)
    }

    private func expression(for token: SearchToken) -> NoteSearchExpression {
        switch token {
        case let .word(word):
            return .predicate(predicate(for: word, isPhrase: false))
        case let .phrase(phrase):
            return phrase.isEmpty ? .empty : .predicate(.text(NoteSearchTextTerm(value: phrase, isPhrase: true)))
        default:
            return .empty
        }
    }

    private func predicate(for word: String, isPhrase: Bool) -> NoteSearchPredicate {
        if word.hasPrefix("#") {
            return .tag(String(word.dropFirst()))
        }
        if word.hasPrefix("@") {
            return .person(String(word.dropFirst()))
        }

        guard let colon = word.firstIndex(of: ":") else {
            return .text(NoteSearchTextTerm(value: unquoted(word), isPhrase: isPhrase))
        }

        let key = word[..<colon].lowercased()
        let rawValue = String(word[word.index(after: colon)...])
        let value = unquoted(rawValue)

        switch key {
        case "tag", "tags":
            return .tag(value)
        case "person", "people", "assignee", "owner":
            return .person(value)
        case "status":
            return .status(value)
        case "has":
            return .has(NoteSearchHasPredicate(rawValue: value.lowercased()) ?? .tasks)
        case "is":
            return .is(NoteSearchIsPredicate(rawValue: value.lowercased()) ?? .open)
        case "date", "scheduled":
            return .date(NoteSearchDatePredicate(rawValue: value.lowercased()) ?? .today)
        case "title":
            return .text(NoteSearchTextTerm(value: value, field: .title, isPhrase: rawValue.hasPrefix("\"")))
        case "body", "content":
            return .text(NoteSearchTextTerm(value: value, field: .body, isPhrase: rawValue.hasPrefix("\"")))
        case "meta", "metadata":
            return .text(NoteSearchTextTerm(value: value, field: .metadata, isPhrase: rawValue.hasPrefix("\"")))
        default:
            return .text(NoteSearchTextTerm(value: unquoted(word), isPhrase: isPhrase))
        }
    }

    private var peek: SearchToken? {
        index < tokens.count ? tokens[index] : nil
    }

    private mutating func match(_ token: SearchToken) -> Bool {
        guard peek == token else { return false }
        index += 1
        return true
    }

    private func unquoted(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return value }
        return String(value.dropFirst().dropLast())
    }
}

private extension Array where Element == NoteSearchTextTerm {
    func deduplicatedTextTerms() -> [NoteSearchTextTerm] {
        var seen = Set<NoteSearchTextTerm>()
        var result: [NoteSearchTextTerm] = []
        for term in self where !term.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if seen.insert(term).inserted {
                result.append(term)
            }
        }
        return result
    }
}
