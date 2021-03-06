# Get stuff before polluting namespace
aRawObjects = ObjectSpace.each_object(Class).to_a + ObjectSpace.each_object(Module).to_a

require_relative '../lib/ruby-inspector/object-data'

hObjects = ObjectData.load_objects(aRawObjects)

require_relative '../lib/ruby-inspector/server'

srv = RubyInspector::Server.new(hObjects)
trap('INT') { srv.shutdown }
srv.start

# Kernel.global_variables
