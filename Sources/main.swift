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
    static let version = "1.0.0"
    
    static let configuration = CommandConfiguration(commandName: "texts-swift",
                                                    abstract: "A utility to generate Swift source code mirroring the contents of text files as strings.",
                                                    version: version)
    
    @Flag(name: .shortAndLong, help: """
    Resource directories should be scanned recursively.
    """)
    var recursive: Bool = false
    
    @Flag(inversion: FlagInversion.prefixedEnableDisable, help: """
    File paths are transformed into Swift indentifiers by either replacing illegal characters with underscores or simply ignoring them.
    """)
    var underscoreReplacement: Bool = true
    
    @Flag(help: ArgumentHelp("""
        Create a .generated.swift file for each resource file.
        """,
        discussion: """
        In this mode, <enum-name>.generated.swift will still be created to house the directory structure as an empty Swift enum.
        """)
    )
    var multipleFiles: Bool = false
    
    @Option(help: ArgumentHelp("""
        The name of the Swift enum which will contain the results of the conversion.
        """,
        discussion: """
        This will be converted into a valid Swift identifier automatically according to the specified underscore replacement rule.
        """)
    )
    var enumName: String = "Texts"
    
    @Option(name: .customLong("source-root"), help: ArgumentHelp("""
        A directory which _all_ path arguments will be treated relative to. \
        (default: The directory of the Xcode project if specified, and the current working directory otherwise)
        """,
        discussion: """
        This can only be specified without an Xcode project. \
        If a project is specified, the directory of the Xcode project will be used.
        """,
        valueName: "root")
    )
    var rootPath: Path?
    
    @Option(name: .customLong("xcode-project"), help: ArgumentHelp("""
        The path to an Xcode project to add the generated files to.
        """,
        discussion: """
        This project is _not_ scanned for resource files.
        """,
        valueName: "proj")
    )
    var xcodeProject: Path?
    
    @Option(name: .customLong("target"), help: ArgumentHelp("""
        The name of an Xcode target to link the generated files to.
        """,
        discussion: """
        Multiple targets can be specified. \
        If no target is specified, the added source files will not be linked to any target.
        """)
    )
    var targetNames: [String] = []
    
    @Option(name: [.short, .customLong("output")], help: ArgumentHelp("""
        A file or directory to which the generated Swift sources will be written. \
        (default: <root>)
        """,
        discussion: """
        This is treated as a directory if it ends in a / or if this path exists and is a directory. \
        In single-file mode, if this is a file, all generated content will be written to this file. \
        If this is a directory, all generated content will be written to <output>/<enum-name>.generated.swift. \
        In multiple-file mode, if this is a file, the Swift source corresponding to the directory information will be written to this file, and the files for each resource will be written to the directory of this file. \
        If this is a directory, all files will be written to this directory, and the directory structure will be written to <output>/<enum-name>.generated.swift.
        """)
    )
    var outputString: String?
    
    @Argument(help: """
    A list of files and directories to be converted to Swift sources.
    """)
    var resources: [Path] = []
    
    func run() throws {
        // Keep track of the original working directory.
        let originalWorkingDirectory = Path.current
        
        /* Additional Parsing */
        // The parsing of the enumName depends on whether or not underscores should be replaced,
        //      so we do that here, instead of in a transform.
        let rootIdentifier = Identifier(from: enumName, useUnderscores: underscoreReplacement)
        
        /* end Additional Parsing */
        
        /* Validation */
        // We could put this in the validate method(), but we'd have to do some of the same work again anyway.
        
        // Verify that the specified Xcode project exists and create the relevant data.
        let xcode: (path: Path, project: XcodeProj, sourcesBuildPhases: [PBXSourcesBuildPhase], mainGroup: PBXGroup)?
        if let xcodeProject = xcodeProject {
            let project: XcodeProj
            do {
                project = try XcodeProj(path: xcodeProject)
            } catch {
                throw ValidationError("Could not open the Xcode project: \(error).")
            }
            
            let sourcesBuildPhases = try targetNames.map({ targetName -> PBXSourcesBuildPhase in
                // Confirm that this project has exactly one target with the specified name.
                let targets = project.pbxproj.targets(named: targetName)
                guard targets.count <= 1 else {
                    throw ValidationError("Target name \(targetName) is ambiguous. Do you have multiple targets with this name?")
                }
                guard let target = targets.first else {
                    throw ValidationError("Could not find target named \(targetName) in the specified Xcode project.")
                }
                
                guard let sourcesBuildPhase = try target.sourcesBuildPhase() else {
                    throw ValidationError("Could not find sources build phase for target: \(targetName)")
                }
                                
                return sourcesBuildPhase
            })
            
            // Create the main group
            guard let mainGroup = try project.pbxproj.rootProject()?.mainGroup else {
                throw RuntimeError("Could not create main group for Xcode project: \(xcodeProject).")
            }
            
            xcode = (xcodeProject, project, sourcesBuildPhases, mainGroup)
        } else {
            // Make sure that a target is not specified without an Xcode project
            guard targetNames.isEmpty else {
                throw ValidationError("<target> specified without an Xcode project.")
            }
            xcode = nil
        }
        
        // Our root path and Xcode project path are entangled.
        let root: Path
        if let xcode = xcode {
            // If an Xcode project is specified, <root> must not be specified.
            guard rootPath == nil else {
                throw ValidationError("<root> cannot be specified along with an Xcode project.")
            }
            root = xcode.path.parent()
        } else if let rootPath = rootPath {
            // If no Xcode project is specified, we use the specified root path
            root = rootPath
        } else {
            // If neither an Xcode project or a root are specified, use the current working directory
            root = Path.current
        }
        // Whatever root we decide upon, it better be a directory
        guard root.isDirectory else {
            throw ValidationError("Specified or derived <root> is not a directory: \(root)")
        }
        
        // Now, we can chdir into root and correctly treat all paths except xcode.path as relative
        Path.current = root
        
        // Decide where we're going to output things.
        let outputDirectory: Path
        let outputName: String
        if let outputString = outputString {
            // If an output is specified, turn it into a path
            let outputPath = Path(outputString).normalize()
            // If this path is a directory or ends in a /, treat it as a directory
            if outputPath.isDirectory || outputString.last == "/" {
                outputDirectory = outputPath
                outputName = "\(rootIdentifier).generated.swift"
            } else {
                outputDirectory = outputPath.parent()
                outputName = outputPath.lastComponent
            }
        } else {
            // If no output is specified, just write to root.
            outputDirectory = Path(".")
            outputName = "\(rootIdentifier).generated.swift"
        }
        // Try to create this directory in case it does not exist.
        try outputDirectory.mkpath()
        // Confirm we have succeeded. I'm not sure if this is necessary.
        guard outputDirectory.isDirectory else {
            throw ValidationError("Specified or derived output directory is not a directory: \(outputDirectory)")
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
                    guard file1.path == file2.path || file1.identifierPath != file2.identifierPath else {
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
            for component in file.parent.components {
                identifierPath = identifierPath + [component]
                directories.update(with: identifierPath)
            }
        }
        // In the generated Swift source, each directory is represented as an enum in the scope of the enum of its parent.
        // The path [rootIdentifier] has no parent, so it must be created in the global scope.
        // Therefore, we have to generate its code in a distinct way.
        // Thus, we separate this path out from the others.
        directories.remove([rootIdentifier])
        
        // Generate the source file(s) from our resources.
        let sourceFiles: [SourceFile]
        if !multipleFiles {
            let outputString = try Template(templateString: Texts.Templates.Texts_swifttemplate).render([
                "version": Texts_swift.version,
                "files": files.sorted(by: { $0.identifierPath.description < $1.identifierPath.description }),
                "directories": directories.sorted(by: { $0.description < $1.description }),
                "rootIdentifier": rootIdentifier
            ])
            
            sourceFiles = [SourceFile(name: outputName, contents: outputString)]
        } else {
            let directoryString = try Template(templateString: Texts.Templates.Texts_Directory_swifttemplate).render([
                "version": Texts_swift.version,
                "directories": directories.sorted(by: { $0.description < $1.description }),
                "rootIdentifier": rootIdentifier
            ])
            let directoryFile = SourceFile(name: outputName, contents: directoryString)
            
            let otherFiles = try files.map({ file -> SourceFile in
                let fileString = try Template(templateString: Texts.Templates.Texts_File_swifttemplate).render([
                    "version": Texts_swift.version,
                    "file": file
                ])
                
                return SourceFile(name: "\(file.identifierPath).generated.swift", contents: fileString)
            })
            
            sourceFiles = [directoryFile] + otherFiles
        }
       
        // Write our source files to disk
        for file in sourceFiles {
            try (outputDirectory + file.name).write(file.contents)
        }
        
        // Return to the original working directory to write to the Xcode project
        Path.current = originalWorkingDirectory
        
        // If an Xcode project was specified, link our generated files to it.
        if let (path, project, sourcesBuildPhases, mainGroup) = xcode {
            var shouldWrite = false
            
            // Find the group to add our source files to.
            var group = mainGroup
            for pathComponent in outputDirectory.components {
                let groups = group.children.filter({ $0.sourceTree == .group && $0.path == pathComponent })
                guard groups.count <= 1 else {
                    throw RuntimeError("Xcode group named \(pathComponent) is ambiguous. Is it possible that two groups have the same path? I am honestly not sure.")
                }
                if let childGroup = groups.first as? PBXGroup {
                    group = childGroup
                } else {
                    shouldWrite = true
                    let createdGroups = try group.addGroup(named: pathComponent)
                    guard createdGroups.count <= 1 else {
                        throw RuntimeError("XcodeProj is busted. I tried to create a single group and it created a bunch: \(pathComponent).")
                    }
                    guard let _group = createdGroups.first else {
                        throw RuntimeError("XcodeProj is busted. I tried to create a group and it created none: \(pathComponent).")
                    }
                    group = _group
                }
            }
            let outputGroup = group
            
            // Add files to the project and link them to the target if they do not exist.
            for file in sourceFiles {
                let outputFiles = outputGroup.children.filter(({ $0.path == file.name }))
                if outputFiles.count > 1 {
                    print("Warning: Xcode somehow has two files name \(file.name) in the output group. Ignoring...")
                }
                if outputFiles.isEmpty {
                    shouldWrite = true
                    // Add the file to the group
                    let fileReference = try group.addFile(at: root + outputDirectory + file.name, sourceRoot: root)
                    // Create a corresponding build file and add it to the project
                    let buildFile = PBXBuildFile(file: fileReference, product: nil, settings: nil)
                    project.pbxproj.add(object: buildFile)
                    // Add the build file to each target
                    for sourcesBuildPhase in sourcesBuildPhases {
                        // If the build phase has no file list, create one
                        if sourcesBuildPhase.files == nil {
                            sourcesBuildPhase.files = []
                        }
                        // Add the file to the build phase
                        sourcesBuildPhase.files!.append(buildFile)
                    }
                }
            }
            
            // If we made a change to the Xcode project, write it.
            if shouldWrite {
                try project.writePBXProj(path: path, outputSettings: PBXOutputSettings())
            }
        }
    }
}

Texts_swift.main()
