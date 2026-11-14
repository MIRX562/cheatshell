pragma Singleton
import Quickshell
import "../config"
import "../models"

// Pure in-memory search over pre-normalised entry fields:
// case-insensitive substring matching plus a subsequence fuzzy fallback,
// relevance scoring and `tag:` query parsing.
Singleton {
    id: root

    // Ranking weights encode the documented priority:
    // title > tags > command > description > examples > notes > filename.
    readonly property var weights: ({
        title: 100,
        tags: 80,
        command: 60,
        description: 45,
        examples: 35,
        notes: 30,
        filename: 20
    })

    // Splits a raw query into lowercased search terms and tag filters.
    function parseQuery(query) {
        const tokens = String(query === undefined || query === null ? "" : query).trim().split(/\s+/)
        const terms = []
        const tags = []

        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i]
            if (token === "")
                continue
            if (token.length > 4 && token.slice(0, 4).toLowerCase() === "tag:") {
                const value = token.slice(4).replace(/^"|"$/g, "").trim().toLowerCase()
                if (value !== "")
                    tags.push(value)
            } else {
                terms.push(token.toLowerCase())
            }
        }
        return { terms: terms, tags: tags }
    }

    // Returns { entries, total }. `entries` is the visible window (all matches
    // when limit <= 0) and `total` is the number of matches before limiting.
    function search(query, activeTags, limit) {
        const parsed = root.parseQuery(query)
        const filterTags = []

        const selected = activeTags === undefined || activeTags === null ? [] : activeTags
        for (let i = 0; i < selected.length; i++)
            filterTags.push(String(selected[i]).toLowerCase())
        for (let i = 0; i < parsed.tags.length; i++) {
            if (filterTags.indexOf(parsed.tags[i]) < 0)
                filterTags.push(parsed.tags[i])
        }

        const all = CommandModel.entries

        // Tag filtering first (AND across all requested tags).
        let pool = all
        if (filterTags.length > 0) {
            pool = []
            for (let i = 0; i < all.length; i++) {
                const entry = all[i]
                let matches = true
                for (let t = 0; t < filterTags.length; t++) {
                    if (entry.tags.indexOf(filterTags[t]) < 0) {
                        matches = false
                        break
                    }
                }
                if (matches)
                    pool.push(entry)
            }
        }

        const max = root._limit(limit)

        if (parsed.terms.length === 0) {
            let total = pool.length
            if (Config.maxResults > 0)
                total = Math.min(total, Config.maxResults)
            const shown = max > 0 ? Math.min(max, total) : total
            return { entries: pool.slice(0, shown), total: total }
        }

        const scored = []
        for (let i = 0; i < pool.length; i++) {
            const entry = pool[i]
            let total = 0
            let matched = true
            for (let t = 0; t < parsed.terms.length; t++) {
                const score = root._termScore(entry, parsed.terms[t])
                if (score <= 0) {
                    matched = false
                    break
                }
                total += score
            }
            if (matched)
                scored.push({ entry: entry, score: total })
        }

        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score
            if (a.entry.sTitle < b.entry.sTitle) return -1
            if (a.entry.sTitle > b.entry.sTitle) return 1
            return 0
        })

        let total = scored.length
        if (Config.maxResults > 0)
            total = Math.min(total, Config.maxResults)
        const visible = max > 0 ? Math.min(max, total) : total
        const results = []
        for (let i = 0; i < visible; i++)
            results.push(scored[i].entry)
        return { entries: results, total: total }
    }

    // <= 0 means unlimited. Missing values fall back to search.maxResults.
    function _limit(value) {
        let max = Number(value)
        if (!isFinite(max) || max < 0)
            max = Config.maxResults
        return Math.floor(max)
    }

    function _termScore(entry, term) {
        let best = root.weights.title * root._quality(term, entry.sTitle)

        let tagQuality = 0
        for (let i = 0; i < entry.tags.length; i++) {
            const quality = root._quality(term, entry.tags[i])
            if (quality > tagQuality)
                tagQuality = quality
        }
        const tagScore = root.weights.tags * tagQuality
        if (tagScore > best) best = tagScore

        const commandScore = root.weights.command * root._quality(term, entry.sCommand)
        if (commandScore > best) best = commandScore

        const descriptionScore = root.weights.description * root._quality(term, entry.sDescription)
        if (descriptionScore > best) best = descriptionScore

        const examplesScore = root.weights.examples * root._quality(term, entry.sExamples)
        if (examplesScore > best) best = examplesScore

        const notesScore = root.weights.notes * root._quality(term, entry.sNotes)
        if (notesScore > best) best = notesScore

        const filenameScore = root.weights.filename * root._quality(term, entry.sFilename)
        if (filenameScore > best) best = filenameScore

        return best
    }

    // 0 = no match, 1.0 = exact field match. Substring hits always count;
    // fuzzy subsequence hits honour config.search.fuzzy/minimumScore.
    function _quality(term, text) {
        if (!term || !text)
            return 0

        const index = text.indexOf(term)
        if (index === 0)
            return text.length === term.length ? 1.0 : 0.95
        if (index > 0) {
            const before = text.charAt(index - 1)
            const boundary = !root._isWordChar(before)
            return boundary ? 0.9 : 0.78
        }

        if (!Config.fuzzy)
            return 0

        const fuzzy = root._fuzzyQuality(term, text)
        if (fuzzy === null || fuzzy < Config.minimumScore)
            return 0
        return 0.6 * fuzzy
    }

    function _fuzzyQuality(needle, text) {
        const n = needle.length
        if (n === 0)
            return null

        let ni = 0
        let score = 0
        let previous = -2

        for (let hi = 0; hi < text.length && ni < n; hi++) {
            if (text.charAt(hi) !== needle.charAt(ni))
                continue

            score += 1
            if (hi === previous + 1)
                score += 2 // consecutive characters are strongly preferred
            if (hi === 0 || !root._isWordChar(text.charAt(hi - 1)))
                score += 1.5 // start of a word
            previous = hi
            ni++
        }

        if (ni < n)
            return null

        return score / (n * 4.5)
    }

    function _isWordChar(ch) {
        return (ch >= "a" && ch <= "z") || (ch >= "0" && ch <= "9")
    }
}
