class << ActiveRecord::Base.connection
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SHOW FIELDS /]

  def execute_with_counting(sql, name = nil, &block)
    $query_count ||= 0
    $query_count  += 1 unless IGNORED_SQL.any? { |r| sql =~ r }
    execute_without_counting(sql, name, &block)
  end

  alias_method_chain :execute, :counting
end