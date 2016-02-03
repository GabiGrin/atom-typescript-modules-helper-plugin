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
    console.log('bound event')
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
    symbolLocation = @index[selection]
    if symbolLocation and selection
      atom.workspace.open(symbolLocation)
    else
      atom.commands.dispatch(document.querySelector('atom-text-editor'), 'typescript:go-to-declaration')


  addImportStatement: (importStatement) ->
      editor = atom.workspace.getActiveTextEditor()
      currentText = editor.getText()
      currentPosition = editor.getCursorBufferPosition()
      importMatches = currentText.match(/import\s*\w*\s*from.*\n/g)
      referencesMatches= currentText.match(/\/\/\/\s*<reference\s*path.*\/>\n/g)
      useStrictMatche = currentText.match(/.*[\'\"]use strict[\'\"].*/)
      if importMatches
        lastImport = importMatches.pop();
        currentText = currentText.replace(lastImport, lastImport + importStatement);
      else if referencesMatches
        lastReference = referencesMatches.pop();
        currentText = currentText.replace(lastReference, lastReference + '\n' + importStatement);
      else if useStrictMatche
        useStrict = useStrictMatche.pop();
        currentText = currentText.replace(useStrict, useStrict + '\n' + importStatement);
      else
        currentText = importStatement + currentText;
      editor.setText(currentText);
      currentPosition.row++;
      editor.setCursorBufferPosition(currentPosition)

  insert: ->
      @buildIndex()
      @bindEvent()
      path = require('path')
      editor = atom.workspace.getActiveTextEditor()
      position = editor.getCursorBufferPosition()
      editor.selectWordsContainingCursors()
      selection = editor.getSelectedText().trim()
      filePath = editor.getPath();
      symbolLocation = @index[selection]
      if symbolLocation && selection
        fileFolder = path.resolve(filePath + '/..')
        relative = path.relative(fileFolder, symbolLocation).replace(/\.(js|ts)$/, '');
        importClause = "import #{selection} from './#{relative}';\n"
        @addImportStatement(importClause)
#        editor.insertText(selection + "\nimport #{selection} from './#{relative}'")
      else
        console.log('No cached data found for symbol', selection)

  buildIndex: ->
    index = @index;
    symbolPattern = /export\s*default\s*(class|function)?\s*(([a-zA-Z])*)/
    atom.workspace.scan(symbolPattern, null, (result) ->
        rawSymbol = result.matches[0].matchText
        symbol = rawSymbol.match(symbolPattern)[2];
        index[symbol] = result.filePath;
      );
  getIndex: ->
    @index
