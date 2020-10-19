//
//  IdentifierPath.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/19/20.
//

import PathKit

final class IdentifierPath: CustomStringConvertible, ExpressibleByArrayLiteral {
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
    convenience init(arrayLiteral elements: Identifier...) {
        self.init(elements)
    }
    convenience init(from path: Path, useUnderscores: Bool = true) {
        self.init(path.components.map({ Identifier(from: $0, useUnderscores: useUnderscores) }))
    }
    
    static func + (lhs: IdentifierPath, rhs: IdentifierPath) -> IdentifierPath {
        return IdentifierPath(lhs.components + rhs.components)
    }
    
    var description: String {
        components.map(\.description).joined(separator: ".")
    }
}
