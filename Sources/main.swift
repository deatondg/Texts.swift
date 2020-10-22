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
import XcodeProj

struct Texts_swift: ParsableCommand {
    static let version = "0.0.1"
    
    static let configuration = CommandConfiguration(commandName: "texts-swift",
                                                    abstract: "A utility to generate Swift sources mirror the contents of text files as strings.",
                                                    version: version)
    
    @Flag(name: .shortAndLong, help: """
    Resource directories should be scanned recursively.
    """)
    var recursive: Bool = false
    
    @Flag(inversion: FlagInversion.prefixedEnableDisable, help: """
    File paths are transformed into Swift indentifiers by either replacing illegal characters with underscores or simply ignoring them.
    """)
    var underscoreReplacement: Bool = true
    
    @Flag(help: """
    Creates a .generated.swift file for each resource file. \
    In this mode, an additional .generated.swift will still be created to house the directory structure.
    """)
    var multipleFiles: Bool = false
    
    @Option(help: """
    The name of the Swift enum which will contain the results of the conversion. \
    This will be converted into a valid Swift identifier automatically.
    """)
    var enumName: String = "Texts"
    
    @Option(name: .customLong("root"), help: """
    A directory which _all_ path arguments will be treated relative to. \
    Specifying this directory helps with generating compact names. \
    (default: The directory of the Xcode project if specified, and the current working directory otherwise)
    """)
    var rootPath: Path?
    
    @Option(name: .customLong("xcode-project"), help: """
    The path to an Xcode project to link the generated files to. \
    This project is _not_ scanned for resource files.
    """)
    var xcodeProject: Path?
    
    @Option(name: [.short, .customLong("output")], help: """
    A file or directory to which the generated Swift sources will be written. \
    In single-file mode, if this is a file, all generated content will be written to this file. \
    If this is a directory, all generated content will be written to <output>/<enum-name>.generated.swift. \
    In multiple-file mode, if this is a file, the Swift source corresponding to the directory information will be written to this file, and the files for each resource will be written to the directory of this file. \
    If this is a directory, all files will be written to this directory, and the directory structure will be written to <output>/<enum-name>.generated.swift \
    (default: <root>)
    """)
    var outputPath: Path?
    
    @Argument(help: """
    A list of files and directories to be converted to Swift sources.
    """)
    var resources: [Path] = []
    
    func run() throws {
        /* Additional Parsing */
        // The parsing of the enumName depends on whether or not underscores should be replaced,
        //      so we do that here, instead of in a transform.
        let rootIdentifier = Identifier(from: enumName, useUnderscores: underscoreReplacement)
        
        /* end Additional Parsing */
        
        /* Validation */
        // We could put this in the validate method(), but we'd have to do some of the same work again anyway.
        
        // Our root path and Xcode project path are entangled.
        let root: Path
        let xcodeProjectPath: Path?
        if let rootPath = rootPath {
            // If <root> is specified, then it is the root, and <xcode-project> is relative to it.
            root = rootPath
            xcodeProjectPath = xcodeProject
        } else if let xcodeProject = xcodeProject {
            // Otherwise, if <xcode-project> is specified, then its directory is root
            root = xcodeProject.parent()
            // In this case <xcode-project> is the only path relative to cwd rather than <root> (its parent)
            xcodeProjectPath = Path(".") + xcodeProject.lastComponent
        } else {
            // Otherwise, the root is cwd, and everything is relative to cwd
            root = Path.current
            xcodeProjectPath = xcodeProject
        }
        // Whatever root we decide upon, it better be a directory
        guard root.isDirectory else {
            throw ValidationError("Specified root is not a directory: \(root)")
        }
        
        // Now, we can chdir into root and correctly treat all paths as relative
        try root.chdir {
            
            // Create an XcodeProj from the xcodeProjectPath we decided upon
            let xcodeProj: XcodeProj?
            if let xcodeProjectPath = xcodeProjectPath {
                do {
                    xcodeProj = try XcodeProj(path: xcodeProjectPath)
                } catch {
                    throw ValidationError("Could not open the Xcode project: \(error)")
                }
            } else {
                xcodeProj = nil
            }
            // xcodeProj == nil <=> xcodeProjectPath == nil <=> xcodeProject == nil
            
            // Decide where we're going to output things.
            let outputDirectory: Path
            let outputName: String
            if let outputPath = outputPath {
                if outputPath.isDirectory {
                    outputDirectory = outputPath
                    outputName = "\(rootIdentifier).generated.swift"
                } else {
                    outputDirectory = outputPath.parent()
                    outputName = outputPath.lastComponent
                }
            } else {
                outputDirectory = root
                outputName = "\(rootIdentifier).generated.swift"
            }
            guard outputDirectory.isDirectory else {
                throw ValidationError("Specified output directory is not a directory: \(outputDirectory)")
            }
            
            // Make sure that all the resources we'll be reading from actually exist
            for resource in resources {
                guard resource.exists else {
                    throw ValidationError("Specified resource does not exist: \(resource)")
                }
            }
                
            /* end Validation */

            // Parse the resources into a set of normalized paths.
            let filePaths = Set(try resources.flatMap({ resource -> [Path] in
                    if resource.isDirectory {
                        if recursive {
                            return try resource.recursiveChildren()
                        } else {
                            return try resource.children()
                        }
                    } else {
                        return [resource]
                    }
                })
                .filter({ $0.isFile })
                .map({ $0.normalize() })
            )
            
            // Read these resource files into File objects
            let files = try filePaths.map({ try File(path: $0, useUnderscores: underscoreReplacement, identifierPathPrefix: [rootIdentifier]) })
            
            // Make sure that no two files have the same identifier path.
            guard Set(files.map(\.identifierPath)).count == files.count else {
                for file1 in files {
                    for file2 in files {
                        guard file1.identifierPath != file2.identifierPath else {
                            throw ValidationError("Two file paths were mapped to the same Swift identifier: \(file1.path) and \(file2.path) both map to \(file1.identifierPath)")
                        }
                    }
                }
                throw ValidationError("Two file paths we mapped to the same Swift identifier, but we couldn't find which ones. Weird.")
            }
            
            // Create the set of all IdentifierPaths we will need to represent these Files.
            // This will be the set of recursive grandparents of each File's IdentifierPath.
            var directories: Set<IdentifierPath> = []
            for file in files {
                var identifierPath = IdentifierPath()
                for component in file.identifierPath.components {
                    identifierPath = identifierPath + [component]
                    directories.update(with: identifierPath)
                }
            }
            directories.remove([rootIdentifier])
            
            if multipleFiles {
                fatalError("Multiple files not yet implemented.")
            }
            
            let outputString = try Template(templateString: Texts.Templates.Texts_swifttemplate).render([
                "version": Texts_swift.version,
                "files": files.sorted(by: { $0.identifierPath.description < $1.identifierPath.description }),
                "directories": directories.sorted(by: { $0.description < $1.description }),
                "rootIdentifier": rootIdentifier
            ])
            
            try (outputDirectory + outputName).write(outputString)
            
            if xcodeProj != nil {
                fatalError("Writing to Xcode projects not yet implemented.")
            }
        }
    }
}


//print(Texts_swift.helpMessage())
//Texts_swift.main(#"-r -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated/"#.split(separator: " ").map(String.init))
//Texts_swift.main(#"-r --root /Users/davisdeaton/Developer/Projects/Texts.swift --xcode-project /Users/davisdeaton/Developer/Projects/Texts.swift/Texts.swift.xcodeproj Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated"#.split(separator: " ").map(String.init))
Texts_swift.main(#"-r --root /Users/davisdeaton/Developer/Projects/Texts.swift Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated"#.split(separator: " ").map(String.init))
//Texts_swift.main("--root /Users/davisdeaton/Developer/Projects/Texts.swift/ Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated".split(separator: " ").map(String.init))
