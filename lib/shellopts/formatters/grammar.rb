

# The following code doesn't model class relationships so we need to be sure
# that Grammar has already been included
raise if !defined? ShellOpts::Grammar

module ShellOpts
  module Grammar
    module Format; end

    class Node
      # Main format switcher for Spec objects. It instantiates a formatter
      # object from a class corresponding to the :format argument and let it
      # handle the output. The formatter class refines Spec, augmenting its
      # classes with methods to do the actual output
      def dump(format: :debug)
        formatter = 
            case format
              when :debug; Format::Short::Formatter.new
            else
              raise ArgumentError
            end
        formatter.format(self)
      end
    end
  end
end

require_relative './grammar_debug.rb'

