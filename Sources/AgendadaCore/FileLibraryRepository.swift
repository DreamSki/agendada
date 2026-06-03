import Foundation

public actor FileLibraryRepository {
    public let fileURL: URL

    private var libraryDirectory: URL { fileURL.deletingLastPathComponent() }
    private var assetsDirectory: URL { libraryDirectory.appending(path: "Assets") }

    public init(fileURL: URL = FileLibraryRepository.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL.appending(path: "Agendada").appending(path: "Library.json")
    }

    public func load() async throws -> LibrarySnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LibrarySnapshot.self, from: data)
    }

    public func save(_ snapshot: LibrarySnapshot) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        // Phase 1: Write new content to a temporary file first.
        // This ensures we never corrupt the main file on encoding errors.
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: [.atomic])

        // Phase 2: Create a backup of the current file before replacing it.
        // Use copyItem (not replaceItemAt) to avoid deleting the main file.
        // A crash between Phase 1 and Phase 3 must never leave fileURL missing.
        if fileExists {
            let backupURL = fileURL.deletingPathExtension().appendingPathExtension("previous.json")
            // Remove old backup first (best-effort).
            try? FileManager.default.removeItem(at: backupURL)
            do {
                try FileManager.default.copyItem(at: fileURL, to: backupURL)
            } catch {
                // Backup failure is non-fatal — the temp file is valid,
                // so the save can still succeed.  Log and continue.
                print("[FileRepository] warning: failed to create backup: \(error.localizedDescription)")
            }
        }

        // Phase 3: Atomically replace the main file with the temporary file.
        // replaceItemAt is safe here because tempURL is the *source* — if it
        // fails, tempURL still holds the valid data and fileURL is untouched.
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
    }

    // MARK: - Asset GC

    public func collectGarbage(in snapshot: LibrarySnapshot) async {
        let fm = FileManager.default
        guard fm.fileExists(atPath: assetsDirectory.path) else {
            print("[AssetGC] no Assets directory, skipping")
            return
        }

        guard let onDisk = try? fm.contentsOfDirectory(atPath: assetsDirectory.path) else { return }
        guard !onDisk.isEmpty else {
            print("[AssetGC] Assets directory empty, skipping")
            return
        }

        let referenced = referencedAssetNames(in: snapshot)
        print("[AssetGC] \(onDisk.count) on disk, \(referenced.count) referenced in \(snapshot.notes.count) notes")

        if referenced.isEmpty && !onDisk.isEmpty {
            print("[AssetGC] ⚠️ no references found but \(onDisk.count) files on disk — skipping GC for safety")
            return
        }

        var removed = 0
        for file in onDisk {
            if referenced.contains(file) { continue }
            let url = assetsDirectory.appending(path: file)
            do {
                try fm.removeItem(at: url)
                removed += 1
            } catch {
                print("[AssetGC] failed to remove \(file): \(error)")
            }
        }
        if removed > 0 {
            print("[AssetGC] removed \(removed) orphaned asset(s), \(referenced.count) referenced, \(onDisk.count) were on disk")
        }
    }

    private func referencedAssetNames(in snapshot: LibrarySnapshot) -> Set<String> {
        var names = Set<String>()
        for note in snapshot.notes {
            let raw = String(data: note.blockJSON, encoding: .utf8) ?? ""

            if let blocks = try? JSONDecoder().decode([BlockRef].self, from: note.blockJSON) {
                for block in blocks {
                    names.formUnion(collectImageNames(from: block))
                }
            }

            // Always run string-scan fallback too, since blockJSON format may vary
            names.formUnion(extractAssetNames(from: raw))
        }
        return names
    }

    private func collectImageNames(from block: BlockRef) -> Set<String> {
        var names = Set<String>()
        if let url = block.imageURL, let name = url.split(separator: "/").last.map(String.init) {
            names.insert(name.removingPercentEncoding ?? name)
        }
        for child in block.children ?? [] {
            names.formUnion(collectImageNames(from: child))
        }
        return names
    }

    private func extractAssetNames(from raw: String) -> Set<String> {
        var names = Set<String>()
        let pattern = #"Assets/([^"]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return names }
        let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
        for m in matches {
            if let range = Range(m.range(at: 1), in: raw) {
                let encoded = String(raw[range])
                names.insert(encoded.removingPercentEncoding ?? encoded)
            }
        }
        return names
    }
}

/// Minimal decodable for scanning image URLs in blockJSON.
private struct BlockRef: Decodable {
    let type: String?
    let props: PropsRef?
    let children: [BlockRef]?

    var imageURL: String? {
        guard type == "image" else { return nil }
        return props?.url
    }

    struct PropsRef: Decodable {
        let url: String?
    }
}
