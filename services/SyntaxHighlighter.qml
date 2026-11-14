pragma Singleton
import Quickshell

// Dependency-free syntax highlighter for fenced Markdown code blocks.
// Produces a Qt StyledText (HTML subset) string; the raw code is left
// untouched and remains the source of truth for copying.
Singleton {
    id: root

    readonly property string cKeyword: "#82aaff"
    readonly property string cString: "#93d9a7"
    readonly property string cNumber: "#f78c6c"
    readonly property string cComment: "#5f6678"
    readonly property string cVariable: "#d8a657"
    readonly property string cOperator: "#89ddff"
    readonly property string cKey: "#89ddff"

    readonly property var bashKeywords: ({
        "if": true, "then": true, "else": true, "elif": true, "fi": true,
        "for": true, "while": true, "until": true, "do": true, "done": true,
        "case": true, "esac": true, "in": true, "function": true,
        "select": true, "time": true, "return": true, "local": true,
        "export": true, "readonly": true, "declare": true, "unset": true,
        "shift": true, "break": true, "continue": true, "exit": true,
        "trap": true, "eval": true, "exec": true
    })

    readonly property var sqlKeywords: ({
        "SELECT": true, "FROM": true, "WHERE": true, "INSERT": true,
        "INTO": true, "VALUES": true, "UPDATE": true, "SET": true,
        "DELETE": true, "CREATE": true, "ALTER": true, "DROP": true,
        "TABLE": true, "INDEX": true, "VIEW": true, "DATABASE": true,
        "JOIN": true, "INNER": true, "LEFT": true, "RIGHT": true,
        "FULL": true, "OUTER": true, "ON": true, "USING": true,
        "GROUP": true, "BY": true, "ORDER": true, "HAVING": true,
        "LIMIT": true, "OFFSET": true, "AS": true, "AND": true,
        "OR": true, "NOT": true, "NULL": true, "IS": true, "IN": true,
        "EXISTS": true, "BETWEEN": true, "LIKE": true, "ILIKE": true,
        "DISTINCT": true, "UNION": true, "ALL": true, "CASE": true,
        "WHEN": true, "THEN": true, "ELSE": true, "END": true,
        "PRIMARY": true, "KEY": true, "FOREIGN": true, "REFERENCES": true,
        "UNIQUE": true, "DEFAULT": true, "CHECK": true, "CONSTRAINT": true,
        "CASCADE": true, "RETURNING": true, "WITH": true, "RECURSIVE": true,
        "BEGIN": true, "COMMIT": true, "ROLLBACK": true, "TRANSACTION": true,
        "GRANT": true, "REVOKE": true, "TRUNCATE": true, "EXPLAIN": true,
        "ANALYZE": true, "VACUUM": true, "IF": true, "ASC": true, "DESC": true,
        "COUNT": true, "SUM": true, "AVG": true, "MIN": true, "MAX": true,
        "COALESCE": true, "CAST": true, "INTEGER": true, "TEXT": true,
        "VARCHAR": true, "BOOLEAN": true, "TIMESTAMP": true, "SERIAL": true,
        "UUID": true, "JSON": true, "JSONB": true, "ARRAY": true
    })

    readonly property var jsKeywords: ({
        "var": true, "let": true, "const": true, "function": true,
        "return": true, "if": true, "else": true, "for": true,
        "while": true, "do": true, "switch": true, "case": true,
        "break": true, "continue": true, "new": true, "delete": true,
        "typeof": true, "instanceof": true, "in": true, "of": true,
        "class": true, "extends": true, "super": true, "this": true,
        "import": true, "export": true, "from": true, "default": true,
        "try": true, "catch": true, "finally": true, "throw": true,
        "async": true, "await": true, "yield": true, "void": true,
        "null": true, "undefined": true, "true": true, "false": true,
        "interface": true, "type": true, "enum": true, "implements": true,
        "public": true, "private": true, "protected": true, "readonly": true,
        "static": true, "declare": true, "namespace": true, "satisfies": true
    })

    readonly property var dockerInstructions: ({
        "FROM": true, "RUN": true, "CMD": true, "LABEL": true,
        "EXPOSE": true, "ENV": true, "ADD": true, "COPY": true,
        "ENTRYPOINT": true, "VOLUME": true, "USER": true, "WORKDIR": true,
        "ARG": true, "ONBUILD": true, "STOPSIGNAL": true, "HEALTHCHECK": true,
        "SHELL": true, "MAINTAINER": true
    })

    // `language` is the normalised fence info string from MarkdownParser.
    function highlight(code, language) {
        const text = code === undefined || code === null ? "" : String(code)
        if (text === "")
            return ""

        const lang = String(language === undefined || language === null ? "text" : language)
            .trim().toLowerCase()

        try {
            if (lang === "bash")
                return root._wrap(root._bash(text))
            if (lang === "sql")
                return root._wrap(root._sql(text))
            if (lang === "js")
                return root._wrap(root._js(text))
            if (lang === "json")
                return root._wrap(root._json(text))
            if (lang === "yaml")
                return root._wrap(root._yaml(text))
            if (lang === "ini")
                return root._wrap(root._ini(text))
            if (lang === "dockerfile")
                return root._wrap(root._dockerfile(text))
        } catch (e) {
            // Never let a highlighting bug hide the code itself.
        }

        return root._wrap(root._esc(text))
    }

    // --- bash -------------------------------------------------------------

    function _bash(text) {
        const tokens = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            if (i > 0)
                tokens.push({ c: "", t: "\n" })
            root._bashLine(lines[i], tokens)
        }
        return root._render(tokens)
    }

    function _bashLine(line, tokens) {
        let i = 0
        while (i < line.length) {
            const ch = line.charAt(i)

            if (ch === "#" && (i === 0 || root._isSpaceOrOp(line.charAt(i - 1)))) {
                tokens.push({ c: root.cComment, t: line.slice(i) })
                return
            }

            if (ch === "'") {
                let end = line.indexOf("'", i + 1)
                end = end < 0 ? line.length : end + 1
                tokens.push({ c: root.cString, t: line.slice(i, end) })
                i = end
                continue
            }

            if (ch === "\"" || ch === "`") {
                let j = i + 1
                while (j < line.length) {
                    const c = line.charAt(j)
                    if (c === "\\") {
                        j += 2
                        continue
                    }
                    if (c === ch) {
                        j++
                        break
                    }
                    j++
                }
                tokens.push({ c: root.cString, t: line.slice(i, j) })
                i = j
                continue
            }

            if (ch === "$") {
                const rest = line.slice(i)
                let match = /^\$\{[^}]*\}/.exec(rest)
                if (!match)
                    match = /^\$[A-Za-z_][A-Za-z0-9_]*/.exec(rest)
                if (!match)
                    match = /^\$[0-9@*#?$!_-]/.exec(rest)
                if (match) {
                    tokens.push({ c: root.cVariable, t: match[0] })
                    i += match[0].length
                    continue
                }
            }

            if (ch === "-" && (i === 0 || root._isSpace(line.charAt(i - 1)))) {
                const match = /^-{1,2}[A-Za-z0-9][A-Za-z0-9_-]*/.exec(line.slice(i))
                if (match) {
                    tokens.push({ c: root.cVariable, t: match[0] })
                    i += match[0].length
                    continue
                }
            }

            if (root._isDigit(ch) && (i === 0 || !root._isWord(line.charAt(i - 1)))) {
                const match = /^\d+(?:\.\d+)?/.exec(line.slice(i))
                tokens.push({ c: root.cNumber, t: match[0] })
                i += match[0].length
                continue
            }

            if (root._isWordStart(ch)) {
                const match = /^[A-Za-z_][A-Za-z0-9_-]*/.exec(line.slice(i))
                const word = match[0]
                tokens.push({ c: root.bashKeywords[word] === true ? root.cKeyword : "", t: word })
                i += word.length
                continue
            }

            if (root._isOperator(ch)) {
                const match = /^(?:&&|\|\||>>|<<|[|&;<>+\-*/%=!?:^~])/.exec(line.slice(i))
                tokens.push({ c: root.cOperator, t: match[0] })
                i += match[0].length
                continue
            }

            tokens.push({ c: "", t: ch })
            i++
        }
    }

    // --- sql --------------------------------------------------------------

    function _sql(text) {
        const tokens = []
        let i = 0

        while (i < text.length) {
            const ch = text.charAt(i)
            const next = text.charAt(i + 1)

            if (ch === "-" && next === "-") {
                let end = text.indexOf("\n", i)
                if (end < 0)
                    end = text.length
                tokens.push({ c: root.cComment, t: text.slice(i, end) })
                i = end
                continue
            }

            if (ch === "/" && next === "*") {
                let end = text.indexOf("*/", i + 2)
                end = end < 0 ? text.length : end + 2
                tokens.push({ c: root.cComment, t: text.slice(i, end) })
                i = end
                continue
            }

            if (ch === "'") {
                let j = i + 1
                while (j < text.length) {
                    if (text.charAt(j) === "'") {
                        if (text.charAt(j + 1) === "'") {
                            j += 2
                            continue
                        }
                        j++
                        break
                    }
                    j++
                }
                tokens.push({ c: root.cString, t: text.slice(i, j) })
                i = j
                continue
            }

            if (ch === "\"" || ch === "`") {
                const end = root._quotedEnd(text, i, ch)
                tokens.push({ c: root.cKey, t: text.slice(i, end) })
                i = end
                continue
            }

            if (root._isDigit(ch) && (i === 0 || !root._isWord(text.charAt(i - 1)))) {
                const match = /^\d+(?:\.\d+)?/.exec(text.slice(i))
                tokens.push({ c: root.cNumber, t: match[0] })
                i += match[0].length
                continue
            }

            if (root._isWordStart(ch)) {
                const match = /^[A-Za-z_][A-Za-z0-9_$]*/.exec(text.slice(i))
                const word = match[0]
                tokens.push({
                    c: root.sqlKeywords[word.toUpperCase()] === true ? root.cKeyword : "",
                    t: word
                })
                i += word.length
                continue
            }

            if (root._isOperator(ch)) {
                tokens.push({ c: root.cOperator, t: ch })
                i++
                continue
            }

            tokens.push({ c: "", t: ch })
            i++
        }

        return root._render(tokens)
    }

    // --- javascript / typescript -----------------------------------------

    function _js(text) {
        const tokens = []
        let i = 0

        while (i < text.length) {
            const ch = text.charAt(i)
            const next = text.charAt(i + 1)

            if (ch === "/" && next === "/") {
                let end = text.indexOf("\n", i)
                if (end < 0)
                    end = text.length
                tokens.push({ c: root.cComment, t: text.slice(i, end) })
                i = end
                continue
            }

            if (ch === "/" && next === "*") {
                let end = text.indexOf("*/", i + 2)
                end = end < 0 ? text.length : end + 2
                tokens.push({ c: root.cComment, t: text.slice(i, end) })
                i = end
                continue
            }

            if (ch === "'" || ch === "\"" || ch === "`") {
                const end = root._quotedEnd(text, i, ch)
                tokens.push({ c: root.cString, t: text.slice(i, end) })
                i = end
                continue
            }

            if (root._isDigit(ch) && (i === 0 || !root._isWord(text.charAt(i - 1)))) {
                const match = /^\d+(?:\.\d+)?(?:e[+-]?\d+)?/i.exec(text.slice(i))
                tokens.push({ c: root.cNumber, t: match[0] })
                i += match[0].length
                continue
            }

            if (root._isWordStart(ch)) {
                const match = /^[A-Za-z_$][A-Za-z0-9_$]*/.exec(text.slice(i))
                const word = match[0]
                tokens.push({ c: root.jsKeywords[word] === true ? root.cKeyword : "", t: word })
                i += word.length
                continue
            }

            if (root._isOperator(ch)) {
                const match = /^(?:===|!==|=>|==|!=|<=|>=|&&|\|\||\?\?|[+\-*/%=<>!&|^~?:;])/.exec(text.slice(i))
                tokens.push({ c: root.cOperator, t: match[0] })
                i += match[0].length
                continue
            }

            tokens.push({ c: "", t: ch })
            i++
        }

        return root._render(tokens)
    }

    // --- json -------------------------------------------------------------

    function _json(text) {
        const tokens = []
        let i = 0

        while (i < text.length) {
            const ch = text.charAt(i)

            if (ch === "\"") {
                const end = root._quotedEnd(text, i, ch)
                const literal = text.slice(i, end)
                let j = end
                while (j < text.length && root._isSpace(text.charAt(j)))
                    j++
                tokens.push({
                    c: text.charAt(j) === ":" ? root.cKey : root.cString,
                    t: literal
                })
                i = end
                continue
            }

            if (root._isDigit(ch) || (ch === "-" && root._isDigit(text.charAt(i + 1)))) {
                const match = /^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/.exec(text.slice(i))
                tokens.push({ c: root.cNumber, t: match[0] })
                i += match[0].length
                continue
            }

            if (root._isWordStart(ch)) {
                const match = /^[A-Za-z_][A-Za-z0-9_]*/.exec(text.slice(i))
                const word = match[0]
                const isLiteral = word === "true" || word === "false" || word === "null"
                tokens.push({ c: isLiteral ? root.cKeyword : "", t: word })
                i += word.length
                continue
            }

            tokens.push({ c: "", t: ch })
            i++
        }

        return root._render(tokens)
    }

    // --- yaml -------------------------------------------------------------

    function _yaml(text) {
        const tokens = []
        const lines = text.split("\n")

        for (let i = 0; i < lines.length; i++) {
            if (i > 0)
                tokens.push({ c: "", t: "\n" })
            root._yamlLine(lines[i], tokens)
        }

        return root._render(tokens)
    }

    function _yamlLine(line, tokens) {
        const trimmed = line.trim()

        if (trimmed === "") {
            tokens.push({ c: "", t: line })
            return
        }

        if (trimmed.charAt(0) === "#") {
            tokens.push({ c: root.cComment, t: line })
            return
        }

        const match = /^(\s*(?:-\s+)?)([A-Za-z0-9_."'\/-]+)(\s*:)(.*)$/.exec(line)
        if (match) {
            tokens.push({ c: "", t: match[1] })
            tokens.push({ c: root.cKey, t: match[2] })
            tokens.push({ c: root.cOperator, t: match[3] })
            root._valueTokens(match[4], tokens)
            return
        }

        root._valueTokens(line, tokens)
    }

    // --- ini --------------------------------------------------------------

    function _ini(text) {
        const tokens = []
        const lines = text.split("\n")

        for (let i = 0; i < lines.length; i++) {
            if (i > 0)
                tokens.push({ c: "", t: "\n" })
            root._iniLine(lines[i], tokens)
        }

        return root._render(tokens)
    }

    function _iniLine(line, tokens) {
        const trimmed = line.trim()

        if (trimmed === "") {
            tokens.push({ c: "", t: line })
            return
        }

        if (trimmed.charAt(0) === ";" || trimmed.charAt(0) === "#") {
            tokens.push({ c: root.cComment, t: line })
            return
        }

        const section = /^(\s*)(\[[^\]]*\])(.*)$/.exec(line)
        if (section) {
            tokens.push({ c: "", t: section[1] })
            tokens.push({ c: root.cKeyword, t: section[2] })
            root._valueTokens(section[3], tokens)
            return
        }

        const match = /^(\s*)([A-Za-z0-9_.-]+)(\s*[=:]\s*)(.*)$/.exec(line)
        if (match) {
            tokens.push({ c: "", t: match[1] })
            tokens.push({ c: root.cKey, t: match[2] })
            tokens.push({ c: root.cOperator, t: match[3] })
            root._valueTokens(match[4], tokens)
            return
        }

        root._valueTokens(line, tokens)
    }

    // --- dockerfile -------------------------------------------------------

    function _dockerfile(text) {
        const tokens = []
        const lines = text.split("\n")

        for (let i = 0; i < lines.length; i++) {
            if (i > 0)
                tokens.push({ c: "", t: "\n" })
            root._dockerLine(lines[i], tokens)
        }

        return root._render(tokens)
    }

    function _dockerLine(line, tokens) {
        const trimmed = line.trim()

        if (trimmed === "") {
            tokens.push({ c: "", t: line })
            return
        }

        if (trimmed.charAt(0) === "#") {
            tokens.push({ c: root.cComment, t: line })
            return
        }

        const instruction = /^(\s*)([A-Za-z]+)\b/.exec(line)
        if (instruction) {
            tokens.push({ c: "", t: instruction[1] })
            const word = instruction[2]
            tokens.push({
                c: root.dockerInstructions[word.toUpperCase()] === true ? root.cKeyword : "",
                t: word
            })
            root._dockerArgs(line.slice(instruction[1].length + word.length), tokens)
            return
        }

        root._dockerArgs(line, tokens)
    }

    function _dockerArgs(text, tokens) {
        let i = 0

        while (i < text.length) {
            const ch = text.charAt(i)

            if (ch === "#" && (i === 0 || root._isSpace(text.charAt(i - 1)))) {
                tokens.push({ c: root.cComment, t: text.slice(i) })
                return
            }

            if (ch === "'" || ch === "\"") {
                const end = root._quotedEnd(text, i, ch)
                tokens.push({ c: root.cString, t: text.slice(i, end) })
                i = end
                continue
            }

            if (ch === "$") {
                const rest = text.slice(i)
                let match = /^\$\{[^}]*\}/.exec(rest)
                if (!match)
                    match = /^\$[A-Za-z_][A-Za-z0-9_]*/.exec(rest)
                if (match) {
                    tokens.push({ c: root.cVariable, t: match[0] })
                    i += match[0].length
                    continue
                }
            }

            if (ch === "-" && (i === 0 || root._isSpace(text.charAt(i - 1)))) {
                const match = /^-{1,2}[A-Za-z0-9][A-Za-z0-9_-]*(?:=[^\s]*)?/.exec(text.slice(i))
                if (match) {
                    tokens.push({ c: root.cVariable, t: match[0] })
                    i += match[0].length
                    continue
                }
            }

            if (root._isDigit(ch) && (i === 0 || !root._isWord(text.charAt(i - 1)))) {
                const match = /^\d+(?:\.\d+)?/.exec(text.slice(i))
                tokens.push({ c: root.cNumber, t: match[0] })
                i += match[0].length
                continue
            }

            tokens.push({ c: "", t: ch })
            i++
        }
    }

    // --- shared -----------------------------------------------------------

    // Highlights quoted strings, numbers and booleans inside a value fragment,
    // plus trailing comments introduced by " #".
    function _valueTokens(text, tokens) {
        let i = 0

        while (i < text.length) {
            const ch = text.charAt(i)

            if ((ch === "'" || ch === "\"") && (i === 0 || /[\s:=,\[]/.test(text.charAt(i - 1)))) {
                const end = root._quotedEnd(text, i, ch)
                tokens.push({ c: root.cString, t: text.slice(i, end) })
                i = end
                continue
            }

            if (ch === "#" && (i === 0 || root._isSpace(text.charAt(i - 1)))) {
                tokens.push({ c: root.cComment, t: text.slice(i) })
                return
            }

            if (root._isDigit(ch) && (i === 0 || !root._isWord(text.charAt(i - 1)))) {
                const match = /^\d+(?:\.\d+)?/.exec(text.slice(i))
                tokens.push({ c: root.cNumber, t: match[0] })
                i += match[0].length
                continue
            }

            if (root._isWordStart(ch)) {
                const match = /^[A-Za-z_][A-Za-z0-9_-]*/.exec(text.slice(i))
                const word = match[0]
                if (word === "true" || word === "false" || word === "null")
                    tokens.push({ c: root.cKeyword, t: word })
                else
                    tokens.push({ c: "", t: word })
                i += word.length
                continue
            }

            tokens.push({ c: "", t: ch })
            i++
        }
    }

    function _quotedEnd(text, start, quote) {
        let i = start + 1
        while (i < text.length) {
            const ch = text.charAt(i)
            if (ch === "\\") {
                i += 2
                continue
            }
            if (ch === quote) {
                i++
                break
            }
            if (ch === "\n" && quote !== "`")
                break
            i++
        }
        return Math.min(i, text.length)
    }

    function _render(tokens) {
        const parts = []
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i]
            if (token.t === "")
                continue
            if (token.c === "")
                parts.push(root._esc(token.t))
            else
                parts.push("<font color=\"" + token.c + "\">" + root._esc(token.t) + "</font>")
        }
        return root._preserveWhitespace(parts.join(""))
    }

    // Qt's StyledText parser collapses literal newlines and leading spaces, so
    // emit explicit <br/> and non-breaking spaces instead. Only text outside
    // our own <font> tags is touched.
    function _preserveWhitespace(html) {
        const segments = html.split(/(<font color="#[0-9a-f]{6}">|<\/font>)/)
        const out = []
        let lineStart = true

        for (let i = 0; i < segments.length; i++) {
            const segment = segments[i]
            if (segment === "")
                continue
            if (segment.charAt(0) === "<") {
                out.push(segment)
                continue
            }

            let formatted = ""
            for (let c = 0; c < segment.length; c++) {
                const ch = segment.charAt(c)
                if (ch === "\n") {
                    formatted += "<br/>"
                    lineStart = true
                } else if (ch === "\t") {
                    if (lineStart)
                        formatted += "&nbsp;&nbsp;&nbsp;&nbsp;"
                    else
                        formatted += "    "
                    // tabs keep the line "started" only when they were rendered
                    // as indentation; either way the next char is not at column 0.
                    lineStart = false
                } else if (ch === " " && lineStart) {
                    formatted += "&nbsp;"
                } else {
                    formatted += ch
                    lineStart = false
                }
            }
            out.push(formatted)
        }

        return out.join("")
    }

    function _wrap(inner) {
        return "<div style=\"white-space: pre-wrap\">" + inner + "</div>"
    }

    function _esc(text) {
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function _isSpace(ch) {
        return ch === " " || ch === "\t" || ch === "\n" || ch === "\r"
    }

    function _isSpaceOrOp(ch) {
        return root._isSpace(ch) || ch === ";" || ch === "|" || ch === "&" || ch === "(" || ch === ")"
    }

    function _isDigit(ch) {
        return ch >= "0" && ch <= "9"
    }

    function _isWordStart(ch) {
        return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "_"
    }

    function _isWord(ch) {
        return root._isWordStart(ch) || root._isDigit(ch)
    }

    function _isOperator(ch) {
        return "|&;<>+-*/%=!?:^~".indexOf(ch) >= 0
    }
}
