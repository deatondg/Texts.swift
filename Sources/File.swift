//
//  File.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/19/20.
//

import Foundation
import PathKit

// A file wraps a path to a file.
// It contains a path, a corresponding IdentifierPath for usage in Swift source,
//  the contents of the file, and how many #'s the contents need to be escaped as a raw string.
class File {
    let path: Path
    let identifierPath: IdentifierPath
    
    let parent: IdentifierPath
    let name: Identifier
    
    let contents: String
    
    let escapes: String
    
    init(path: Path, useUnderscores: Bool = true, identifierPathPrefix: IdentifierPath = IdentifierPath()) throws {
        self.path = path
        self.identifierPath = identifierPathPrefix + IdentifierPath(from: path)
        
        guard let parent = self.identifierPath.parent,
              let name = self.identifierPath.lastComponent else {
            throw RuntimeError("File.init: Path \(path) has identifier path \(identifierPath) which is too short to refer to a file.")
        }
        self.parent = parent
        self.name = name
        
        self.contents = try path.read()
        
        self.escapes = String(repeating: "#", count: try File.escapes(for: contents))
    }
    
    static var _escapeRegex: NSRegularExpression?
    static func escapeRegex() throws -> NSRegularExpression {
        if let escapeRegex = _escapeRegex {
            return escapeRegex
        } else {
            let escapeRegex = try NSRegularExpression(pattern: ##"("#*)|(#*")|(\\#*)"##)
            _escapeRegex = escapeRegex
            return escapeRegex
        }
    }
    static func escapes(for string: String) throws -> Int {
        let escapeRegex = try File.escapeRegex()
        let matches = escapeRegex.matches(in: string, range: NSRange(location: 0, length: string.count))
        return matches.reduce(0, { max($0, $1.range.length) })
    }
}
