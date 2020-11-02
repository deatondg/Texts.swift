//
//  Utility.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/18/20.
//

import ArgumentParser
import PathKit
import Stencil

// A class representing a generated source file.
class SourceFile {
    let name: String
    let contents: String
    
    init(name: String, contents: String) {
        self.name = name
        self.contents = contents
    }
}

extension Path: ExpressibleByArgument {
    public init(argument: String) {
        self = Path(argument).normalize()
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    var description: String
    
    init(_ description: String) {
        self.description = description
    }
}
struct ValidationError: Error, CustomStringConvertible {
    var description: String
    
    init(_ description: String) {
        self.description = description
    }
}
