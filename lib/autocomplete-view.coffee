_ = require 'underscore-plus'
process = require 'child_process'
path = require 'path'
{$, $$, Range, SelectListView}  = require 'atom'

module.exports =
class AutocompleteView extends SelectListView
  currentBuffer: null
  wordList: null
  wordRegex: /\w+/g
  originalSelectionBufferRanges: null
  originalCursorPosition: null
  aboveCursor: false

  initialize: (@editorView) ->
    super
    @addClass('autocomplete-jedi popover-list')
    {@editor} = @editorView
    @handleEvents()
    @setCurrentBuffer(@editor.getBuffer())

  getFilterKey: ->
    'full'

  viewForItem: ({full}) ->
    $$ ->
      @li =>
        @span full

  handleEvents: ->
    @list.on 'mousewheel', (event) -> event.stopPropagation()

    @editorView.on 'editor:path-changed', => @setCurrentBuffer(@editor.getBuffer())
    @editorView.command 'autocomplete-jedi:toggle', =>
      if @hasParent()
        @cancel()
      else
        @attach()
    @editorView.command 'autocomplete-jedi:next', => @selectNextItemView()
    @editorView.command 'autocomplete-jedi:previous', => @selectPreviousItemView()

    @filterEditorView.preempt 'textInput', ({originalEvent}) =>
      text = originalEvent.data
      unless text.match(@wordRegex)
        @confirmSelection()
        @editor.insertText(text)
        false

  setCurrentBuffer: (@currentBuffer) ->

  selectItemView: (item) ->
    super
    if match = @getSelectedItem()
      @replaceSelectedTextWithMatch(match)

  selectNextItemView: ->
    super
    false

  selectPreviousItemView: ->
    super
    false

  confirmed: (match) ->
    @editor.getSelections().forEach (selection) -> selection.clear()
    @cancel()
    return unless match
    @replaceSelectedTextWithMatch match
    @editor.getCursors().forEach (cursor) ->
      position = cursor.getBufferPosition()
      cursor.setBufferPosition([position.row, position.column + match.suffix.length])

  cancelled: ->
    super
    @editor.abortTransaction()
    @editor.setSelectedBufferRanges(@originalSelectionBufferRanges)
    @editorView.focus()

  attach: ->
    @editor.beginTransaction()
    @aboveCursor = false
    @originalSelectionBufferRanges = @editor.getSelections().map (selection) -> selection.getBufferRange()
    @originalCursorPosition = @editor.getCursorScreenPosition()
    return @cancel() unless @allPrefixAndSuffixOfSelectionsMatch()

    # get our autocomplete shit here
    point = @editor.getCursorScreenPosition()
    pyfile = @editor.getBuffer().getPath()
    console.log('Inspecing: ' + pyfile)
    args = [path.resolve(__dirname, 'completions.py'), @editor.getText(), point.row + 1, point.column, pyfile]
    @jediProc = process.spawn('python', args)

    @dataOut = ""
    me = @
    @jediProc.stdout.on 'data', (line) =>
      me.dataOut += line.toString() + '\n'
    @jediProc.on 'exit', (exit_code, signal) ->
      tempArr = me.dataOut.split('\n')
      me.wordList = []
      for h in tempArr
        t = h.split(':::')
        if t[1]?
          word = t[0]
          suffix = t[1]
          prefix = word.substring(0, word.lastIndexOf(suffix))
          typee = t[2]
          full = "#{word} <#{typee}>"
          if word.charAt(0) isnt '_'
            me.wordList.push({word: word, prefix: prefix, suffix: '', full: full})

      # select if only one match else show list
      if me.wordList.length is 1
        me.confirmSelection()
      me.setItems(me.wordList)
      me.editorView.appendToLinesView(me)
      me.setPosition()
      me.focusFilterEditor()

  setPosition: ->
    {left, top} = @editorView.pixelPositionForScreenPosition(@originalCursorPosition)
    height = @outerHeight()
    width = @outerWidth()
    potentialTop = top + @editorView.lineHeight
    potentialBottom = potentialTop - @editorView.scrollTop() + height
    parentWidth = @parent().width()

    left = parentWidth - width if left + width > parentWidth
    if @aboveCursor or potentialBottom > @editorView.outerHeight()
      @aboveCursor = true
      @css(left: left, top: top - height, bottom: 'inherit')
    else
      @css(left: left, top: potentialTop, bottom: 'inherit')

  replaceSelectedTextWithMatch: (match) ->
    newSelectedBufferRanges = []
    selections = @editor.getSelections()

    selections.forEach (selection, i) =>
      startPosition = selection.getBufferRange().start
      buffer = @editor.getBuffer()
      selection.deleteSelectedText()
      cursorPosition = @editor.getCursors()[i].getBufferPosition()
      buffer.delete(Range.fromPointWithDelta(cursorPosition, 0, match.suffix.length))
      buffer.delete(Range.fromPointWithDelta(cursorPosition, 0, -match.prefix.length))
      infixLength = match.word.length - match.prefix.length - match.suffix.length
      newSelectedBufferRanges.push([startPosition, [startPosition.row, startPosition.column + infixLength]])

    @editor.insertText(match.word)
    @editor.setSelectedBufferRanges(newSelectedBufferRanges)

  prefixAndSuffixOfSelection: (selection) ->
    selectionRange = selection.getBufferRange()
    lineRange = [[selectionRange.start.row, 0], [selectionRange.end.row, @editor.lineLengthForBufferRow(selectionRange.end.row)]]
    [prefix, suffix] = ["", ""]

    @currentBuffer.scanInRange @wordRegex, lineRange, ({match, range, stop}) ->
      stop() if range.start.isGreaterThan(selectionRange.end)

      if range.intersectsWith(selectionRange)
        prefixOffset = selectionRange.start.column - range.start.column
        suffixOffset = selectionRange.end.column - range.end.column
        prefix = match[0][0...prefixOffset] if range.start.isLessThan(selectionRange.start)
        suffix = match[0][suffixOffset..] if range.end.isGreaterThan(selectionRange.end)

    {prefix, suffix}

  allPrefixAndSuffixOfSelectionsMatch: ->
    {prefix, suffix} = {}
    @editor.getSelections().every (selection) =>
      [previousPrefix, previousSuffix] = [prefix, suffix]
      {prefix, suffix} = @prefixAndSuffixOfSelection(selection)
      return true unless previousPrefix? and previousSuffix?
      prefix is previousPrefix and suffix is previousSuffix

  afterAttach: (onDom) ->
    if onDom
      widestCompletion = parseInt(@css('min-width')) or 0
      @list.find('span').each ->
        widestCompletion = Math.max(widestCompletion, $(this).outerWidth())
      @list.width(widestCompletion)
      @width(@list.outerWidth())

  populateList: ->
    super
    @setPosition()
