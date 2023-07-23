

# The following code doesn't model class relationships so we need to be sure
# that Ast has already been included
raise if !defined? ShellOpts::Ast 

module ShellOpts
  module Ast
    module Format; end

    class Node
      # Main format switcher for Ast objects. It instantiates a formatter
      # object from a class corresponding to the :format argument and let it
      # handle the output. The formatter class refines Ast, augmenting its
      # classes with methods to do the actual output
      def dump(format: :debug)
        formatter = 
            case format
              when :debug; Format::Short::Formatter.new
              when :rspec; Format::RSpec::Formatter.new
            else
              raise ArgumentError, format.inspect
            end
        formatter.format(self)
      end
    end
  end
end

# Requires Ast::Format to be defined
require_relative './ast_debug.rb'
require_relative './ast_rspec.rb'

