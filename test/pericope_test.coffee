assert = require('chai').assert
Pericope = require('../src/pericope')

refute = (expression, message)-> assert(!expression, message)
r = range = (low, high)-> new Pericope.Range(low, high)

describe 'Pericope', ->
  describe 'has the ability to quickly recognize Bible references:', ->
    describe 'BOOK_PATTERN', ->
      it 'should match valid books (including by abbreviations and common misspellings)', ->
        tests =
          'ii samuel':      'ii samuel'
          '1 cor.':         '1 cor'
          'jas':            'jas'
          'song of songs':  'song of songs'
          'song of solomon':'song of solomon'
          'first kings':    'first kings'
          '3rd jn':         '3rd jn'
          'phil':           'phil'
        for test, expectedMatch of tests
          assert Pericope.BOOK_PATTERN.test(test), "Expected Pericope to recognize \"#{test}\" as a potential book"
          assert.equal test.match(Pericope.BOOK_PATTERN)[0], expectedMatch

    describe 'PERICOPE_PATTERN', ->
      it 'should match things that look like pericopes', ->
        tests = [ 'Romans 3:9' ]
        for test in tests
          Pericope.PERICOPE_PATTERN.lastIndex = 0
          assert Pericope.PERICOPE_PATTERN.test(test), "Expected Pericope to recognize \"#{test}\" as a potential pericope"

      it 'should not match things that do not look like pericopes', ->
        tests = [ 'Cross 1', 'Hezekiah 4:3' ]
        for test in tests
          Pericope.PERICOPE_PATTERN.lastIndex = 0
          refute Pericope.PERICOPE_PATTERN.test(test), "Expected Pericope to recognize that \"#{test}\" is not a potential pericope"



  describe 'knows various boundaries in the Bible', ->
    describe 'lastChapterOf', ->
      it 'should return the last chapter in the given book', ->
        tests = [
          [ 1,  50],         # Genesis has 50 chapters
          [19, 150],         # Psalms has 150 chapters
          [65,   1],         # Jude has only 1 chapter
          [66,  22] ]        # Revelation has 22 chapters

        for [book, chapters] in tests
          assert.equal chapters, Pericope.lastChapterOf(book), "Expected Pericope to know the number of chapters in #{Pericope.BOOK_NAMES[book]}"

    describe 'lastVerseOf', ->
      it 'should return the last verse in a given chapter', ->
        tests = [
          [ 1,   9,  29],    # Genesis 9 has 29 verses
          [ 1,  50,  26] ]   # Genesis 50 has 26 verses

        for [book, chapter, verses] in tests
          assert.equal verses, Pericope.lastVerseOf(book, chapter), "Expected Pericope to know the number of verses in #{Pericope.BOOK_NAMES[book]} #{chapter}"

    describe 'hasChapters', ->
      it 'should correctly identify books that don\'t have chapters', ->
        assert Pericope.hasChapters(1),  "Genesis has chapters"
        assert Pericope.hasChapters(23), "Isaiah has chapters"
        refute Pericope.hasChapters(57), "Philemon does not have chapters"
        refute Pericope.hasChapters(65), "Jude does not have chapters"



  describe 'can identify books of the Bible', ->
    it 'should return the integer identifying the book of the Bible', ->
      tests =
        'Romans':   45 # Romans
        'mark':     41 # Mark
        'ps':       19 # Psalms
        'jas':      59 # James

      for input, expectedBook of tests
        assert.equal expectedBook, Pericope.parse("#{input} 1").book, "Expected Pericope to be able to identify \"#{input}\" as book ##{expectedBook}"



  describe 'can parse chapter-and-verse notation identifying Bible references', ->
    describe 'parseReference', ->
      it 'should return an array of verse ranges', ->
        tests = [
          [60, "1:1",         [r(60001001,60001001)]],                          # 1 Peter 1:1
          [19, "1-8",         [r(19001001,19008009)]],                          # Psalm 1-8
          [1,  "1",           [r(1001001,1001031)]],                            # Genesis 1
          [43, "12:1–13:8",   [r(43012001,43013008)]],                          # John 12:1–13:8
          [45, "6:1,4-8",     [r(45006001,45006001), r(45006004,45006008)]]     # Romans 6:1,4-8
        ]
        for [book, reference, expectedRanges] in tests
          assert.deepEqual expectedRanges, Pericope.parseReference(book, reference), "Expected Pericope to be able to parse \"#{reference}\"..."

      it 'should ignore "a" and "b"', ->
        assert.deepEqual [r(39002006,39002009)], Pericope.parseReference(39, "2:6a-9b")

      it 'should work correctly on books with no chapters', ->
        assert.deepEqual [r(65001008,65001010)], Pericope.parseReference(65, "8–10")

      it 'should work with different punctuation, errors for range separators', ->
        expectedResults = [
          r(40003001, 40003001),
          r(40003003, 40003003),
          r(40003004, 40003005),
          r(40003007, 40003007),
          r(40004019, 40004019) ]
        assert.deepEqual expectedResults, Pericope.parseReference(40, "3:1,3,4-5,7,4:19")
        assert.deepEqual expectedResults, Pericope.parseReference(40, "3:1, 3, 4-5, 7; 4:19")

      it 'should forgive various punctuation errors for chapter/verse pairing', ->
        tests = ["1:4-9", "1\"4-9", "1.4-9", "1 :4-9", "1: 4-9"]
        for test in tests
          assert.deepEqual [r(28001004, 28001009)], Pericope.parseReference(28, test)

      it 'should coerce verses to the right range', ->
        assert.deepEqual [r(41001045, 41001045)], Pericope.parseReference(41, "1:452")
        assert.deepEqual [r(41001001, 41001001)], Pericope.parseReference(41, "1:0")

      it 'should coerce chapters to the right range', ->
        assert.deepEqual [r(43021001, 43021001)], Pericope.parseReference(43, "28:1")
        assert.deepEqual [r(43001001, 43001001)], Pericope.parseReference(43, "0:1")



  describe 'can parse Bible references', ->
    describe 'parse', ->
      it 'should work', ->
        pericope = Pericope.parse('ps 1:1-8')
        assert.equal 'Psalm', pericope.bookName, "Expected Pericope to read \"ps\" as \"Psalm\""

      it 'should work when there is no space between the book name and reference', ->
        pericope = Pericope.parse('ps1')
        assert.equal 'Psalm', pericope.bookName, "Expected Pericope to read \"ps\" as \"Psalm\""

      it 'should return null for invalid references', ->
        assert.isNull Pericope.parse('nope'), "Expected Pericope to return null"



  describe 'can format Bible references', ->
    describe 'toString()', ->
      it 'should format Bible references correctly', ->
        tests =
          'James 4:7':                      ['jas 4:7', 'james 4:7', 'James 4.7', 'jas 4 :7', 'jas 4: 7']    # test basic formatting
          '2 Samuel 7':                     ['2 sam 7', 'iisam 7', 'second samuel 7', '2sa 7', '2 sam. 7']   # test chapter range formatting
          'Philemon 8–10':                  ['philemon 8-10', 'philemon 6:8-10']                             # test book with no chapters
          'Philippians 1:1–17; 2:3–5, 17':  ['phil 1:1-17,2:3-5,17']                                         # test comma-separated ranges

          # test the values embedded in the pericope extraction
          'Psalm 37:3–7, 23–24, 39–40':     ['Psalm 37:3–7a, 23–24, 39–40']
          'John 20:19–23':                  ['John 20:19–23']
          'Exodus 2—3':                     ['ex 2-3']
          '2 Peter 3:1':                    ['2 Peter 4.1 ']
          'James 1:13, 20':                 ['(Jas. 1:13, 20) ']
          'John 21:14':                     ['jn 21:14, ']
          'Zechariah 4:7':                  ['zech 4:7, ']
          'Matthew 12:13':                  ['mt 12:13. ']
          'Luke 2':                         ['Luke 2---Maris ']
          'Luke 3:1':                       ['Luke 3\"1---Aliquam ']
          'Acts 13:4–20':                   ['(Acts 13:4-20)']

        for wellFormattedPericope, pericopes of tests
          for pericope in pericopes
            result = Pericope.parse(pericope).toString()
            assert.equal wellFormattedPericope, result,
              "Expected Pericope to parse \"#{pericope}\" and present it as \"#{wellFormattedPericope}\"; but got: \"#{result}\""

      it 'should accept verseRangeSeparator', ->
        assert.equal Pericope.parse('john 1:1-7').toString(verseRangeSeparator: '_'), 'John 1:1_7'

      it 'should accept chapterRangeSeparator', ->
        assert.equal Pericope.parse('john 1-3').toString(chapterRangeSeparator: '_'), 'John 1_3'

      it 'should accept verseListSeparator', ->
        assert.equal Pericope.parse('john 1:1,7').toString(verseListSeparator: '_'), 'John 1:1_7'

      it 'should accept chapterListSeparator', ->
        assert.equal Pericope.parse('john 1:1, 3:1').toString(chapterListSeparator: '_'), 'John 1:1_3:1'

      it 'should accept alwaysPrintVerseRange', ->
        assert.equal Pericope.parse('john 1').toString(alwaysPrintVerseRange: false), 'John 1'
        assert.equal Pericope.parse('john 1').toString(alwaysPrintVerseRange:  true), 'John 1:1–51'
