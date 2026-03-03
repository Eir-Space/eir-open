import { useState, useRef, useEffect } from 'react'

export default function SearchBar({ onSearch, placeholder = "Search providers...", value = "" }) {
  const [query, setQuery] = useState(value)
  const [suggestions, setSuggestions] = useState([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const inputRef = useRef(null)
  const suggestionsRef = useRef(null)

  useEffect(() => {
    setQuery(value)
  }, [value])

  // Handle search with debouncing
  const handleSearch = async (searchQuery) => {
    const trimmedQuery = searchQuery.trim()
    
    if (trimmedQuery.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      onSearch(trimmedQuery)
      return
    }

    setIsLoading(true)
    
    try {
      const response = await fetch(`/api/search?q=${encodeURIComponent(trimmedQuery)}&limit=5`)
      const data = await response.json()
      
      if (data.results && data.results.length > 0) {
        // Show provider names as suggestions
        const providerSuggestions = data.results.slice(0, 5).map(provider => ({
          type: 'provider',
          text: provider.name,
          subtitle: provider.location.address,
          provider: provider
        }))
        setSuggestions(providerSuggestions)
      } else if (data.suggestions && data.suggestions.length > 0) {
        // Show term suggestions
        const termSuggestions = data.suggestions.map(suggestion => ({
          type: 'term',
          text: suggestion,
          subtitle: null
        }))
        setSuggestions(termSuggestions)
      } else {
        setSuggestions([])
      }
      
      setShowSuggestions(true)
    } catch (error) {
      console.error('Search suggestions failed:', error)
      setSuggestions([])
    } finally {
      setIsLoading(false)
    }
  }

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      if (query !== value) {
        handleSearch(query)
      }
    }, 300)

    return () => clearTimeout(timer)
  }, [query])

  const handleInputChange = (e) => {
    const newQuery = e.target.value
    setQuery(newQuery)
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      handleSubmit()
    } else if (e.key === 'Escape') {
      setShowSuggestions(false)
    }
  }

  const handleSubmit = () => {
    onSearch(query)
    setShowSuggestions(false)
    inputRef.current?.blur()
  }

  const handleSuggestionClick = (suggestion) => {
    setQuery(suggestion.text)
    onSearch(suggestion.text)
    setShowSuggestions(false)
    inputRef.current?.blur()
  }

  const handleClear = () => {
    setQuery('')
    onSearch('')
    setSuggestions([])
    setShowSuggestions(false)
    inputRef.current?.focus()
  }

  // Close suggestions when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (suggestionsRef.current && !suggestionsRef.current.contains(event.target)) {
        setShowSuggestions(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  return (
    <div className="search-bar-container">
      <div className="search-input-wrapper">
        <div className="search-icon">🔍</div>
        
        <input
          ref={inputRef}
          type="text"
          className="search-input"
          placeholder={placeholder}
          value={query}
          onChange={handleInputChange}
          onKeyPress={handleKeyPress}
          onFocus={() => query.length >= 2 && setShowSuggestions(true)}
        />

        {isLoading && (
          <div className="search-loading">
            <div className="loading-spinner-small"></div>
          </div>
        )}

        {query && (
          <button 
            className="clear-button"
            onClick={handleClear}
            title="Clear search"
          >
            ✕
          </button>
        )}

        <button 
          className="search-button"
          onClick={handleSubmit}
          title="Search"
        >
          Search
        </button>
      </div>

      {/* Search Suggestions */}
      {showSuggestions && suggestions.length > 0 && (
        <div className="search-suggestions" ref={suggestionsRef}>
          {suggestions.map((suggestion, index) => (
            <div
              key={index}
              className={`suggestion-item ${suggestion.type}`}
              onClick={() => handleSuggestionClick(suggestion)}
            >
              <div className="suggestion-main">
                {suggestion.type === 'provider' && <span className="suggestion-icon">🏥</span>}
                {suggestion.type === 'term' && <span className="suggestion-icon">🔍</span>}
                <span className="suggestion-text">{suggestion.text}</span>
              </div>
              
              {suggestion.subtitle && (
                <div className="suggestion-subtitle">
                  {suggestion.subtitle}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Popular Searches (when input is empty and focused) */}
      {showSuggestions && query.length === 0 && (
        <div className="search-suggestions" ref={suggestionsRef}>
          <div className="suggestions-header">Popular searches:</div>
          
          {[
            'vårdcentral Stockholm',
            'dermatologi',
            'ögonmottagning',
            'egen remiss',
            'psykiatri'
          ].map((term, index) => (
            <div
              key={index}
              className="suggestion-item term"
              onClick={() => handleSuggestionClick({ text: term })}
            >
              <div className="suggestion-main">
                <span className="suggestion-icon">💡</span>
                <span className="suggestion-text">{term}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}