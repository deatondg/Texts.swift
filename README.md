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
This is in fact the structure of the [Stencil](https://github.com/kylef/Stencil) template resources used Texts.swift.
That's right: Texts.swift is used to generate its own source code.

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

### Excluding files or including files by regex

An original draft of this program included support for exclusion and regular expressions.
Ultimately, I decided that these features were out of scope for this utility and was duplicating too much standard unix functionality.
If you would still like this kind of behavior, I suggest chaining `texts-swift` with `xargs` and `find` for something like
```
find <root> <criterion> | xargs texts-swift --source-root <root> <options>
```

## Detailed Design

I wrote this tool for three primary reasons:
1. For personal use in another one of my projects, AutoMetal, which generates Swift sources for `.metallib` files.
1. To practice writing (partially) self-hosted source code generation tools before creating a complicated one.
1. To have a small project that I actually open source for once.

As a result, this tool was written with two primary design goals:
1. The generated Swift code should resemble the directory stucture of the text resources.
1. The tool should integrate easily with Xcode.
because these were the primary ways I wanted it to behave. 

#### File Paths -> Identifier Paths

The most natural way to resemble a directory structure in Swift is some sort of static key path.
In particular, the resource `A/B/C/D.text` should be translated into something like `A.B.C.D_text`.
Thus, the easiest way to make from a resource path to a Swift identifier is just to replace the `/` between path components with `.`.
However, not all characters which are valid in paths are valid in Swift identifiers.
The grammar of Swift identifiers is presented found in the [Swift language reference](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html#//apple_ref/doc/uid/TP40014097-CH30-ID410).

A choice must be made.
I think there are two obvious ones: either invalid characters should simply be deleted when converting to Swift identifiers, or they should be replaced by a fixed character like `_`.
I let the user pick between these two options with `--enable-underscore-replacement/--disable-underscore-replacement`.
If you have another idea and want it implemented, file an issue or a PR and I might add support.

Some characters are valid in Swift idenfifiers but not at the very beginning (for example digits).
If a path component begins with such a character, I prefix that component with an underscore.

In order for an identifier like `A.B.C.D_text` to actually be valid Swift, each of the components `A`,`B`,`C`,`D_text` must be something.
The most obvious choice here is for directories to be empty Swift enums (unlike structs, these cannot be initialized) and for files to be `static let` strings.
In order to avoid polluting the global namespace, I decided to put all of these enums inside a single parent enum.
You can choose the name of this enum with the `--enum-name <enum-name>` option which defaults to `Texts`.

Thus, a resource path like `A/1/B/2/D.text` becomes `Texts.A._1.B._2.D_text` which will be a string containing the contents of the resource file `D.text`.

#### Source root and Xcode projects

Most (all?) Swift sources in an Xcode project are relative to the directory of the Xcode project.
In order for a resource file to be converted to a Swift identifier, the path should also be relative so that information about absolute paths does not pollute the generated source code.
Thus, I chose to accept a `--source-root <root>` argument to which all other paths are treated relative to.
If an Xcode project is specified, its directory is used as the source root instead.
Otherwise, the source root defaults to the current working directory.
I'm sure there's another reasonable way to do this, but this made Xcode support as easy as possible.

Speaking of Xcode support, I support automatically adding the generated source files to an Xcode project and automatically linking them to specified targets.
I based my utility on my experience using [Sourcery](https://github.com/krzysztofzablocki/Sourcery)'s Xcode project support.
I made three decisions which could either be controversial or differ from Sourcery.
1. I only write to an Xcode project if I actually needed to make a change.
Thus, if you use Texts.swift in a custom Xcode build phase, your build should not cancel part way through due to the Xcode project updating unless you have caused Texts.swift to add a new `.generated.swift` file to your project.
1. I only link files to the specified targets if they are absent from the project.
If a generated source file is present in the project but is not linked to a target, I assume you did that on purpose, so I'm not going to change it on you.
1. Xcode groups will be created matching the directory structure of your specified output.
If you choose to output to `Sources/Generated`, a `Sources` group will be created on the main group if it does not already exist, and a `Generated` group will be created on the `Sources` group if it does not already exist, and all generated files will be placed in this group.
Unlike Sourcery, I do not support linking to other groups.
This is mostly because I gave up trying to figure out how [XcodeProj](https://github.com/tuist/XcodeProj) handles groups.
I'm probably doing something incredibly dumb, so if you know better or would like different functionality, please let me know.

## Attributions

This tool is powered by

- [Stencil](https://github.com/kylef/Stencil) and [PathKit](https://github.com/kylef/PathKit) by [Kyle Fuller](https://github.com/kylef)
- [XcodeProj](https://github.com/tuist/XcodeProj) by the folks at [Tuist](https://tuist.io)
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) by Apple

and inspired by

- [Sourcery](https://github.com/krzysztofzablocki/Sourcery) by [Krzysztof Zabłocki](https://github.com/krzysztofzablocki)
- [R.swift](https://github.com/mac-cain13/R.swift) by [Mathijs Kadijk](https://github.com/mac-cain13)

## About me

My name is Davis Deaton. 
This is my first open source project.
I do not have much of an internet presence, but you can visit [my website](https://www.davislikes.coffee)
If you like my work and want to get ahold of me, your best bet is to [email me](mailto://deaton.dg@gmail.com) although I rarely check my inbox.
