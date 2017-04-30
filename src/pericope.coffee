class Pericope
  class @Range
    constructor: (@low, @high)->
    size: -> (@high - @low) + 1



  @parse: (text)->
    {originalString, book, ranges} = Pericope.matchOne(text) ? {}
    return null unless book and ranges

    pericope = new Pericope(book, ranges)
    pericope.originalString = originalString
    pericope

  constructor: (@book, @ranges)->
    @bookName = Pericope.BOOK_NAMES[@book]



  toString: (options={})->
    "#{@bookName} #{@wellFormattedReference(options)}"

  wellFormattedReference: (options={})->
    recentChapter = null # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recentChapter = 1 unless Pericope.hasChapters(@book)

    verseRangeSeparator = options.verseRangeSeparator ? "–" # en-dash
    chapterRangeSeparator = options.chapterRangeSeparator ? "—" # em-dash
    verseListSeparator = options.verseListSeparator ? ", "
    chapterListSeparator = options.chapterListSeparator ? "; "
    alwaysPrintVerseRange = options.alwaysPrintVerseRange ? false

    s = ""
    for i in [0...@ranges.length]
      range = @ranges[i]
      minChapter = Pericope.getChapter(range.low)
      minVerse = Pericope.getVerse(range.low)
      maxChapter = Pericope.getChapter(range.high)
      maxVerse = Pericope.getVerse(range.high)

      if i > 0
        if recentChapter == minChapter
          s += verseListSeparator
        else
          s += chapterListSeparator

      if minVerse == 1 and maxVerse >= Pericope.lastVerseOf(@book, maxChapter) and !alwaysPrintVerseRange
        s += minChapter
        s += "#{chapterRangeSeparator}#{maxChapter}" if maxChapter > minChapter
      else
        if recentChapter == minChapter
          s += minVerse
        else
          recentChapter = minChapter
          s += "#{minChapter}:#{minVerse}"

        if range.size() > 1
          if minChapter == maxChapter
            s += "#{verseRangeSeparator}#{maxVerse}"
          else
            recentChapter = maxChapter
            s += "#{chapterRangeSeparator}#{maxChapter}:#{maxVerse}"
    s



  @matchOne: (text)->
    @matchAll(text)[0]

  @matchAll: (text, callback)->
    results = []
    callback ?= (attributes)-> results.push(attributes)

    @PERICOPE_PATTERN.lastIndex = 0
    while match = @PERICOPE_PATTERN.exec(text)
      # There's a separate capture group for each book of the Bible
      # Get the index of the first one that isn't undefined
      i = 1 # (The first capture is the whole match)
      i += 1 while match[i] is undefined and i < match.length
      book = @BOOK_IDS[i]

      ranges = @parseReference(book, match[match.length - 1]) if book
      if ranges?.length
        callback
          originalString: match[0]
          book: book
          ranges: ranges

    results

  @parseReference: (book, reference)->
    ranges = @normalizeReference(reference).split /[,;]/
    @parseRanges(book, ranges)

  @normalizeReference: (reference)->
    for [regex, replacement] in @REFERENCE_NORMALIZATIONS
      reference = reference.replace(regex, replacement)
    reference

  @parseRanges: (book, ranges)->
    recentChapter = null # e.g. in 12:1-8, remember that 12 is the chapter when we parse the 8
    recentChapter = 1 unless @hasChapters(book)
    for range in ranges
      range = range.split('-') # parse the low end of a verse range and the high end separately
      range.push range[0] if range.length < 2 # treat 12:4 as 12:4-12:4
      lowerChapterAndVerse = (+d for d in range[0].split(':')) # parse "3:28" to [3,28]
      upperChapterAndVerse = (+d for d in range[1].split(':')) # parse "3:28" to [3,28]

      # treat Mark 3-1 as Mark 3-3 and, eventually, Mark 3:1-35
      if lowerChapterAndVerse.length == 1 and
         upperChapterAndVerse.length == 1 and
         upperChapterAndVerse[0] < lowerChapterAndVerse[0]
        upperChapterAndVerse = lowerChapterAndVerse.slice() # clone lowerChapterAndVerse


      # Make sure the low end of the range and the high end of the range
      # are composed of arrays with two appropriate values: [chapter, verse]
      chapterRange = false
      if lowerChapterAndVerse.length < 2
        if recentChapter
          lowerChapterAndVerse.unshift recentChapter # When parsing 11 in "12:1-8,11" remember that 12 is the chapter
        else
          lowerChapterAndVerse[0] = @toValidChapter(book, lowerChapterAndVerse[0])
          lowerChapterAndVerse.push 1 # no verse specified; this is a range of chapters, start with verse 1
          chapterRange = true
      else
        lowerChapterAndVerse[0] = @toValidChapter(book, lowerChapterAndVerse[0])
      lowerChapterAndVerse[1] = @toValidVerse(book, lowerChapterAndVerse...)


      if upperChapterAndVerse.length < 2
        if chapterRange
          upperChapterAndVerse[0] = @toValidChapter(book, upperChapterAndVerse[0])
          upperChapterAndVerse.push @lastVerseOf(book, upperChapterAndVerse[0]) # this is a range of chapters, end with the last verse
        else
          upperChapterAndVerse.unshift lowerChapterAndVerse[0] # e.g. parsing 8 in 12:1-8 => remember that 12 is the chapter
      else
        upperChapterAndVerse[0] = @toValidChapter(book, upperChapterAndVerse[0])
      upperChapterAndVerse[1] = @toValidVerse(book, upperChapterAndVerse...)


      recentChapter = upperChapterAndVerse[0] # remember the last chapter

      new @Range(@getId(book, lowerChapterAndVerse...), @getId(book, upperChapterAndVerse...))



  @toValidBook = (book)-> @coerceToRange(book, new @Range(1, 66))
  @toValidChapter = (book, chapter)-> @coerceToRange(chapter, new @Range(1, @lastChapterOf(book)))
  @toValidVerse = (book, chapter, verse)-> @coerceToRange(verse, new @Range(1, @lastVerseOf(book, chapter)))
  @getId = (book, chapter, verse)->
    book = @toValidBook(book)
    chapter = @toValidChapter(book, chapter)
    verse = @toValidVerse(book, chapter, verse)
    book * 1000000 + chapter * 1000 + verse
  @coerceToRange = (value, range)->
    value = range.low if value < range.low
    value = range.high if value > range.high
    value



  @BOOK_PATTERN = /\b(?:(?:(?:3|iii|third|3rd)\s*(?:(john|joh|jon|jhn|jh|jo|jn)))|(?:(?:2|ii|second|2nd)\s*(?:(samuels|samuel|sam|sa|sm)|(kings|king|kngs|kgs|kg|k)|(chronicles|chronicle|chron|chrn|chr)|(john|joh|jon|jhn|jh|jo|jn)|(corinthians?|cor?|corint?h?|corth)|(thessalonians?|thes{1,}|the?s?)|(timothy|tim|tm|ti)|(peter|pete|pet|ptr|pe|pt|pr)))|(?:(?:1|i|first|1st)\s*(?:(samuels|samuel|sam|sa|sm)|(kings|king|kngs|kgs|kg|k)|(chronicles|chronicle|chron|chrn|chr)|(john|joh|jon|jhn|jh|jo|jn)|(corinthians?|cor?|corint?h?|corth)|(thessalonians?|thes{1,}|the?s?)|(timothy|tim|tm|ti)|(peter|pete|pet|ptr|pe|pt|pr)))|(genesis|gen|gn|ge)|(exodus|exod|exo|exd|ex)|(leviticus|lev|levi|le|lv)|(numbers|number|numb|num|nmb|nu|nm)|(deuteronomy|deut|deu|dt)|(joshua|josh|jsh|jos)|(judges|jdgs|judg|jdg)|(ruth|rut|rth|ru)|(isaiah|isa|is|ia|isai|isah)|(ezra|ezr)|(nehemiah|neh|ne)|(esther|esth|est|es)|(job|jb)|(psalms|psalm|pslms|pslm|psm|psa|ps)|(proverbs|proverb|prov|prv|prvb|prvbs|pv)|(ecclesiastes|eccles|eccl|ecc|ecl)|((?:the\s?)?song\s?of\s?solomon|(?:the\s?)?song\s?of\s?songs|sn?gs?|songs?|so?s|sol?|son|s\s?of\s?\ss)|(jeremiah?|jer?|jr|jere)|(lamentations?|lam?|lm)|(ezekiel|ezek|eze|ezk)|(daniel|dan|dn|dl|da)|(hosea|hos|ho|hs)|(joel|jl)|(amos|amo|ams|am)|(obadiah|obadia|obad|oba|obd|ob)|(jonah|jon)|(micah|mica|mic|mi)|(nahum|nah|nahu|na)|(habakk?uk|habk?)|(zephaniah?|ze?ph?)|(haggai|ha?gg?)|(zechariah?|ze?ch?)|(malachi|mal)|(matthew|matt|mat|ma|mt)|(mark|mrk|mk)|(luke|luk|lk|lu)|(john|joh|jon|jhn|jh|jo|jn)|(acts|act|ac)|(romans|roman|roms|rom|rms|ro|rm)|(galatians|galatian|galat|gala|gal|ga)|(ephesians?|eph?|ephe?s?)|(philippians?|phi?l|php|phi|philipp?)|(colossi?ans?|col?)|(titus|tit|ti)|(philemon|phl?mn?|philem?)|(hebrews|hebrew|heb)|(james|jam|jas|jm|js|ja)|(jude)|(revelations|revelation|revel|rev|rv|re))/i
  @REFERENCE_PATTERN = /(?:\s*\d{1,3})(?:\s*[:"\.]\s*\d{1,3}[ab]?(?:\s*[,;]\s*(?:\d{1,3}[:"\.])?\s*\d{1,3}[ab]?)*)?(?:\s*[-–—]\s*(?:\d{1,3}\s*[:"\.])?(?:\d{1,3}[ab]?)(?:\s*[,;]\s*(?:\d{1,3}\s*[:"\.])?\s*\d{1,3}[ab]?)*)*/
  @PERICOPE_PATTERN = new RegExp("(?:#{@BOOK_PATTERN.source})\\.?(#{@REFERENCE_PATTERN.source})", 'ig')

  # The order books of the Bible are matched
  @BOOK_IDS = [null,64,10,12,14,63,47,53,55,61,9,11,13,62,46,52,54,60,1,2,3,4,5,6,7,8,23,15,16,17,18,19,20,21,22,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,48,49,50,51,56,57,58,59,65,66]

  @BOOK_NAMES = [null, 'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalm', 'Proverbs', 'Ecclesiastes', 'Song of Songs', 'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John ', '2 John', '3 John', 'Jude', 'Revelation']

  @VERSES_PER_CHAPTER = [null, [null,31,25,24,26,32,22,24,22,29,32,32,20,18,24,21,16,27,33,38,18,34,24,20,67,34,35,46,22,35,43,55,32,20,31,29,43,36,30,23,23,57,38,34,34,28,34,31,22,33,26],[null,22,25,22,31,23,30,25,32,35,29,10,51,22,31,27,36,16,27,25,26,36,31,33,18,40,37,21,43,46,38,18,35,23,35,35,38,29,31,43,38],[null,17,16,17,35,19,30,38,36,24,20,47,8,59,57,33,34,16,30,37,27,24,33,44,23,55,46,34],[null,54,34,51,49,31,27,89,26,23,36,35,16,33,45,41,50,13,32,22,29,35,41,30,25,18,65,23,31,40,16,54,42,56,29,34,13],[null,46,37,29,49,33,25,26,20,29,22,32,32,18,29,23,22,20,22,21,20,23,30,25,22,19,19,26,68,29,20,30,52,29,12],[null,18,24,17,24,15,27,26,35,27,43,23,24,33,15,63,10,18,28,51,9,45,34,16,33],[null,36,23,31,24,31,40,25,35,57,18,40,15,25,20,20,31,13,31,30,48,25],[null,22,23,18,22],[null,28,36,21,22,12,21,17,22,27,27,15,25,23,52,35,23,58,30,24,42,15,23,29,22,44,25,12,25,11,31,13],[null,27,32,39,12,25,23,29,18,13,19,27,31,39,33,37,23,29,33,43,26,22,51,39,25],[null,53,46,28,34,18,38,51,66,28,29,43,33,34,31,34,34,24,46,21,43,29,53],[null,18,25,27,44,27,33,20,29,37,36,21,21,25,29,38,20,41,37,37,21,26,20,37,20,30],[null,54,55,24,43,26,81,40,40,44,14,47,40,14,17,29,43,27,17,19,8,30,19,32,31,31,32,34,21,30],[null,17,18,17,22,14,42,22,18,31,19,23,16,22,15,19,14,19,34,11,37,20,12,21,27,28,23,9,27,36,27,21,33,25,33,27,23],[null,11,70,13,24,17,22,28,36,15,44],[null,11,20,32,23,19,19,73,18,38,39,36,47,31],[null,22,23,15,17,14,14,10,17,32,3],[null,22,13,26,21,27,30,21,22,35,22,20,25,28,22,35,22,16,21,29,29,34,30,17,25,6,14,23,28,25,31,40,22,33,37,16,33,24,41,30,24,34,17],[null,6,12,8,8,12,10,17,9,20,18,7,8,6,7,5,11,15,50,14,9,13,31,6,10,22,12,14,9,11,12,24,11,22,22,28,12,40,22,13,17,13,11,5,26,17,11,9,14,20,23,19,9,6,7,23,13,11,11,17,12,8,12,11,10,13,20,7,35,36,5,24,20,28,23,10,12,20,72,13,19,16,8,18,12,13,17,7,18,52,17,16,15,5,23,11,13,12,9,9,5,8,28,22,35,45,48,43,13,31,7,10,10,9,8,18,19,2,29,176,7,8,9,4,8,5,6,5,6,8,8,3,18,3,3,21,26,9,8,24,13,10,7,12,15,21,10,20,14,9,6],[null,33,22,35,27,23,35,27,36,18,32,31,28,25,35,33,33,28,24,29,30,31,29,35,34,28,28,27,28,27,33,31],[null,18,26,22,16,20,12,29,17,18,20,10,14],[null,17,17,11,16,16,13,13,14],[null,31,22,26,6,30,13,25,22,21,34,16,6,22,32,9,14,14,7,25,6,17,25,18,23,12,21,13,29,24,33,9,20,24,17,10,22,38,22,8,31,29,25,28,28,25,13,15,22,26,11,23,15,12,17,13,12,21,14,21,22,11,12,19,12,25,24],[null,19,37,25,31,31,30,34,22,26,25,23,17,27,22,21,21,27,23,15,18,14,30,40,10,38,24,22,17,32,24,40,44,26,22,19,32,21,28,18,16,18,22,13,30,5,28,7,47,39,46,64,34],[null,22,22,66,22,22],[null,28,10,27,17,17,14,27,18,11,22,25,28,23,23,8,63,24,32,14,49,32,31,49,27,17,21,36,26,21,26,18,32,33,31,15,38,28,23,29,49,26,20,27,31,25,24,23,35],[null,21,49,30,37,31,28,28,27,27,21,45,13],[null,11,23,5,19,15,11,16,14,17,15,12,14,16,9],[null,20,32,21],[null,15,16,15,13,27,14,17,14,15],[null,21],[null,17,10,10,11],[null,16,13,12,13,15,16,20],[null,15,13,19],[null,17,20,19],[null,18,15,20],[null,15,23],[null,21,13,10,14,11,15,14,23,17,12,17,14,9,21],[null,14,17,18,6],[null,25,23,17,25,48,34,29,34,38,42,30,50,58,36,39,28,27,35,30,34,46,46,39,51,46,75,66,20],[null,45,28,35,41,43,56,37,38,50,52,33,44,37,72,47,20],[null,80,52,38,44,39,49,50,56,62,42,54,59,35,35,32,31,37,43,48,47,38,71,56,53],[null,51,25,36,54,47,71,53,59,41,42,57,50,38,31,27,33,26,40,42,31,25],[null,26,47,26,37,42,15,60,40,43,48,30,25,52,28,41,40,34,28,41,38,40,30,35,27,27,32,44,31],[null,32,29,31,25,21,23,25,39,33,21,36,21,14,23,33,27],[null,31,16,23,21,13,20,40,13,27,33,34,31,13,40,58,24],[null,24,17,18,18,21,18,16,24,15,18,33,21,14],[null,24,21,29,31,26,18],[null,23,22,21,32,33,24],[null,30,30,21,23],[null,29,23,25,18],[null,10,20,13,18,28],[null,12,17,18],[null,20,15,16,16,25,21],[null,18,26,17,22],[null,16,15,15],[null,25],[null,14,18,19,16,14,20,28,13,28,39,40,29,25],[null,27,26,18,17,20],[null,25,25,22,19,14],[null,21,22,18],[null,10,29,24,21,21],[null,13],[null,15],[null,25],[null,20,29,22,11,14,17,17,13,21,11,19,17,18,20,8,21,18,24,21,15,27,21]]

  @REFERENCE_NORMALIZATIONS = [
    [/(\d+)[".](\d+)/g, '$1:$2'], # 12"5 and 12.5 -> 12:5
    [/[–—]/g,           '-'],     # convert em dash and en dash to -
    [/[^0-9,:;\-–—]/g,  '']       # remove everything but [0-9,;:-]
  ]

  @lastChapterOf = (book)-> @VERSES_PER_CHAPTER[book].length - 1
  @lastVerseOf = (book, chapter)-> @VERSES_PER_CHAPTER[book][chapter]
  @hasChapters = (book)-> @lastChapterOf(book) > 1

  @getBook: (id)-> Math.round id / 1000000 # the book is everything left of the least significant 6 digits
  @getChapter: (id)-> Math.round (id % 1000000) / 1000 # the chapter is the 3rd through 6th most significant digits
  @getVerse: (id)-> id % 1000 # the verse is the 3 least significant digits



module.exports = Pericope
