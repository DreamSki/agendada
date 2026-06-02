import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Transferable payload for drag-and-drop operations on notes.
/// Carries Note.ID across drag sessions within Agendada.
public struct DragPayload: Transferable, Codable {
	public let noteID: Note.ID

	public init(noteID: Note.ID) {
		self.noteID = noteID
	}

	public static var transferRepresentation: some TransferRepresentation {
		DataRepresentation(contentType: .utf8PlainText) { payload in
			payload.encode() ?? Data()
		} importing: { data in
			guard let payload = DragPayload.decode(from: data) else {
				throw DragPayloadError.invalidData
			}
			return payload
		}
	}

	public func encode() -> Data? {
		try? JSONEncoder().encode(self)
	}

	public static func decode(from data: Data) -> DragPayload? {
		try? JSONDecoder().decode(DragPayload.self, from: data)
	}

	public enum DragPayloadError: Error {
		case invalidData
	}
}
