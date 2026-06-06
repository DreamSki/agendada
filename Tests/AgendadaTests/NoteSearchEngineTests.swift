import Foundation
import Testing
@testable import AgendadaCore

// MARK: - Test Helpers

private let testProjectID = UUID()

private func makeNote(
    title: String,
    body: String = "",
    tags: [String] = [],
    people: [String] = [],
    status: NoteStatus = .open,
    isFocused: Bool = false,
    isStarred: Bool = false,
    isBrief: Bool = false,
    scheduledDate: Date? = nil,
    hasTasks: Bool = false
) -> Note {
    // Build HTML body with optional checklist items to trigger hasOpenItems
    var html = body
    if hasTasks {
        if !html.isEmpty { html += "<br>" }
        html += """


<ul data-type="taskList"><li data-type="taskItem"><input type="checkbox"><span>待办事项</span></li></ul>
"""
    }
    return Note(
        projectID: testProjectID,
        title: title,
        body: html,
        scheduledDate: scheduledDate,
        tags: tags,
        people: people,
        status: status,
        isFocused: isFocused,
        isStarred: isStarred,
        isBrief: isBrief
    )
}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-13-ish

// MARK: - Parser Tests

@Test func parseEmptyQuery() {
    let query = NoteSearchEngine.parse("")
    #expect(query.isEmpty)
}

@Test func parseWhitespaceOnly() {
    let query = NoteSearchEngine.parse("   ")
    #expect(query.isEmpty)
}

@Test func parseSingleWord() {
    let query = NoteSearchEngine.parse("apple")
    #expect(!query.isEmpty)
    let terms = query.highlightTerms
    #expect(terms.count == 1)
    #expect(terms[0].value == "apple")
}

@Test func parseMultipleWordsDefaultAND() {
    let query = NoteSearchEngine.parse("apple banana")
    // Both words must be present (AND semantics)
    let note1 = makeNote(title: "apple banana")
    let note2 = makeNote(title: "apple only")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func parseOR() {
    let query = NoteSearchEngine.parse("apple OR banana")
    let note1 = makeNote(title: "apple only")
    let note2 = makeNote(title: "banana only")
    let note3 = makeNote(title: "cherry")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(NoteSearchEngine.matches(note2, query: query))
    #expect(!NoteSearchEngine.matches(note3, query: query))
}

@Test func parseNOT() {
    let query = NoteSearchEngine.parse("apple -rotten")
    let note1 = makeNote(title: "fresh apple")
    let note2 = makeNote(title: "rotten apple")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func parseNOTKeyword() {
    let query = NoteSearchEngine.parse("apple NOT rotten")
    let note1 = makeNote(title: "fresh apple")
    let note2 = makeNote(title: "rotten apple")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func parseParentheses() {
    let query = NoteSearchEngine.parse("(apple OR banana) cherry")
    let note1 = makeNote(title: "apple cherry")
    let note2 = makeNote(title: "banana cherry")
    let note3 = makeNote(title: "apple banana")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(NoteSearchEngine.matches(note2, query: query))
    #expect(!NoteSearchEngine.matches(note3, query: query))
}

@Test func parsePhrase() {
    let query = NoteSearchEngine.parse(#""apple notes""#)
    let note1 = makeNote(title: "apple notes is great")
    let note2 = makeNote(title: "notes about apple")
    #expect(NoteSearchEngine.matches(note1, query: query))
    // "apple notes" as a phrase should NOT match "notes about apple"
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

// MARK: - Predicate Tests: tag

@Test func tagPredicate() {
    let query = NoteSearchEngine.parse("tag:work")
    let note1 = makeNote(title: "会议", tags: ["work"])
    let note2 = makeNote(title: "work", tags: ["personal"])
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func hashTag() {
    let query = NoteSearchEngine.parse("#work")
    let note1 = makeNote(title: "会议", tags: ["work"])
    let note2 = makeNote(title: "work", tags: [])
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

// MARK: - Predicate Tests: person

@Test func personPredicate() {
    let query = NoteSearchEngine.parse("person:jenny")
    let note1 = makeNote(title: "讨论", people: ["jenny"])
    let note2 = makeNote(title: "jenny", people: [])
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func atPerson() {
    let query = NoteSearchEngine.parse("@jenny")
    let note1 = makeNote(title: "讨论", people: ["jenny"])
    #expect(NoteSearchEngine.matches(note1, query: query))
}

// MARK: - Predicate Tests: status

@Test func statusPredicate() {
    let query = NoteSearchEngine.parse("status:open")
    let note1 = makeNote(title: "进行中", status: .open)
    let note2 = makeNote(title: "已完成", status: .completed)
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func statusChineseAlias() {
    let query = NoteSearchEngine.parse("status:已完成")
    let note1 = makeNote(title: "笔记", status: .completed)
    #expect(NoteSearchEngine.matches(note1, query: query))
}

@Test func statusTrashed() {
    let query = NoteSearchEngine.parse("is:trashed")
    let note1 = makeNote(title: "已删除", status: .trashed)
    let note2 = makeNote(title: "正常", status: .open)
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

// MARK: - Predicate Tests: has

@Test func hasTasks() {
    let query = NoteSearchEngine.parse("has:tasks")
    let note1 = makeNote(title: "待办笔记", hasTasks: true)
    let note2 = makeNote(title: "普通笔记", hasTasks: false)
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func hasDate() {
    let query = NoteSearchEngine.parse("has:date")
    let note1 = makeNote(title: "有日期", scheduledDate: fixedNow)
    let note2 = makeNote(title: "无日期")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func hasTags() {
    let query = NoteSearchEngine.parse("has:tags")
    let note1 = makeNote(title: "有标签", tags: ["work"])
    let note2 = makeNote(title: "无标签")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func hasPeople() {
    let query = NoteSearchEngine.parse("has:people")
    let note1 = makeNote(title: "有人", people: ["jenny"])
    let note2 = makeNote(title: "无人")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

// MARK: - Predicate Tests: is

@Test func isFocused() {
    let query = NoteSearchEngine.parse("is:focused")
    let note1 = makeNote(title: "关注", isFocused: true)
    let note2 = makeNote(title: "普通", isFocused: false)
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func isStarred() {
    let query = NoteSearchEngine.parse("is:starred")
    let note1 = makeNote(title: "星标", isStarred: true)
    let note2 = makeNote(title: "普通", isStarred: false)
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func isBrief() {
    let query = NoteSearchEngine.parse("is:brief")
    let note1 = makeNote(title: "简达", isBrief: true)
    let note2 = makeNote(title: "普通", isBrief: false)
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

// MARK: - Predicate Tests: date

@Test func dateToday() {
    let query = NoteSearchEngine.parse("date:today")
    let today = Calendar.current.startOfDay(for: fixedNow)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    let note1 = makeNote(title: "今天", scheduledDate: today)
    let note2 = makeNote(title: "明天", scheduledDate: tomorrow)
    let note3 = makeNote(title: "无日期")
    #expect(NoteSearchEngine.matches(note1, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note2, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note3, query: query, now: fixedNow))
}

@Test func dateUpcoming() {
    let query = NoteSearchEngine.parse("date:upcoming")
    let today = Calendar.current.startOfDay(for: fixedNow)
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    let note1 = makeNote(title: "明天", scheduledDate: tomorrow)
    let note2 = makeNote(title: "昨天", scheduledDate: yesterday)
    #expect(NoteSearchEngine.matches(note1, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note2, query: query, now: fixedNow))
}

@Test func dateTomorrow() {
    let query = NoteSearchEngine.parse("date:tomorrow")
    let today = Calendar.current.startOfDay(for: fixedNow)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: today)!
    let note1 = makeNote(title: "明天", scheduledDate: tomorrow)
    let note2 = makeNote(title: "后天", scheduledDate: dayAfter)
    #expect(NoteSearchEngine.matches(note1, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note2, query: query, now: fixedNow))
}

@Test func dateYesterday() {
    let query = NoteSearchEngine.parse("date:yesterday")
    let today = Calendar.current.startOfDay(for: fixedNow)
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let note1 = makeNote(title: "昨天", scheduledDate: yesterday)
    let note2 = makeNote(title: "今天", scheduledDate: today)
    #expect(NoteSearchEngine.matches(note1, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note2, query: query, now: fixedNow))
}

@Test func dateOverdue() {
    let query = NoteSearchEngine.parse("date:overdue")
    let today = Calendar.current.startOfDay(for: fixedNow)
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    let note1 = makeNote(title: "过期", scheduledDate: yesterday)
    let note2 = makeNote(title: "未来", scheduledDate: tomorrow)
    #expect(NoteSearchEngine.matches(note1, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note2, query: query, now: fixedNow))
}

@Test func dateNone() {
    let query = NoteSearchEngine.parse("date:none")
    let note1 = makeNote(title: "无日期")
    let note2 = makeNote(title: "有日期", scheduledDate: fixedNow)
    #expect(NoteSearchEngine.matches(note1, query: query, now: fixedNow))
    #expect(!NoteSearchEngine.matches(note2, query: query, now: fixedNow))
}

// MARK: - Field Scoping Tests

@Test func titleScope() {
    let query = NoteSearchEngine.parse(#"title:launch"#)
    let note1 = makeNote(title: "Launch Plan")
    let note2 = makeNote(title: "Meeting", body: "discuss launch details")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func bodyScope() {
    let query = NoteSearchEngine.parse("body:todo")
    let note1 = makeNote(title: "Meeting", body: "todo list for today")
    let note2 = makeNote(title: "Todo Review")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

@Test func metadataScope() {
    let query = NoteSearchEngine.parse("metadata:jenny")
    let note1 = makeNote(title: "会议", people: ["jenny"])
    let note2 = makeNote(title: "jenny is here")
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
}

// MARK: - Filter Tests

@Test func filterReturnsMatchingNotes() {
    let notes = [
        makeNote(title: "Apple Notes"),
        makeNote(title: "Notion Docs"),
        makeNote(title: "Apple Music")
    ]
    let result = NoteSearchEngine.filter(notes, query: "apple")
    #expect(result.count == 2)
    #expect(Set(result.map(\.title)) == ["Apple Notes", "Apple Music"])
}

@Test func filterWithEmptyQueryReturnsAll() {
    let notes = [
        makeNote(title: "A"),
        makeNote(title: "B")
    ]
    let result = NoteSearchEngine.filter(notes, query: "")
    #expect(result.count == 2)
}

@Test func filterWithComplexQuery() {
    let today = Calendar.current.startOfDay(for: fixedNow)
    let notes = [
        makeNote(title: "Meeting Notes", tags: ["work"], people: ["alice"]),
        makeNote(title: "Personal Journal", tags: ["personal"]),
        makeNote(title: "Work Log", tags: ["work"], scheduledDate: today)
    ]
    let result = NoteSearchEngine.filter(notes, query: "tag:work date:today", now: fixedNow)
    #expect(result.count == 1)
    #expect(result[0].title == "Work Log")
}

// MARK: - Occurrence Tests

@Test func occurrencesInTitle() {
    let notes = [makeNote(title: "Apple released new Apple Watch")]
    let occs = NoteSearchEngine.occurrences(in: notes, query: "apple")
    #expect(occs.count == 2)
    #expect(occs[0].field == .title)
    #expect(occs[1].field == .title)
}

@Test func occurrencesInTitleAndBody() {
    let notes = [makeNote(title: "Apple Event", body: "Apple announced new products")]
    let occs = NoteSearchEngine.occurrences(in: notes, query: "apple")
    // Title hits come first, then body hits
    #expect(occs.count == 2)
    #expect(occs[0].field == .title)
    #expect(occs[1].field == .body)
}

@Test func occurrencesAcrossMultipleNotes() {
    let notes = [
        makeNote(title: "Apple Notes"),
        makeNote(title: "Google Docs")
    ]
    let occs = NoteSearchEngine.occurrences(in: notes, query: "apple")
    #expect(occs.count == 1)
    #expect(occs[0].noteTitle == "Apple Notes")
    #expect(occs[0].globalIndex == 0)
}

@Test func occurrencesEmptyForStructuralOnlyQuery() {
    let notes = [makeNote(title: "有任务", hasTasks: true)]
    let occs = NoteSearchEngine.occurrences(in: notes, query: "has:tasks")
    #expect(occs.isEmpty)
}

@Test func occurrencesRespectFieldScope() {
    let notes = [makeNote(title: "Apple Event", body: "Apple announced")]
    let occs = NoteSearchEngine.occurrences(in: notes, query: "title:apple")
    #expect(occs.count == 1)
    #expect(occs[0].field == .title)
}

// MARK: - highlightText Tests

@Test func highlightTextExtractsPositiveTerms() {
    let text = NoteSearchEngine.highlightText(for: "apple banana")
    #expect(text == "apple banana")
}

@Test func highlightTextExcludesSyntax() {
    let text = NoteSearchEngine.highlightText(for: "tag:work apple has:tasks")
    #expect(text == "apple")
}

@Test func highlightTextEmptyForStructuralOnly() {
    let text = NoteSearchEngine.highlightText(for: "has:tasks is:starred date:today")
    #expect(text.isEmpty)
}

@Test func highlightTextExcludesNegatedTerms() {
    let text = NoteSearchEngine.highlightText(for: "apple -rotten")
    #expect(text == "apple")
}

@Test func highlightTextDeduplicatesTerms() {
    let text = NoteSearchEngine.highlightText(for: "apple apple")
    #expect(text == "apple")
}

// MARK: - mergedQuery Tests

@Test func mergedQueryCombinesSavedAndTransient() {
    let query = NoteSearchEngine.mergedQuery(savedQuery: "tag:work", transientText: "重要")
    let note1 = makeNote(title: "重要会议", tags: ["work"])
    let note2 = makeNote(title: "重要会议", tags: ["personal"])
    let note3 = makeNote(title: "普通会议", tags: ["work"])
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
    #expect(!NoteSearchEngine.matches(note3, query: query))
}

@Test func mergedQueryWithOnlySaved() {
    let query = NoteSearchEngine.mergedQuery(savedQuery: "tag:work", transientText: "")
    let note = makeNote(title: "会议", tags: ["work"])
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func mergedQueryWithOnlyTransient() {
    let query = NoteSearchEngine.mergedQuery(savedQuery: nil, transientText: "apple")
    let note = makeNote(title: "Apple")
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func mergedQueryBothEmpty() {
    let query = NoteSearchEngine.mergedQuery(savedQuery: "", transientText: "")
    #expect(query.isEmpty)
}

// MARK: - Case Insensitivity Tests

@Test func caseInsensitiveText() {
    let query = NoteSearchEngine.parse("APPLE")
    let note = makeNote(title: "apple")
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func caseInsensitiveTag() {
    let query = NoteSearchEngine.parse("tag:WORK")
    let note = makeNote(title: "test", tags: ["work"])
    #expect(NoteSearchEngine.matches(note, query: query))
}

// MARK: - Backward Compatibility Tests

@Test func backwardCompatTagSyntax() {
    let query = NoteSearchEngine.parse("tag:MVP")
    let note = makeNote(title: "计划", tags: ["MVP"])
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func backwardCompatPersonSyntax() {
    let query = NoteSearchEngine.parse("person:alice")
    let note = makeNote(title: "讨论", people: ["alice"])
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func backwardCompatStatusSyntax() {
    let query = NoteSearchEngine.parse("status:open")
    let note = makeNote(title: "测试", status: .open)
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func backwardCompatHasTasks() {
    let query = NoteSearchEngine.parse("has:tasks")
    let note = makeNote(title: "待办", hasTasks: true)
    #expect(NoteSearchEngine.matches(note, query: query))
    // No highlight terms for structural query
    #expect(query.highlightTerms.isEmpty)
}

@Test func backwardCompatIsFocused() {
    let query = NoteSearchEngine.parse("is:focused")
    let note = makeNote(title: "关注", isFocused: true)
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func backwardCompatIsStarred() {
    let query = NoteSearchEngine.parse("is:starred")
    let note = makeNote(title: "星标", isStarred: true)
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func backwardCompatIsBrief() {
    let query = NoteSearchEngine.parse("is:brief")
    let note = makeNote(title: "简达", isBrief: true)
    #expect(NoteSearchEngine.matches(note, query: query))
}

@Test func backwardCompatDateToday() {
    let query = NoteSearchEngine.parse("date:today")
    let today = Calendar.current.startOfDay(for: fixedNow)
    let note = makeNote(title: "今天", scheduledDate: today)
    #expect(NoteSearchEngine.matches(note, query: query, now: fixedNow))
}

@Test func backwardCompatDateUpcoming() {
    let query = NoteSearchEngine.parse("date:upcoming")
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: fixedNow))!
    let note = makeNote(title: "明天", scheduledDate: tomorrow)
    #expect(NoteSearchEngine.matches(note, query: query, now: fixedNow))
}

// MARK: - Mixed Query Tests

@Test func mixedTextAndStructural() {
    let query = NoteSearchEngine.parse("apple tag:work")
    let note1 = makeNote(title: "Apple Meeting", tags: ["work"])
    let note2 = makeNote(title: "Apple Meeting", tags: ["personal"])
    let note3 = makeNote(title: "Google Meeting", tags: ["work"])
    #expect(NoteSearchEngine.matches(note1, query: query))
    #expect(!NoteSearchEngine.matches(note2, query: query))
    #expect(!NoteSearchEngine.matches(note3, query: query))
}

@Test func mixedWithHighlightTerms() {
    let query = NoteSearchEngine.parse("apple tag:work has:tasks")
    // Only "apple" should be a highlight term
    #expect(query.highlightTerms.count == 1)
    #expect(query.highlightTerms[0].value == "apple")
}
