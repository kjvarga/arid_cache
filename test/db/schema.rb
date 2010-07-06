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