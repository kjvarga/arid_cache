require 'active_record'

# Create an in-memory sqlite3 database
ActiveRecord::Base.establish_connection(
  :adapter  => "sqlite3",
  :database => ":memory:"
)

# Schema
ActiveRecord::Base.silence do
  ActiveRecord::Migration.verbose = false

  ActiveRecord::Schema.define do
    create_table "users", :force => true do |t|
      t.column "name",  :text
      t.column "email", :text
      t.timestamps
    end

    create_table "companies", :force => true do |t|
      t.column "name",  :text
      t.column "owner_id", :integer
      t.column "country_id", :integer
      t.column "employees", :integer
      t.timestamps
    end

    create_table "empty_user_relations", :force => true do |t|
      t.column "user_id", :integer
    end
  end
end

Dir[File.join(File.dirname(__FILE__), 'models', '*.rb')].each { |f| require f }