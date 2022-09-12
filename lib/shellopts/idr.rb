module ShellOpts
  module Idr
    class Node
    end

    class Command < Node
      attr_reader :group # A Doc::CommandGroup object

    end

    class Option < Node
      attr_reader :group # A Doc::OptionGroup object
    end
  end

end
