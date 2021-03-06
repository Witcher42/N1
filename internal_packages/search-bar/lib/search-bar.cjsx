React = require 'react/addons'
classNames = require 'classnames'
{Actions, WorkspaceStore} = require 'nylas-exports'
{Menu, RetinaImg} = require 'nylas-component-kit'
SearchSuggestionStore = require './search-suggestion-store'
_ = require 'underscore'

class SearchBar extends React.Component
  @displayName = 'SearchBar'

  constructor: (@props) ->
    @state =
      query: ""
      focused: false
      suggestions: []
      committedQuery: null

  componentDidMount: =>
    @usub = []
    @usub.push SearchSuggestionStore.listen @_onChange
    @usub.push WorkspaceStore.listen =>
      @setState(focused: false) if @state.focused
    @body_unsubscriber = atom.commands.add 'body', {
      'application:focus-search': @_onFocusSearch
    }
    @search_unsubscriber = atom.commands.add '.search-bar', {
      'search-bar:escape-search': @_clearAndBlur
    }

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    usub() for usub in @usub
    @body_unsubscriber.dispose()
    @search_unsubscriber.dispose()

  render: =>
    inputValue = @_queryToString(@state.query)
    inputClass = classNames
      'input-bordered': true
      'empty': inputValue.length is 0

    headerComponents = [
      <input type="text"
             ref="searchInput"
             key="input"
             className={inputClass}
             placeholder="Search all email"
             value={inputValue}
             onChange={@_onValueChange}
             onFocus={@_onFocus}
             onBlur={@_onBlur} />

      <RetinaImg className="search-accessory search"
                 name="searchloupe.png"
                 key="accessory"
                 mode={RetinaImg.Mode.ContentDark}
                 onClick={@_doSearch} />
      <RetinaImg className="search-accessory clear"
                 name="searchclear.png"
                 key="clear"
                 mode={RetinaImg.Mode.ContentDark}
                 onClick={@_onClearSearch} />
    ]

    itemContentFunc = (item) =>
      if item.divider
        <Menu.Item divider={item.divider} />
      else if item.contact
        <Menu.NameEmailItem name={item.contact.name} email={item.contact.email} />
      else if item.thread
        item.thread.subject
      else
        item.label

    <div className="search-bar">
      <Menu ref="menu"
        className={@_containerClasses()}
        headerComponents={headerComponents}
        items={@state.suggestions}
        itemContent={itemContentFunc}
        itemKey={ (item) -> item.id ? item.label }
        onSelect={@_onSelectSuggestion}
        />
    </div>

  _onFocusSearch: =>
    React.findDOMNode(@refs.searchInput).focus()

  _containerClasses: =>
    classNames
      'focused': @state.focused
      'showing-query': @state.query?.length > 0
      'committed-query': @state.committedQuery?.length > 0
      'search-container': true
      'showing-suggestions': @state.suggestions?.length > 0

  _queryToString: (query) =>
    return "" unless query instanceof Array
    str = ""
    for term in query
      for key,val of term
        if key == "all"
          str += val
        else
          str += val

  _stringToQuery: (str) =>
    return [] unless str
    return [all: str]

  _onValueChange: (event) =>
    Actions.searchQueryChanged(@_stringToQuery(event.target.value))
    if (event.target.value is '')
      @_onClearSearch()

  _onSelectSuggestion: (item) =>
    if item.thread?
      Actions.searchQueryCommitted(null)
      Actions.setFocus({collection: 'thread', item: item.thread})
    else
      Actions.searchQueryCommitted(item.value)

  _onClearSearch: (event) =>
    if @state.committedQuery
      Actions.searchQueryCommitted(null)
    else
      Actions.searchQueryChanged(null)

  _clearAndBlur: =>
    @_onClearSearch()
    React.findDOMNode(@refs.searchInput)?.blur()

  _onFocus: =>
    @setState focused: true

  _onBlur: =>
    # Don't immediately hide the menu when the text input is blurred,
    # because the user might have clicked an item in the menu. Wait to
    # handle the touch event, then dismiss the menu.
    setTimeout =>
      Actions.searchBlurred()
      @setState(focused: false)
    , 150

  _doSearch: =>
    Actions.searchQueryCommitted(@state.query)

  _onChange: => @setState @_getStateFromStores()

  _getStateFromStores: =>
    query: SearchSuggestionStore.query()
    suggestions: SearchSuggestionStore.suggestions()
    committedQuery: SearchSuggestionStore.committedQuery()

module.exports = SearchBar
