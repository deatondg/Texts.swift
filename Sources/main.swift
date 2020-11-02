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
    
    @Option(name: .customLong("source-root"), help: """
    A directory which _all_ path arguments will be treated relative to. \
    This can only be specified without an Xcode project. \
    If a project is specified, the directory of the Xcode project will be used. \
    (default: The directory of the Xcode project if specified, and the current working directory otherwise)
    """)
    var rootPath: Path?
    
    @Option(name: .customLong("xcode-project"), help: """
    The path to an Xcode project to link the generated files to. \
    This project is _not_ scanned for resource files.
    """)
    var xcodeProject: Path?
    
    @Option(name: .customLong("target"), help: """
    The name of the Xcode target to link the generated files to. \
    Must be specified if an Xcode project is specified. \
    It is an error to supply this argument without an Xcode project.
    """)
    var targetName: String?
    
    @Option(name: .customLong("group"), help: """
    The name of the Xcode group to link the generated files to. \
    It is an error to supply this argument without an Xcode Project. \
    This string is checked against both the name and paths of the Xcode groups. \
    If unspecified, the root group is used.
    """)
    var groupName: String?
    
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
        
        // Verify that the specified Xcode project exists and create the relevant data.
        let xcode: (path: Path, project: XcodeProj, target: PBXTarget, group: PBXGroup)?
        if let xcodeProject = xcodeProject {
            // Make sure a target is specified along with the project
            guard let targetName = targetName else {
                throw ValidationError("<xcode-project> specified without a target.")
            }
            
            let project: XcodeProj
            do {
                project = try XcodeProj(path: xcodeProject)
            } catch {
                throw ValidationError("Could not open the Xcode project: \(error).")
            }
            
            // Confirm that this project has exactly one target with the specified name.
            let targets = project.pbxproj.targets(named: targetName)
            guard targets.count <= 1 else {
                throw ValidationError("Target name \(targetName) is ambiguous. Do you have multiple targets with this name?")
            }
            guard let target = targets.first else {
                throw ValidationError("Could not find target named \(targetName) in the specified Xcode project.")
            }
            
            // If the group is specified, make sure it exists uniquely.
            let group: PBXGroup
            if let groupName = groupName {
                let groups = project.pbxproj.groups.filter({ ($0.name == groupName) || ($0.path == groupName) })
                guard groups.count <= 1 else {
                    throw ValidationError("Group name \(groupName) is ambiguous. Do you have multiple groups with this name?")
                }
                guard let _group = groups.first else {
                    throw ValidationError("Could not find group named \(groupName) in the specified Xcode Project.")
                }
                group = _group
            } else {
                guard let _group = try project.pbxproj.rootGroup() else {
                    throw ValidationError("Xcode project has no root group. I'm not sure if this is even possible.")
                }
                group = _group
            }
            
            xcode = (xcodeProject, project, target, group)
        } else {
            // Make sure that a target and group are not specified without an Xcode project
            guard targetName == nil else {
                throw ValidationError("<target> specified without an Xcode project.")
            }
            guard groupName == nil else {
                throw ValidationError("<group> specified without an Xcode project.")
            }
            xcode = nil
        }
        
        // Our root path and Xcode project path are entangled.
        let root: Path
        if let xcode = xcode {
            // If an Xcode project is specified, <root> must not be specified.
            guard rootPath == nil else {
                throw ValidationError("<root> cannot be specified along with <xcode-project>.")
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
            throw ValidationError("Specified root is not a directory: \(root)")
        }
        
        // Now, we can chdir into root and correctly treat all paths except xcode.path as relative
        try root.chdir {
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
                for component in file.parent.components {
                    identifierPath = identifierPath + [component]
                    directories.update(with: identifierPath)
                }
            }
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
        } // end root.chdir
        
        // If an Xcode project was specified, link our generated files to it.
        if let (path, project, target, group) = xcode {
            try project.pbxproj.rootProject()!.mainGroup.addGroup(named: "Test", options: GroupAddingOptions.withoutFolder)
            //project.write(path: <#T##Path#>)
            print(try project.pbxproj.rootProject()!.mainGroup!.path)
            
            //print(try project.pbxproj.groups.map({ try ($0.name, $0.fullPath(sourceRoot: ".")) }))
            //print(try project.pbxproj.fileReferences.map({ try $0.path }))
            
            /*
            for file in sourceFiles {
                let outputFiles = group.children.filter({ $0.path == outputPath })
                if outputFiles.count == 0 {
                    
                }
                print(group.children.map({ $0.path }))
                if let xcodeFile = group.file(named: outputName) {
                    print("Here")
                } else {
                    fatalError("Writing to Xcode projects not yet implemented.")
                }
            }
            */
        }
    }
}


//print(Texts_swift.helpMessage())
Texts_swift.main(#"-r --xcode-project /Users/davisdeaton/Developer/Projects/Texts.swift/Texts.swift.xcodeproj --target Texts.swift --group Generated -o Generated Templates"#.split(separator: " ").map(String.init))
//Texts_swift.main(#"-r -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated/"#.split(separator: " ").map(String.init))
//Texts_swift.main(#"-r --root /Users/davisdeaton/Developer/Projects/Texts.swift --xcode-project /Users/davisdeaton/Developer/Projects/Texts.swift/Texts.swift.xcodeproj Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated"#.split(separator: " ").map(String.init))
//Texts_swift.main(#"-r --root /Users/davisdeaton/Developer/Projects/Texts.swift Templates --multiple-files -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated"#.split(separator: " ").map(String.init))
//Texts_swift.main("--root /Users/davisdeaton/Developer/Projects/Texts.swift/ Templates -o /Users/davisdeaton/Developer/Projects/Texts.swift/Generated".split(separator: " ").map(String.init))
