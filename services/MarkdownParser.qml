pragma Singleton
import Quickshell

// Parses the documented Markdown subset: YAML-ish frontmatter (title, tags)
// plus "## Command", "## Examples" and "## Notes" sections. Deliberately not a
// full YAML/CommonMark implementation; malformed input returns null and never
// throws.
Singleton {
    id: root

    readonly property var headingRe: /^(#{1,6})\s+(.+?)\s*$/
    readonly property var fenceRe: /^(\s*)(`{3,}|~{3,})(.*)$/

    // Returns an entry object or null. `path` must be the absolute file path.
    function parse(path, text) {
        try {
            return root._parse(path, text === undefined || text === null ? "" : String(text))
        } catch (e) {
            console.warn("[cheatshell] markdown parse error in " + path + ": " + e)
            return null
        }
    }

    function _parse(path, text) {
        let content = text
        if (content.charCodeAt(0) === 0xFEFF)
            content = content.slice(1)
        content = content.replace(/\r\n?/g, "\n")

        const lines = content.split("\n")

        // Skip leading blank lines before frontmatter detection.
        let start = 0
        while (start < lines.length && lines[start].trim() === "")
            start++

        let frontmatter = null
        if (start < lines.length && (lines[start].trim() === "---" || lines[start].trim() === "...")) {
            let close = -1
            for (let i = start + 1; i < lines.length; i++) {
                const t = lines[i].trim()
                if (t === "---" || t === "...") {
                    close = i
                    break
                }
            }
            if (close < 0) {
                console.warn("[cheatshell] unterminated frontmatter, skipping: " + path)
                return null
            }
            frontmatter = root._frontmatter(lines.slice(start + 1, close))
            start = close + 1
        }

        if (frontmatter !== null && frontmatter.title === "") {
            console.warn("[cheatshell] missing required 'title' in frontmatter, skipping: " + path)
            return null
        }

        const bodyLines = lines.slice(start)
        let title = frontmatter !== null ? frontmatter.title : ""
        const descriptionLines = []
        const sections = {}
        let current = null

        for (let i = 0; i < bodyLines.length; i++) {
            const line = bodyLines[i]
            const match = root.headingRe.exec(line)
            if (match) {
                const level = match[1].length
                const name = match[2].trim()
                if (level === 1) {
                    // A plain H1 doubles as the title for frontmatter-less notes.
                    if (title === "")
                        title = name
                    continue
                }
                const key = name.toLowerCase()
                if (!Object.prototype.hasOwnProperty.call(sections, key)) {
                    current = { name: key, lines: [] }
                    sections[key] = current
                } else {
                    current = sections[key]
                }
                continue
            }
            if (current === null)
                descriptionLines.push(line)
            else
                current.lines.push(line)
        }

        const filename = root._basename(path)
        let dir = path.slice(0, Math.max(0, path.length - filename.length))
        if (dir.length > 1 && dir.charAt(dir.length - 1) === "/")
            dir = dir.slice(0, -1)

        if (title === "") {
            title = root._filenameTitle(filename)
            if (title === "") {
                console.warn("[cheatshell] no title found, skipping: " + path)
                return null
            }
        }

        const tags = frontmatter !== null ? frontmatter.tags : []

        let command = ""
        let commandLang = "text"
        const commandSection = sections["command"]
        if (commandSection !== undefined) {
            const blocks = root._codeBlocks(commandSection.lines)
            if (blocks.length > 0) {
                command = blocks[0].code
                commandLang = blocks[0].language
            } else {
                command = root._plainText(commandSection.lines)
            }
        }

        const examples = []
        const exampleLangs = []
        const examplesSection = sections["examples"]
        if (examplesSection !== undefined) {
            const blocks = root._codeBlocks(examplesSection.lines)
            for (let i = 0; i < blocks.length; i++) {
                examples.push(blocks[i].code)
                exampleLangs.push(blocks[i].language)
            }
        }

        let notes = ""
        const notesSection = sections["notes"]
        if (notesSection !== undefined)
            notes = root._plainText(notesSection.lines)

        const description = descriptionLines.join("\n").trim()

        // Pre-normalised search fields; the search engine never re-normalises.
        return {
            path: path,
            dir: dir,
            filename: filename,
            title: title,
            tags: tags,
            description: description,
            command: command,
            commandLang: commandLang,
            examples: examples,
            exampleLangs: exampleLangs,
            notes: notes,
            sTitle: title.toLowerCase(),
            sTags: tags.join(" ").toLowerCase(),
            sDescription: description.toLowerCase(),
            sCommand: command.toLowerCase(),
            sExamples: examples.join("\n").toLowerCase(),
            sNotes: notes.toLowerCase(),
            sFilename: filename.toLowerCase()
        }
    }

    // Supports `key: value`, `key: [a, b]`, and block lists below `tags:`.
    function _frontmatter(lines) {
        const result = { title: "", tags: [] }
        let lastKey = ""

        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            const trimmed = raw.trim()
            if (trimmed === "" || trimmed.charAt(0) === "#")
                continue

            const itemMatch = /^\s*-\s*(.+?)\s*$/.exec(raw)
            if (itemMatch) {
                if (lastKey === "tags" || lastKey === "tag")
                    result.tags.push(root._unquote(itemMatch[1]))
                continue
            }

            const kvMatch = /^([A-Za-z0-9_-]+)\s*:\s*(.*)$/.exec(trimmed)
            if (!kvMatch) {
                lastKey = ""
                continue
            }

            const key = kvMatch[1].toLowerCase()
            const value = root._unquote(kvMatch[2].trim())
            lastKey = key

            if (key === "title")
                result.title = value
            else if (key === "tags" || key === "tag")
                result.tags = root._tagsValue(value)
        }

        const seen = {}
        const clean = []
        for (let i = 0; i < result.tags.length; i++) {
            const tag = String(result.tags[i]).trim().toLowerCase()
            if (tag === "" || seen[tag] === true)
                continue
            seen[tag] = true
            clean.push(tag)
        }

        result.tags = clean
        result.title = root._unquote(String(result.title).trim())
        return result
    }

    function _tagsValue(value) {
        let v = String(value).trim()
        if (v === "")
            return []
        if (v.charAt(0) === "[" && v.charAt(v.length - 1) === "]")
            v = v.slice(1, -1)
        const parts = v.split(",")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            const tag = root._unquote(parts[i].trim())
            if (tag !== "")
                out.push(tag)
        }
        return out
    }

    function _unquote(value) {
        let v = String(value).trim()
        if (v.length >= 2) {
            const first = v.charAt(0)
            const last = v.charAt(v.length - 1)
            if ((first === "\"" && last === "\"") || (first === "'" && last === "'"))
                v = v.slice(1, -1)
        }
        return v
    }

    // Extracts every fenced code block from a section, preserving indentation.
    // Returns [{ code, language }]; `language` is the normalised info string.
    function _codeBlocks(lines) {
        const blocks = []
        let fence = null
        let buffer = null

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const openMatch = root.fenceRe.exec(line)

            if (fence === null) {
                if (openMatch) {
                    fence = {
                        ch: openMatch[2].charAt(0),
                        len: openMatch[2].length,
                        language: root._normaliseLanguage(openMatch[3])
                    }
                    buffer = []
                }
                continue
            }

            const closeMatch = /^\s*(`{3,}|~{3,})\s*$/.exec(line)
            if (closeMatch && closeMatch[1].charAt(0) === fence.ch && closeMatch[1].length >= fence.len) {
                blocks.push({ code: root._dedent(buffer), language: fence.language })
                fence = null
                buffer = null
            } else {
                buffer.push(line)
            }
        }

        // Tolerate an unterminated final fence instead of dropping the content.
        if (fence !== null)
            blocks.push({ code: root._dedent(buffer), language: fence.language })

        return blocks
    }

    // Maps a fence info string to a known highlighter id. Unknown languages are
    // kept as-is so the preview can show the original name; the highlighter
    // treats anything it does not know as plain text.
    function _normaliseLanguage(info) {
        let lang = String(info === undefined || info === null ? "" : info).trim().toLowerCase()
        if (lang === "")
            return "text"

        // Support pandoc/quartz style attributes: ```{.bash ...}
        const attr = /^\{\.?\s*([A-Za-z0-9_+#.-]+)/.exec(lang)
        if (attr) {
            lang = attr[1]
        } else {
            const space = lang.search(/[\s,{]/)
            if (space === 0)
                return "text"
            if (space > 0)
                lang = lang.slice(0, space)
        }

        const aliases = {
            "sh": "bash", "shell": "bash", "zsh": "bash", "console": "bash",
            "shell-session": "bash", "bash-session": "bash",
            "js": "js", "javascript": "js", "ts": "js", "typescript": "js",
            "jsx": "js", "tsx": "js", "node": "js",
            "yml": "yaml", "conf": "ini", "cfg": "ini", "properties": "ini",
            "docker": "dockerfile", "docker-file": "dockerfile",
            "plaintext": "text", "plain": "text", "txt": "text"
        }
        return aliases[lang] !== undefined ? aliases[lang] : lang
    }

    function _dedent(lines) {
        let first = 0
        let last = lines.length
        while (first < last && lines[first].trim() === "")
            first++
        while (last > first && lines[last - 1].trim() === "")
            last--

        const sliced = lines.slice(first, last)
        let minIndent = Infinity
        for (let i = 0; i < sliced.length; i++) {
            const line = sliced[i]
            if (line.trim() === "")
                continue
            let width = 0
            for (let c = 0; c < line.length; c++) {
                const ch = line.charAt(c)
                if (ch === " ")  width++
                else if (ch === "\t") width += 4
                else break
            }
            minIndent = Math.min(minIndent, width)
        }

        if (!isFinite(minIndent) || minIndent <= 0)
            return sliced.join("\n")

        const out = []
        for (let i = 0; i < sliced.length; i++)
            out.push(root._trimIndent(sliced[i], minIndent))
        return out.join("\n")
    }

    function _trimIndent(line, amount) {
        let removed = 0
        let idx = 0
        while (idx < line.length && removed < amount) {
            const ch = line.charAt(idx)
            if (ch === " ") {
                removed++
                idx++
            } else if (ch === "\t") {
                removed += 4
                idx++
            } else {
                break
            }
        }
        return line.slice(idx)
    }

    function _plainText(lines) {
        let first = 0
        let last = lines.length
        while (first < last && lines[first].trim() === "")
            first++
        while (last > first && lines[last - 1].trim() === "")
            last--
        return lines.slice(first, last).join("\n").trim()
    }

    function _basename(path) {
        const idx = path.lastIndexOf("/")
        return idx < 0 ? path : path.slice(idx + 1)
    }

    function _filenameTitle(filename) {
        let name = filename
        if (name.length > 3 && name.slice(-3).toLowerCase() === ".md")
            name = name.slice(0, -3)
        name = name.replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim()
        if (name === "")
            return ""
        return name.charAt(0).toUpperCase() + name.slice(1)
    }
}
