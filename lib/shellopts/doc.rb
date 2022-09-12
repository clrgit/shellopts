module ShellOpts
  module Doc
    class Node
      attr_reader :idr_node
      attr_reader :brief
      attr_reader :fragments
      def usage = abstract_method
    end

    class GroupDoc < Node
      def group = fragments.first 
      def group=(fragment) @fragments = [fragment]
      forward_to :group, :description
    end

    class OptionDoc < GroupDoc
    end

    class CommandDoc < GroupDoc
    end

    class ProgramDoc < Node
      alias_method :sections, :fragments
    end
  end
end

