//
//  IdentifierPath.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/19/20.
//

import PathKit

// An IdentifierPath represents a path of Swift identifiers, separated by dots.
// This lets us treat file system paths as enums inside enums.
final class IdentifierPath {
    let components: [Identifier]
    
    let parent: IdentifierPath?
    let lastComponent: Identifier?
    
    init(_ components: [Identifier]) {
        self.components = components
        
        if !components.isEmpty {
            self.parent = IdentifierPath(components.dropLast())
        } else {
            self.parent = nil
        }
        
        self.lastComponent = components.last
    }
    
    convenience init(from path: Path, useUnderscores: Bool = true) {
        self.init(path.components.map({ Identifier(from: $0, useUnderscores: useUnderscores) }))
    }
    
    static func + (lhs: IdentifierPath, rhs: IdentifierPath) -> IdentifierPath {
        return IdentifierPath(lhs.components + rhs.components)
    }
}

extension IdentifierPath: Hashable {
    static func == (lhs: IdentifierPath, rhs: IdentifierPath) -> Bool {
        return lhs.components == rhs.components
    }
    func hash(into hasher: inout Hasher) {
        components.hash(into: &hasher)
    }
}

extension IdentifierPath: CustomStringConvertible {
    var description: String {
        components.map(\.description).joined(separator: ".")
    }
}

extension IdentifierPath: ExpressibleByArrayLiteral {
    convenience init(arrayLiteral elements: Identifier...) {
        self.init(elements)
    }
}
