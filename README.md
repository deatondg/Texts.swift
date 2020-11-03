**Texts.swift** is like `xxd -i` but for including text files in Swift source code.

## Overview

Texts.swift generates Swift source code mirroring the contents of text files as strings.
Users run the utility `texts-swift` either manually or in a custom build phase, supplying it with resources, perhaps
```
Templates/Texts_Directory.swifttemplate
Templates/Texts_File.swifttemplate
Templates/Texts.swifttemplate
```
to convert into a Swift source file looking something like
```swift
// Generated using Texts.swift 0.0.1 by Davis Deaton
// DO NOT EDIT
enum Texts {}

extension Texts { enum Templates {} }

extension Texts.Templates {
    static let Texts_Directory_swifttemplate: String = """
<the contents of Texts_Directory.swifttemplate>
"""
}

extension Texts.Templates {
    static let Texts_File_swifttemplate: String = #"""
<the contents of Texts_File.swifttemplate>
"""#
}

extension Texts.Templates {
    static let Texts_swifttemplate: String = #"""
<the contents of Texts.swifttemplate>
"""#
}
```
so that the contents of `Templates/Texts.swifttemplate` can be used within Swift as `Texts.Templates.Texts_swifttemplate`.
This is in fact the structure of the Stencil template resources used Texts.swift.

## Why?

Mac and iOS apps are almost always distributed as folders.
Thus, they can use `Bundle.main` to access their resources with high confidence that these resources have been correctly installed with them.
Tools like [R.swift](https://github.com/mac-cain13/R.swift) even autogenerate type-safe wrappers for these resources, avoiding errors from typos and the link.
However, command line tools do not have the same luxury.
It is simply much more convenient if such tools can ship as single executables.

For certain tools, in particular those which generate source code, the only required resources are relatively short text files, meaning they can be included directly into the executable as a static string.
This results in an executable with no dependencies, but has some downsides.
In particular, including text tiles directly into Swift source makes it more difficult to apply syntax highlighting or static analysis tools to the text resources, which can result in programmer error.
Thus, the trade-off is between ease of development and ease of installation.

Texts.swift addresses this issue by providing a utility to convert plain text resources into Swift source code, accounting for esacapes and filenames which are invalid Swift identifiers. 

## Usage

Texts.swift provides the command line utility `texts-swift`.
Either run it manually or in a custom build phase as 
```
texts-swift [--recursive] [--enable-underscore-replacement] [--disable-underscore-replacement] \
	[--multiple-files] [--enum-name <enum-name>] [--source-root <root>] \
	[--xcode-project <proj>] [--target <target> ...] \
	[--output <output>] [<resources> ...]
```

### Options
- `-r, --recursive` - Resource directories should be scanned recursively.
- `--enable-underscore-replacement/--disable-underscore-replacement` - File paths are transformed into Swift indentifiers by either replacing illegal characters with underscores or simply ignoring them. (default: `true`)
- `--multiple-files` Create a `.generated.swift` file for each resource file. 
In this mode, `<enum-name>.generated.swift` will still be created to house the directory structure as an empty Swift enum.
- `--enum-name <enum-name>` - The name of the Swift enum which will contain the results of the conversion. (default: `Texts`)
	This will be converted into a valid Swift identifier automatically according to the specified underscore replacement rule.
- `--source-root <root>` - A directory which _all_ path arguments will be treated relative to. (default: The directory of the Xcode project if specified, and the current working directory otherwise) 
	This can only be specified without an Xcode project. If a project is specified, the directory of the Xcode project will be used.
- `--xcode-project <proj>` - The path to an Xcode project to add the generated files to. 
	This project is _not_ scanned for resource files.
- `--target <target>` - The name of an Xcode target to link the generated files to. 
	Multiple targets can be specified. If no target is specified, the added source files will not be linked to any target.
- `-o, --output <output>` - A file or directory to which the generated Swift sources will be written. (default: `<root>`) 
	This is treated as a directory if it ends in a `/` or if this path exists and is a directory. 
	In single-file mode, if this is a file, all generated content will be written to this file. 
	If this is a directory, all generated content will be written to `<output>/<enum-name>.generated.swift`. 
	In multiple-file mode, if this is a file, the Swift source corresponding to the directory information will be written to this file, and the files for each resource will be written to the directory of this file. 
	If this is a directory, all files will be written to this directory, and the directory structure will be written to `<output>/<enum-name>.generated.swift`.
- `--version` - Show the version.
- `-h, --help` - Show help information.
 
### Arguments
- `<resources>` - A list of files and directories to be converted to Swift sources. 

## Attributions

This tool is powered by

- [Stencil](https://github.com/kylef/Stencil) and [PathKit](https://github.com/kylef/PathKit) by [Kyle Fuller](https://github.com/kylef)
- [XcodeProj](https://github.com/tuist/XcodeProj) by the folks at [Tuist](https://tuist.io)
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) by Apple

and inspired by

- [Sourcery](https://github.com/krzysztofzablocki/Sourcery) by [Krzysztof Zabłocki](https://github.com/krzysztofzablocki)
- [R.swift](https://github.com/mac-cain13/R.swift) by [Mathijs Kadijk](https://github.com/mac-cain13)
