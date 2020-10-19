//
//  File.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/19/20.
//

import Foundation
import PathKit

class File {
    let path: Path
    let identifierPath: IdentifierPath
    
    let parent: IdentifierPath
    let name: Identifier
    
    let contents: String
    
    let escapes: String
    
    init(path: Path) throws {
        self.path = path
        self.identifierPath = IdentifierPath(from: path)
        
        self.parent = self.identifierPath.parent!
        self.name = self.identifierPath.lastComponent!
        
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
