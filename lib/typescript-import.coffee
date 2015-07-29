TypescriptImportView = require './typescript-import-view'
SubAtom = require 'sub-atom';

{CompositeDisposable} = require 'atom'

module.exports = TypescriptImport =
  typescriptImportView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @typescriptImportView = new TypescriptImportView(state.typescriptImportViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @typescriptImportView.getElement(), visible: false)

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
    @typescriptImportView.destroy()

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

  addImportStatement: (importStatement) ->
      editor = atom.workspace.getActiveTextEditor()
      currentText = editor.getText()
      currentPosition = editor.getCursorBufferPosition()
      importMatches = currentText.match(/import\s*\w*\s*from.*\n/)
      referencesMatches= currentText.match(/\/\/\/\s*<reference\s*path.*\/>\n/g)
      if importMatches
        lastImport = importMatches.pop();
        currentText = currentText.replace(lastImport, lastImport + importStatement);
      else if referencesMatches
        lastReference = referencesMatches.pop();
        currentText = currentText.replace(lastReference, lastReference + '\n' + importStatement);
      else
        currentText = importStatement + currentText;
      editor.setText(currentText);
      currentPosition.row++;
      editor.setCursorBufferPosition(currentPosition)

  insert: ->
      @bindEvent()
      console.log(@index)
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
        console.log('filePath, symbolLocation, relative', filePath, symbolLocation);
        importClause = "import #{selection} from './#{relative}';\n"
        @addImportStatement(importClause)
#        editor.insertText(selection + "\nimport #{selection} from './#{relative}'")
      else
        console.log('No cached data found for symbol', selection)

  buildIndex: ->
    index = @index;
    symbolPattern = /export\s*default\s*(class|function)?\s*(([a-zA-Z])*)/
    atom.workspace.scan(symbolPattern, null, (result) ->
        console.log(result);
        rawSymbol = result.matches[0].matchText
        symbol = rawSymbol.match(symbolPattern)[2];
        index[symbol] = result.filePath;
        console.log('Added', symbol, result.filePath);
      );
  getIndex: ->
    @index
