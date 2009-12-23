ActiveRecord::Schema.define do
  create_table "users", :force => true do |t|
    t.column "name",  :text
    t.column "email", :text
  end
  
  create_table "companies", :force => true do |t|
    t.column "name",  :text
    t.column "owner_id", :integer
    t.column "country_id", :integer
    t.column "employees", :integer    
  end
end