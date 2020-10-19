//
//  main.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/18/20.
//

import Foundation
import ArgumentParser
import PathKit
import Stencil

struct Texts_swift: ParsableCommand {
    static let version = "0.0.1"
    
    static let configuration = CommandConfiguration(commandName: "texts-swift",
                                                    abstract: "A utility to generate Swift sources for text files.",
                                                    version: version)
    
    @Flag(name: .short, help: """
    Resource directories should be scanned recursively.
    """)
    var recursive: Bool = false
    
    @Option(help: """
    A directory which input and output paths will be treated relative to. \
    Specifying this directory helps with generating compact names. \
    This defaults to the current working directory.
    """)
    var root: Path = Path.current
    
    @Option(name: .shortAndLong, help: """
    The name of the Swift enum which will contain the results of the conversion.
    """)
    var enumName: String = "Texts"
    
    @Argument(help: """
    A list of files and directories to be converted to Swift sources.
    """)
    var resources: [Path]
    
    @Flag(help: """
    File paths are transformed into Swift indentifiers by replacing illegal characters with underscores. This flag changes the behavior to simply ignore the illegal characters.
    """)
    var supressUnderscores: Bool = false
    
    @Option(name: .shortAndLong, help: """
    The directory to output the generated Swift sources.
    """)
    var outputDirectory: Path
    
    func validate() throws {
        guard root.isDirectory else {
            throw ValidationError("'\(root)' is invalid for '<root>'. '<root>' must be a directory.")
        }
    }
    
    func run() throws {
        try root.chdir {
            let files = Set(try resources
                                        .flatMap({ resource -> [Path] in
                                            if resource.isDirectory {
                                                return try resource.recursiveChildren()
                                            } else {
                                                return [resource]
                                            }
                                        })
                                        .filter({
                                            $0.isFile
                                        })
                                        .map({
                                            $0.normalize()
                                        })
                                )
            
            var directories: Set<Path> = []
            for file in files {
                var directory = Path()
                for component in file.components.dropLast() {
                    directory = directory + component
                    directories.update(with: directory)
                }
            }
            
            let rootIdentifier = Identifier(from: enumName)
            
            let fileIdentifiers = try files.map({ try File(path: $0) })
            let directoryIdentifiers = directories.map({ [rootIdentifier] + IdentifierPath(from: $0) })
            
            let output = try template.render([
                "version": Texts_swift.version,
                "files": fileIdentifiers,
                "directories": directoryIdentifiers,
                "enumName": rootIdentifier
            ])
            
            try (outputDirectory + "Texts.generated.swift").write(output)
        }
    }
}

Texts_swift.main(#"-r --root /Users/davisdeaton/Developer/Projects/Texts.swift Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated"#.split(separator: " ").map(String.init))
//Texts_swift.main("--root /Users/davisdeaton/Developer/Projects/Texts.swift/ Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated".split(separator: " ").map(String.init))
