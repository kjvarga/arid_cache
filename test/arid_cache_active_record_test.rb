require 'test_helper'
require 'will_paginate'

class AridCacheActiveRecordTest < ActiveRecordTestCase
  
  def setup
    @user = User.first
  end
  
  def test_counts_queries_correctly
    assert_queries(1) { User.all }
  end
  
  def test_returns_valid_results
    @one = @user.cached_companies
    assert_equal @one, @user.companies
    assert @one.size, @user.companies.count
  end
  
  def test_paginates_results
    results = @user.cached_companies(:page => 1, :per_page => 2)
    assert_kind_of WillPaginate::Collection, results
    assert_equal 2, results.size
    assert_equal 5, results.total_entries    
  end
  
  def test_returns_dynamic_count
    assert_equal 5, @user.cached_companies_count
  end
  
  def test_sets_count_as_well
    assert_queries(1) do
      @user.cached_companies
      @user.cached_companies_count
    end
  end
end