import Foundation

public struct LibrarySnapshot: Codable, Equatable {
    public var categories: [ProjectCategory]
    public var projects: [Project]
    public var notes: [Note]
    public var smartOverviews: [SmartOverview]
    public var selectedProjectID: Project.ID?
    public var selectedOverview: Overview?
    public var selectedSmartOverviewID: SmartOverview.ID?
    public var selectedNoteID: Note.ID?
    public var searchText: String
    public var sortOrder: NoteSortOrder

    public init(
        categories: [ProjectCategory],
        projects: [Project],
        notes: [Note],
        smartOverviews: [SmartOverview] = [],
        selectedProjectID: Project.ID?,
        selectedOverview: Overview?,
        selectedSmartOverviewID: SmartOverview.ID? = nil,
        selectedNoteID: Note.ID?,
        searchText: String,
        sortOrder: NoteSortOrder = .scheduledDateDesc
    ) {
        self.categories = categories
        self.projects = projects
        self.notes = notes
        self.smartOverviews = smartOverviews
        self.selectedProjectID = selectedProjectID
        self.selectedOverview = selectedOverview
        self.selectedSmartOverviewID = selectedSmartOverviewID
        self.selectedNoteID = selectedNoteID
        self.searchText = searchText
        self.sortOrder = sortOrder
    }

    private enum CodingKeys: String, CodingKey {
        case categories, projects, notes, smartOverviews
        case selectedProjectID, selectedOverview, selectedSmartOverviewID
        case selectedNoteID, searchText, sortOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decode([ProjectCategory].self, forKey: .categories)
        projects = try container.decode([Project].self, forKey: .projects)
        notes = try container.decode([Note].self, forKey: .notes)
        smartOverviews = try container.decodeIfPresent([SmartOverview].self, forKey: .smartOverviews) ?? []
        selectedProjectID = try container.decodeIfPresent(Project.ID.self, forKey: .selectedProjectID)
        selectedOverview = try container.decodeIfPresent(Overview.self, forKey: .selectedOverview)
        selectedSmartOverviewID = try container.decodeIfPresent(SmartOverview.ID.self, forKey: .selectedSmartOverviewID)
        selectedNoteID = try container.decodeIfPresent(Note.ID.self, forKey: .selectedNoteID)
        searchText = try container.decodeIfPresent(String.self, forKey: .searchText) ?? ""
        sortOrder = try container.decodeIfPresent(NoteSortOrder.self, forKey: .sortOrder) ?? .scheduledDateDesc
    }
}
