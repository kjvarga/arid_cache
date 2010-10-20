require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "AridCache" do
  describe 'results' do
    before :each do
      Company.destroy_all
      @company1 = Company.make(:name => 'a')
      @company2 = Company.make(:name => 'b')
      Company.class_caches do
        ordered_by_name { Company.all(:order => 'name ASC') }
      end
      Company.clear_caches
    end

    it "order should match the original order" do
      3.times do |t|
        results = Company.cached_ordered_by_name
        results.size.should == 2
        results[0].name.should == @company1.name
        results[1].name.should == @company2.name
      end
    end
  
    it "order should match the order option" do
      3.times do |t|
        results = Company.cached_ordered_by_name(:order => 'name DESC')
        results.size.should == 2
        results[0].name.should == @company2.name
        results[1].name.should == @company1.name
      end
    end
    
    it "with order option should go to the database to order" do
      lambda {
        Company.cached_ordered_by_name(:order => 'name DESC')
      }.should query(2)
    end
  end
end
