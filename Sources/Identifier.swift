//
//  Identifier.swift
//  Texts.swift
//
//  Created by Davis Deaton on 10/19/20.
//

import Foundation

// The grammar of Swift identifiers:
// https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/LexicalStructure.html#//apple_ref/doc/uid/TP40014097-CH30-ID410
class Identifier: CustomStringConvertible {
    static let head_ranges: [(Unicode.Scalar, Unicode.Scalar)] = [
        ("A", "Z"), ("a", "z"),
        ("\u{00B2}", "\u{00B5}"), ("\u{00B7}", "\u{00BA}"),
        ("\u{00BC}", "\u{00BE}"), ("\u{00C0}", "\u{00D6}"), ("\u{00D8}", "\u{00F6}"), ("\u{00F8}", "\u{00FF}"),
        ("\u{0100}", "\u{02FF}"), ("\u{0370}", "\u{167F}"), ("\u{1681}", "\u{180D}"), ("\u{180F}", "\u{1DBF}"),
        ("\u{1E00}", "\u{1FFF}"),
        ("\u{200B}", "\u{200D}"), ("\u{202A}", "\u{202E}"), ("\u{203F}", "\u{2040}"), ("\u{2060}", "\u{206F}"),
        ("\u{2070}", "\u{20CF}"), ("\u{2100}", "\u{218F}"), ("\u{2460}", "\u{24FF}"), ("\u{2776}", "\u{2793}"),
        ("\u{2C00}", "\u{2DFF}"), ("\u{2E80}", "\u{2FFF}"),
        ("\u{3004}", "\u{3007}"), ("\u{3021}", "\u{302F}"), ("\u{3031}", "\u{303F}"), ("\u{3040}", "\u{D7FF}"),
        ("\u{F900}", "\u{FD3D}"), ("\u{FD40}", "\u{FDCF}"), ("\u{FDF0}", "\u{FE1F}"), ("\u{FE30}", "\u{FE44}"),
        ("\u{FE47}", "\u{FFFD}"),
        ("\u{10000}", "\u{1FFFD}"), ("\u{20000}", "\u{2FFFD}"), ("\u{30000}", "\u{3FFFD}"), ("\u{40000}", "\u{4FFFD}"),
        ("\u{50000}", "\u{5FFFD}"), ("\u{60000}", "\u{6FFFD}"), ("\u{70000}", "\u{7FFFD}"), ("\u{80000}", "\u{8FFFD}"),
        ("\u{90000}", "\u{9FFFD}"), ("\u{A0000}", "\u{AFFFD}"), ("\u{B0000}", "\u{BFFFD}"), ("\u{C0000}", "\u{CFFFD}"),
        ("\u{D0000}", "\u{DFFFD}"), ("\u{E0000}", "\u{EFFFD}"),
    ]
    static let head_singles: [Unicode.Scalar] = [
        "_",
        "\u{00A8}", "\u{00AA}", "\u{00AD}", "\u{00AF}",
        "\u{2054}"
    ]
    static let tail_ranges: [(Unicode.Scalar, Unicode.Scalar)] = [
        ("0", "9"),
        ("\u{0300}", "\u{036F}"), ("\u{1DC0}", "\u{1DFF}"), ("\u{20D0}", "\u{20FF}"), ("\u{FE20}", "\u{FE2F}")
    ]
    // There has got to be a better way to do this. This is absolutely ridiculous.
    static let identifier_head = (head_ranges.map({ $0...$1 }).map(CharacterSet.init(charactersIn:)) + [CharacterSet(head_singles)]).reduce(into: CharacterSet(), { $0.formUnion($1) })
    static let identifier_tail =  tail_ranges.map({ $0...$1 }).map(CharacterSet.init(charactersIn:)).reduce(into: CharacterSet(), { $0.formUnion($1) }).union(identifier_head)
    
    // This is probably an overkill list since I'm only creating variables and enums, but there's no downside to unnecessarily escaping identifiers.
    static let reserved: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init", "inout", "internal", "let", "open", "operator", "private", "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias", "var",
        "break", "case", "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
        "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self", "throw", "throws", "true", "try",
        "_",
        "associativity", "convenience", "dynamic", "didSet", "final", "get", "infix", "indirect", "lazy", "left", "mutating", "none", "nonmutating", "optional", "override", "postfix", "precedence", "prefix", "Protocol", "required", "right", "set", "Type", "unowned", "weak", "willSet"
    ]
    
    let string: String
    init(from other: String, useUnderscores: Bool = true) {
        // This is also pretty garbage.
        var string = String(String.UnicodeScalarView(other.unicodeScalars.compactMap({
            Identifier.identifier_tail.contains($0) ? $0 : (useUnderscores ? Unicode.Scalar("_") : nil)
        })))
        if let first = other.unicodeScalars.first, Identifier.identifier_head.contains(first) {} else {
            string = "_\(string)"
        }
        if Identifier.reserved.contains(string) {
            string = "`\(string)`"
        }
        self.string = string
    }
    
    var description: String { string }
}
