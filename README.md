# Search Me

## Installation

```
gem install search_me
```

Or add this to your Gemfile

```
gem 'search_me'
```

## Adding search_me functionality to an Active Record Model

```
class Book < ActiveRecord::Base

  has_many :credited_authors
  has_many :authors, through: :credited_authors

  has_one :publisher

  belongs_to :owner

  # All SearchMe::Search class Methods should come after ALL
  # ActiveRecord Reflections have been defined
  
  # Extend the class Methods
  extend SearchMe::Search
  extend SearchMe::Filters

  # Add search fields for the simple search
  attr_search :name
  attr_search :first_name, :last_name, type: :authors
  attr_search :name, type: :publisher
  attr_search :name, type: :owner

  # Add blocks to override default action for field in advanced search
  alias_advanced_search :published_at do |term|
    date = if term.respond_to?(:to_date)
      term.to_date
    else
      Date.new(term.to_i) 
    end

    # BTW this is for sqlite3
    "strftime('%Y', books.published_at) = '#{date.year}'"

    # You could do this if you are using MySQL
    #"YEAR(books.published) = #{date.year}"
  end

  alias_advanced_search :name, type: :authors do |term|
    first = "COALESCE(authors.i_first_name, '')"
    last  = "COALESCE(authors.i_last_name, '')"
    "CONCAT(#{first}, ' ', #{last}) LIKE '%#{term}%'" 
  end
end
```

## Query the database with SearchMe#Search.search and SearchMe#Search.advanced_search
You will recieve the following queries from the `Book.search` and `Book.advanced_search` methods:

```
$  Book.search('Chuck')
 => "SELECT \"books\".* FROM \"books\" WHERE (CAST(books.name AS CHAR) LIKE '%chuck%' OR id IN (1,2,-5318008) OR publisher_id IN (-5318008) OR owner_id IN (-5318008))"
```

```
$  Book.advanced_search(simple: { name: 'Fight', published_at: 1999 }, authors: { name: 'Chuck P'}, publisher: { name: 'random', city: 'chicago' }, owner: { name: 'library', city: 'baltimore' })
 => "SELECT \"books\".* FROM \"books\" WHERE (CAST(books.name AS CHAR) LIKE '%Fight%' AND strftime('%Y', books.published_at) = '1999' AND id IN (1,2,-5318008) AND publisher_id IN (1,-5318008) AND owner_id IN (1,-5318008))"
```

If you are wondering what the -5318008 is in the query, this is a number that we assume will never be an id. Could also be nil, but we like this number.

## Contributing

* Any feedback would help.
* Any reasonable pull requests will be accepted. Just make sure you leave an explanation in the commit.
* I am sure there are much better tools out there for doing simple searches like these, so if search_me doesn't cut it for you, then please look for them.
