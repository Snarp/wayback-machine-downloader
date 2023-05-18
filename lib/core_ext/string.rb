require_relative 'string/tidy_bytes'
require_relative 'string/to_regex'

class String
  include ToRegex::StringMixin
  include TidyBytes::StringMixin
end