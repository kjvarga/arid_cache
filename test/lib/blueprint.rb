require 'machinist/active_record'
require 'sham'
require 'faker'

Sham.name  { Faker::Name.name }
Sham.company_name { Faker::Company.name }
Sham.email { Faker::Internet.email }

User.blueprint do
  name
  email
end

Company.blueprint do
  name { Sham.company_name }
  employees { rand(200) }
  #owner
end

module Blueprint
  def self.seeds
    10.times do
      user = User.make
      (5 + rand(5)).times do
        Company.make(:owner => user)
      end
    end
  end
end