SubAtom = require 'sub-atom';

{CompositeDisposable} = require 'atom'

module.exports = TypescriptImport =
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'typescript-import:insert': => @insert()
    @subscriptions.add atom.commands.add 'atom-workspace', 'typescript-import:build-index': => @buildIndex()
    @subscriptions.add atom.commands.add 'atom-workspace', 'typescript-import:go-to-declaration': => @goToDeclaration()

    @index = state || {};
    @sub = new SubAtom()
    #bindEvent = @bindEvent
    @sub.add(atom.workspace.observeTextEditors((editor) =>
        @bindEvent(editor)
    ))

  bindEvent: (editor) ->
    # console.log('bound event')
    editorView = atom.views.getView(editor)
#    editorView.on 'click.atom-hack',(e)=>
#      console.log (editor.getCursorBufferPosition())

    @sub.add(editorView, 'click', (e) =>
      if (e.metaKey || e.ctrlKey)
        @goToDeclaration()
    )


  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()

  serialize: ->
    @index

  goToDeclaration: ->
    editor = atom.workspace.getActiveTextEditor()
    position = editor.getCursorBufferPosition();
    editor.selectWordsContainingCursors();
    selection = editor.getSelectedText().trim()
    editor.setCursorBufferPosition(position);
    symbol = @index[selection]
    if symbol and selection
      atom.workspace.open(symbol.path)
    else
      atom.commands.dispatch(document.querySelector('atom-text-editor'), 'typescript:go-to-declaration')


  addImportStatement: (importedSymbol, relativePath, isDefaultImport) ->
      editor = atom.workspace.getActiveTextEditor()
      currentText = editor.getText()

      reImports = /\bimport\b(.|\r|\n)+?\bfrom\b(.*)$/gm;
      isDefined = false
      hasImportStatements = false;
      lastMatchIndex = 0
      while(!isDefined && importMatch = reImports.exec(currentText))
        if !@isInComment(importMatch.index, lastMatchIndex, currentText)
          lastMatchIndex = importMatch.index
          hasImportStatements = true
          #TODO check for comments using lastImport
          lastImport = importMatch[0]
          if @containsSymbol(importMatch, importedSymbol)
            isDefined = true
          #TODO handle insertion of default imports (currently: create a new import statement if default import)
          else if !isDefaultImport && @isImportFromFile(importMatch, relativePath)
            newStatement = @insertIntoStatement(importMatch, importedSymbol, isDefaultImport)
            existingImportStatement = {match: importMatch, statement: newStatement}
        else
            lastMatchIndex = importMatch.index

      if isDefined
        atom.notifications.addWarning('Import '+importedSymbol+' is already defined.');
      else
        currentPosition = editor.getCursorBufferPosition()
        if hasImportStatements
          if existingImportStatement
            newStatement = existingImportStatement.statement
            importMatch = existingImportStatement.match
            prefixEnd = importMatch.index
            suffixStart = prefixEnd + importMatch[0].length
            currentText = currentText.substring(0, prefixEnd) + newStatement + currentText.substring(suffixStart)
          else
            importStatement = @createNewImportStatement(importedSymbol, relativePath, isDefaultImport)
            currentText = currentText.replace(lastImport, lastImport + importStatement);
        else
          importStatement = @createNewImportStatement(importedSymbol, relativePath, isDefaultImport)
          referencesMatches= currentText.match(/\/\/\/\s*<reference\s*path.*\/>\s*$/gm)
          nl = @getNewLineChar()
          if referencesMatches
            lastReference = referencesMatches.pop();
            currentText = currentText.replace(lastReference, lastReference + importStatement + nl);
          else
            useStrictMatche = currentText.match(/.*[\'\"]use strict[\'\"].*/)
            if useStrictMatche
              useStrict = useStrictMatche.pop();
              currentText = currentText.replace(useStrict, useStrict + importStatement + nl);
            else
              currentText = importStatement + currentText;
        editor.setText(currentText);
        currentPosition.row++;
        editor.setCursorBufferPosition(currentPosition)

  insert: ->
      editor = atom.workspace.getActiveTextEditor()
      @buildIndex()
      @bindEvent(editor)
      os = require('os')
      path = require('path')
      position = editor.getCursorBufferPosition()
      editor.selectWordsContainingCursors()
      selection = editor.getSelectedText().trim()
      filePath = editor.getPath()
      symbol = @index[selection]

      if symbol && selection
        location = symbol.path;
        defaultImport = symbol.defaultImport;
        fileFolder = path.resolve(filePath + '/..');
        relative = path.relative(fileFolder, location).replace(/\.(jsx?|tsx?)$/, '');
        # Replace the windows path seperator with '/'
        if (os.platform() == 'win32')
            relative = relative.split(path.sep).join('/');

        if(!/^\./.test(relative))
          relative = './' + relative;

        @addImportStatement(selection, relative, defaultImport)
      else
        atom.notifications.addError('Symbol '+selection+' not found.');

  createNewImportStatement: (importedSymbol, relativePath, isDefaultImport) ->
    nl = @getNewLineChar()

    if(isDefaultImport)
      importStatement = "#{nl}import #{importedSymbol} from '#{relativePath}';"
    else
      importStatement = "#{nl}import { #{importedSymbol} } from '#{relativePath}';"


  getNewLineChar: ->
    switch atom.config.get('line-ending-selector.defaultLineEnding')
      when 'CRLF' then return '\r\n'
      when 'LF' then return '\n'
      # when 'OS Default' then
      else
        os = require('os')
        if os.platform() == 'win32'
          return '\r\n'
        else
          return '\n'


  isInComment: (startIndex, previousIndex, text) ->
    if @isInMultiLineComment(startIndex, previousIndex, text)
      return true
    else
      return @isInLineComment(startIndex, previousIndex, text)

  isInLineComment: (startIndex, previousIndex, text) ->
    reLineComment = /\/\//g
    reLineComment.lastIndex = previousIndex

    #find last line-comment before startIndex
    while (match = reLineComment.exec(text)) && match.index < startIndex
      lastComment = match

    #check if last line-comment is in same line as startIndex
    if lastComment
      reNewLine = /\r|\n/g
      reNewLine.lastIndex = lastComment.index
      if match = reNewLine.exec(text)
        #if match.index > startIndex#DEGUB
        #  console.warn('import is within line-comment')
        return match.index > startIndex # if the next NL comes after the import statement -> import statement is within the line-comment

    return false

  isInMultiLineComment: (startIndex, previousIndex, text) ->
    reComment = /\/\*\*?/g
    reClosing = /\*\//
    reComment.lastIndex = previousIndex
    isOpen = false
    #check if last multi-line comment is open for startIndex
    while (commentMatch = reComment.exec(text)) && commentMatch.index < startIndex
      reClosing.lastIndex = commentMatch.index
      if closingMatch = reClosing.exec() && closingMatch.index < startIndex
        isOpen = false
      else
        isOpen = true

    #if isOpen#DEBUG
    #  console.warn('import in within multi-line-comment')

    return isOpen

  isImportFromFile: (regexImportStatement, symbolPath) ->
      importPathRaw = regexImportStatement[2]#regarding index-access [2]: see RegExp definition for matchImports in addImportStatement()
      importPathMatch = /'([^']+)'|"([^"]+)"/gm.exec(importPathRaw);
      if importPathMatch
        if importPathMatch[1]
          importPath = importPathMatch[1]
        else
          importPath = importPathMatch[2]
      if !importPath
        console.log('could not extract file path from import statement', regexImportStatement)
        return false
      start = 0
      end = importPath.length
      if /^\.\/\.\./.test(importPath)
        start = 2
      #TODO normalize paths properly
      importPath = importPath.substring(start, end)
      return (importPath == symbolPath)

  extractSymbolStringFrom: (regexImportStatement) ->
    importStatement = regexImportStatement[0];
    if /\{/gm.test(importStatement)
      strSymbols = /.*\{([^}]+)\}/g.exec(importStatement)
    else
      strSymbols = /.*?import((.|\r|\n)+?)from/g.exec(importStatement)

  containsSymbol: (regexImportStatement, newSymbol) ->
    symbolStrList = @extractSymbolStringFrom(regexImportStatement)
    if !symbolStrList #either import statement was wrongfully detected, or its imported symbols could not be extracted
      return false
    reTest = new RegExp('\\s*' + newSymbol + '\\s*(,|$)', 'gm')
    i = 0
    size = symbolStrList.length
    while i < size
      if reTest.test(symbolStrList[i])
        return true
      ++i
    return false

  insertIntoStatement: (regexImportStatement, newSymbol, isDefaultImport) ->
    #TODO handle default import?: "import {...} form ..." -> "import newSymbol, {...} form ..."
    importStatement = regexImportStatement[0];
    sb = [', ', newSymbol, ' '];
    if /\{/gm.test(importStatement)
      insertIndex = importStatement.lastIndexOf('}');
    else
      insertIndex = /from(.*)$/gm.exec(importStatement).index;#ASSERT there is at least on match, due to RegExp definition in addImportStatement()
      sb[0] = '{ '
      sb.push('}')
    sb.unshift(importStatement.substring(0, insertIndex))
    sb.push(importStatement.substring(insertIndex, importStatement.length))
    return sb.join('')

  buildIndex: ->
    index = @index;
    searchPaths = ['**/*.ts', '**/*.js', '**/*.tsx', '**/*.jsx'];
    symbolPattern = /export\s*default\s*(class|interface|namespace|enum|const|type|function)?\s*(([a-zA-Z0-9])*)/
    atom.workspace.scan(symbolPattern, { paths: searchPaths }, (result) ->
        for res in result.matches
          rawSymbol = res.matchText
          symbol = rawSymbol.match(symbolPattern)[2];
          index[symbol] = { path: result.filePath, defaultImport: true };
      );
    symbolPatternNoDefault = /export *(class|interface|namespace|enum|const|type|function)?\s*(([a-zA-Z0-9])*)/
    atom.workspace.scan(symbolPatternNoDefault, { paths: searchPaths }, (result) ->
        for res in result.matches
          rawSymbol = res.matchText
          symbol = rawSymbol.match(symbolPatternNoDefault)[2];
          index[symbol] = { path: result.filePath, defaultImport: false };
      );
  getIndex: ->
    @index
