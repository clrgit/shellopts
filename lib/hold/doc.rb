module ShellOpts
  # These classes links grammar object and spec objects. An alternative
  # implementation would move the link into the grammar objects but the current
  # model allows for more complex specifications without polluting grammar
  # objects with method for handling of the documentation. It this is not a
  # problem, then the module could be removed
  #
  # Currently it adds #brief to the link
  #
  module Doc
    class Node
      forward_to :descr, :token
      attr_reader :grammar
      attr_reader :descr
      attr_accessor :brief # Initialized by the parser

      def usage = abstract_method

      # Initialize a Doc object. It also sets the #doc attribute on the grammar
      def initialize(grammar, descr)
        constrain grammar, Grammar::Node
        constrain descr, Ast::Description, nil
        @grammar = grammar
        @descr = descr
        @grammar.doc = self
      end
    end

    class Option < Node
      alias_method :option, :grammar

      def initialize(grammar, descr)
        constrain grammar, Grammar::Option
        constrain descr, Ast::OptionGroup
        super
      end
    end

    class Command < Node
      alias_method :command, :grammar
      attr_accessor :arg_descr # Ast::Line object. Initialized by the parser

      def intialize(grammar, descr)
        constrain grammar, Grammar::Command
        constrain descr, Ast::CommandGroup
        super
      end
    end

    class Program < Command
      alias_method :program, :grammar

      def initialize(grammar, ...)
        constrain grammar, Grammar::Program
        super
      end
    end

#   class ArgSpec < Node # Doubtful
#     def initialize(grammar)
#       constrain grammar, Grammar::Ast
#       super(grammar, nil)
#     end
#   end
#
#   class Arg < Node # Doubtful
#     def initialize(grammar)
#       constrain grammar, Grammar::Arg
#       super(grammar, nil)
#     end
#   end
  end
end

