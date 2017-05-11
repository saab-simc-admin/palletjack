$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../exe', __FILE__)

require 'rspec_structure_matcher'

$EXAMPLE_WAREHOUSE = File.expand_path('../../../examples/warehouse', __FILE__)
