_ = require 'underscore-plus'
AutocompleteView = require './autocomplete-view'

module.exports =
  config:
    includeCompletionsFromAllBuffers: 
      type: 'boolean'
      default: false
    whichPython:
      type: 'string'
      default: 'python'

  autocompleteViews: []
  editorSubscription: null

  activate: ->
    @editorSubscription = atom.workspaceView.eachEditorView (editor) =>
      if editor.attached and not editor.mini
        autocompleteView = new AutocompleteView(editor)
        editor.on 'editor:will-be-removed', =>
          autocompleteView.remove() unless autocompleteView.hasParent()
          _.remove(@autocompleteViews, autocompleteView)
        @autocompleteViews.push(autocompleteView)

  deactivate: ->
    @editorSubscription?.off()
    @editorSubscription = null
    @autocompleteViews.forEach (autocompleteView) -> autocompleteView.remove()
    @autocompleteViews = []
