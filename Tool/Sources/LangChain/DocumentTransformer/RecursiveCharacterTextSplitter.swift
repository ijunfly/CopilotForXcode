import Foundation

public class RecursiveCharacterTextSplitter: TextSplitter {
    /**
     Implementation of splitting text that looks at characters.
     Recursively tries to split by different characters to find one that works.
     */
    public var separators: [String]
    public var chunkSize: Int
    public var chunkOverlap: Int
    public var lengthFunction: (String) -> Int

    public init(
        separators: [String] = ["\n\n", "\n", " ", ""],
        chunkSize: Int = 4000,
        chunkOverlap: Int = 200,
        lengthFunction: @escaping (String) -> Int = { $0.count }
    ) {
        assert(chunkOverlap <= chunkSize)
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.lengthFunction = lengthFunction
        self.separators = separators
    }

    public init(
        separatorSet: TextSplitterSeparatorSet,
        chunkSize: Int = 4000,
        chunkOverlap: Int = 200,
        lengthFunction: @escaping (String) -> Int = { $0.count }
    ) {
        assert(chunkOverlap <= chunkSize)
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
        self.lengthFunction = lengthFunction
        separators = separatorSet.separators
    }

    public func split(text: String) async throws -> [String] {
        return split(text: text, separators: separators)
    }

    private func split(text: String, separators: [String]) -> [String] {
        var finalChunks = [String]()

        // Get appropriate separator to use
        let firstSeparatorIndex = separators.firstIndex {
            let pattern = "(\($0))"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text)
            ) != nil
        }
        var separator: String
        var nextSeparators: [String]
        
        if let index = firstSeparatorIndex {
            separator = separators[index]
            if index < separators.endIndex - 1 {
                nextSeparators = Array(separators[(index + 1)...])
            } else {
                nextSeparators = []
            }
        } else {
            separator = ""
            nextSeparators = []
        }

        let splits = split(text: text, separator: separator)

        // Now go merging things, recursively splitting longer texts.
        var goodSplits = [String]()
        for s in splits {
            if lengthFunction(s) < chunkSize {
                goodSplits.append(s)
            } else {
                if !goodSplits.isEmpty {
                    let mergedText = mergeSplits(goodSplits)
                    finalChunks.append(contentsOf: mergedText)
                    goodSplits.removeAll()
                }
                if nextSeparators.isEmpty {
                    finalChunks.append(s)
                } else {
                    let other_info = split(text: s, separators: nextSeparators)
                    finalChunks.append(contentsOf: other_info)
                }
            }
        }
        if !goodSplits.isEmpty {
            let merged_text = mergeSplits(goodSplits)
            finalChunks.append(contentsOf: merged_text)
        }
        return finalChunks
    }
}

