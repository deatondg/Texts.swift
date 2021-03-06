// Generated using Texts.swift 1.0.0 by Davis Deaton
// DO NOT EDIT
enum Texts {}


extension Texts { enum Templates {} }



extension Texts.Templates {
    static let Texts_Directory_swifttemplate: String = """
// Generated using Texts.swift {{ version }} by Davis Deaton
// DO NOT EDIT
enum {{ rootIdentifier }} {}

{% for directory in directories %}
extension {{ directory.parent }} { enum {{ directory.lastComponent }} {} }
{% endfor %}

"""
}

extension Texts.Templates {
    static let Texts_File_swifttemplate: String = #"""
// Generated using Texts.swift {{ version }} by Davis Deaton
// DO NOT EDIT

extension {{ file.parent }} {
    static let {{ file.name }}: String = {{ file.escapes }}"""
{{ file.contents }}
"""{{ file.escapes }}
}

"""#
}

extension Texts.Templates {
    static let Texts_swifttemplate: String = #"""
// Generated using Texts.swift {{ version }} by Davis Deaton
// DO NOT EDIT
enum {{ rootIdentifier }} {}

{% for directory in directories %}
extension {{ directory.parent }} { enum {{ directory.lastComponent }} {} }
{% endfor %}

{% for file in files %}
extension {{ file.parent }} {
    static let {{ file.name }}: String = {{ file.escapes }}"""
{{ file.contents }}
"""{{ file.escapes }}
}
{% endfor %}

"""#
}

