ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'factory_bot_rails'

abort("The Rails environment is running in production mode!") if Rails.env.production?

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
# ENV['RAILS_ENV'] ||= 'test'

# require File.expand_path('../../config/environment', __FILE__)
# require 'rspec/rails'
# require 'factory_bot_rails'

# abort("The Rails environment is running in production mode!") if Rails.env.production?

# RSpec.configure do |config|
#   config.use_transactional_fixtures = true

#   config.infer_spec_type_from_file_location!
#   config.filter_rails_from_backtrace!
# end
