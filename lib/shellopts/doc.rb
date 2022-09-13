module ShellOpts
  module Doc
    class Node
      attr_reader :grammar
      forward_to :grammar, :token
      attr_accessor :brief
      attr_reader :fragment

      def usage = abstract_method
      def description = abstract_method # Fragment::Description

      def initialize(grammar, fragment = nil)
        constrain grammar, Idr::Node
        constrain fragment, Fragment::Node, nil
        @grammar = grammar
        @fragments = fragment
      end
    end

    class GroupDoc < Node
      forward_to :group, :description

      def initialize(grammar, group)
        super(grammar, group)
        constrain group, Fragment::Group
      end
    end

    class OptionDoc < GroupDoc
      alias_method :option, :grammar

      def initialize(grammar)
        constrain grammar, Idr::Option
        super(grammar, Fragment::OptionGroup.new(grammar.token))
      end
    end

    class CommandDoc < GroupDoc
      alias_method :command, :grammar

      def intialize(grammar)
        constrain grammar, Idr::Command
        super(grammar, Fragment::CommandGroup.new(grammar.token))
      end
    end

    class ProgramDoc < Node
      alias_method :program, :grammar
      attr_reader :description

      def initialize(grammar)
        constrain grammar, Idr::Command
        super(grammar, Fragment::Description.new(grammar.token))
      end
    end

    class ArgSpecDoc < Node
      def initialize(grammar)
        super(grammar, nil)
      end
    end
  end
end

