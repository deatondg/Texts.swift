//
//  Utility.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/18/20.
//

import ArgumentParser
import PathKit
import Stencil

extension Path: ExpressibleByArgument {
    public init(argument: String) {
        self.init(argument)
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
