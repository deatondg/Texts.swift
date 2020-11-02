OVERVIEW: A utility to generate Swift sources mirroring the contents of text files as strings.

USAGE: texts-swift [--recursive] [--enable-underscore-replacement] [--disable-underscore-replacement] [--multiple-files] [--enum-name <enum-name>] [--source-root <root>] [--xcode-project <proj>] [--target <target> ...] [--output <output>] [<resources> ...]

ARGUMENTS:
  <resources>             A list of files and directories to be converted to Swift sources. 

OPTIONS:
  -r, --recursive         Resource directories should be scanned recursively. 
  --enable-underscore-replacement/--disable-underscore-replacement
                          File paths are transformed into Swift indentifiers by either replacing illegal characters with underscores or simply ignoring them. (default: true)
  --multiple-files        Create a .generated.swift file for each resource file. 
        In this mode, <enum-name>.generated.swift will still be created to house the directory structure as an empty Swift enum.
  --enum-name <enum-name> The name of the Swift enum which will contain the results of the conversion. (default: Texts)
        This will be converted into a valid Swift identifier automatically according to the specified underscore replacement rule.
  --source-root <root>    A directory which _all_ path arguments will be treated relative to. (default: The directory of the Xcode project if specified, and the current working directory otherwise) 
        This can only be specified without an Xcode project. If a project is specified, the directory of the Xcode project will be used.
  --xcode-project <proj>  The path to an Xcode project to add the generated files to. 
        This project is _not_ scanned for resource files.
  --target <target>       The name of an Xcode target to link the generated files to. 
        Multiple targets can be specified. If no target is specified, the added source files will not be linked to any target.
  -o, --output <output>   A file or directory to which the generated Swift sources will be written. (default: <root>) 
        This is treated as a directory if it ends in a / or if this path exists and is a directory. In single-file mode, if this is a file, all generated content will be written to this file. If this is a directory, all generated content will be written to <output>/<enum-name>.generated.swift. In multiple-file mode, if this is a file, the Swift source corresponding to the directory information will be written to this file, and the files for each resource will be written to the directory of this file. If this is a directory, all files will be written to this directory, and the directory structure will be written to <output>/<enum-name>.generated.swift.
  --version               Show the version.
  -h, --help              Show help information.
