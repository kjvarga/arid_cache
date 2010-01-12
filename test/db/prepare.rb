require 'active_record'
require 'active_record/fixtures'

# Create an in-memory test database and load the fixures into it
ActiveRecord::Base.establish_connection(
  :adapter  => "sqlite3",
  :database => ":memory:"
)

# Schema
ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false
  load(File.join(File.dirname(__FILE__), 'schema.rb'))
end

# Models
Dir[File.join(File.dirname(__FILE__), '..', 'models', '*.rb')].each { |f| require f }

# Populate
require 'blueprint'
Blueprint.seeds

class << ActiveRecord::Base.connection
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SHOW FIELDS /]

  def execute_with_counting(sql, name = nil, &block)
    $query_count ||= 0
    $query_count  += 1 unless IGNORED_SQL.any? { |r| sql =~ r }
    execute_without_counting(sql, name, &block)
  end

  alias_method_chain :execute, :counting
end