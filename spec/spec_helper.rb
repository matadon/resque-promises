require 'timeout'
require 'benchmark'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

RSpec.configure do |config|
    config.treat_symbols_as_metadata_keys_with_true_values = true
end
