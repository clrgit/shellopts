

# The following code doesn't model class relationships so we need to be sure
# that Spec has already been included
raise if !defined? ShellOpts::Spec 

module ShellOpts
  module Spec
    module Format; end

    class Node
      # Main format switcher for Spec objects. It instantiates a formatter
      # object from a class corresponding to the :format argument and let it
      # handle the output. The formatter class refines Spec, augmenting it with
      # methods to do the actual output
      def dump(format: :short)
        formatter = 
            case format
              when :short; Format::Short::Formatter.new
              when :rspec; Format::RSpec::Formatter.new
            else
              raise ArgumentError
            end
        formatter.format(self)
      end
    end
  end
end

# Requires Spec::Format to be defined
require_relative './spec_debug.rb'
require_relative './spec_rspec.rb'

