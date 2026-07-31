ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/user_test_data"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    include UserTestData
  end
end

class ActionDispatch::IntegrationTest
  include SessionTestHelper
end
