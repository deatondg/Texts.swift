// Generated using Texts.swift 0.0.0 by Davis Deaton
// DO NOT EDIT

enum Texts {
    enum Templates {
        static var Texts_swifttemplate: String =
#"""
// Generated using Texts.swift {{ version }} by Davis Deaton
// DO NOT EDIT
enum {{ rootIdentifier }} {}

{% for directory in directories %}
extension {{ directory.parent }} { enum {{ directory.lastComponent }} {} }
{% endfor %}

{% for file in files %}
extension {{ file.parent }} {
    static var {{ file.name }}: String = {{ file.escapes }}"""
{{ file.contents }}
"""{{ file.escapes }}
}
{% endfor %}
"""#
    }
}
