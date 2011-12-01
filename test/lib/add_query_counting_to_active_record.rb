require 'active_record'

class << ActiveRecord::Base.connection
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /SHOW FIELDS/]
  method = AridCache.framework.active_record31? ? :exec_query : :execute
  define_method(:"#{method}_with_counting") do |sql, *args, &block|
    $query_count ||= 0
    $query_count += 1 unless IGNORED_SQL.any? { |ignore| sql =~ ignore }
    send("#{method}_without_counting", sql, *args, &block)
  end
  alias_method :"#{method}_without_counting", method.to_sym
  alias_method method.to_sym, :"#{method}_with_counting"
end
