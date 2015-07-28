TypescriptImportView = require './typescript-import-view'
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

    @index = state || {};

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @typescriptImportView.destroy()

  serialize: ->
    @index

  goToSymbol: ->


  insert: ->
      console.log(@index);
      path = require('path')
      editor = atom.workspace.getActiveTextEditor()
      selection = editor.getSelectedText().trim()
      filePath = editor.getPath();
      symbolLocation = @index[selection]
      if symbolLocation
        fileFolder = path.resolve(filePath + '/..')
        relative = path.relative(fileFolder, symbolLocation).replace(/\.(js|ts)$/, '');
        console.log('filePath, symbolLocation, relative', filePath, symbolLocation);
        importClause = "\nimport #{selection} from '#{relative}';"
        editor.setTextInBufferRange([[0,0], [0,0]], importClause + '\n')
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
