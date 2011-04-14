RSpec::Matchers.define :include_keys do |*expected|
  
  match do |actual|
    check_all_present(actual, expected) == []
  end

  failure_message_for_should do |actual|
    "expected key #{check_all_present(actual, expected).first} but did not see it in #{actual.keys.map(&:to_sym)}"
   end

   def check_all_present actual, expected
     keys_we_have = actual.keys.map(&:to_sym)
     expected = [expected] unless expected.is_a?(Array)
     remainder = expected.map(&:to_sym) - keys_we_have
   end
end

RSpec::Matchers.define :match_object do |object, *expected_matching_keys|

  match do |actual|
    check_specified_keys_match(actual, object, expected_matching_keys) == []
  end

  failure_message_for_should do |actual|
    offending_key = check_specified_keys_match(actual, object, expected_matching_keys).first
    "expected match for #{offending_key} but it did not. Expected: #{object.send(offending_key).inspect} but got #{actual[offending_key].inspect}"
  end

  def check_specified_keys_match actual, object, expected_matches
    expected_matches = [expected_matches] unless expected_matches.is_a?(Array)
    expected_matches.map(&:to_sym).map { |key| key unless (object.send(key) == actual[key]) }.compact
  end
end
