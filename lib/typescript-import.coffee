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
    symbol = @index[selection]
    if symbol and selection
      atom.workspace.open(symbol.path)
    else
      atom.commands.dispatch(document.querySelector('atom-text-editor'), 'typescript:go-to-declaration')


  addImportStatement: (importStatement) ->
      editor = atom.workspace.getActiveTextEditor()
      currentText = editor.getText()

      if currentText.indexOf(importStatement)>=0
        atom.notifications.addWarning('Import already defined.');
      else
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
      os = require('os')
      path = require('path')
      editor = atom.workspace.getActiveTextEditor()
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

        if(defaultImport)
          importClause = "import #{selection} from '#{relative}';\n"
        else
          importClause = "import {#{selection}} from '#{relative}';\n"
        @addImportStatement(importClause)
#        editor.insertText(selection + "\nimport #{selection} from './#{relative}'")
      else
        atom.notifications.addError('Symbol '+selection+' not found.');

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
