module ShellOpts
  module Fragment
    class Node
      attr_reader :parent
      def initialize(parent) = @parent = parent
    end

    class Brief < Node
    end

    class Description < Node
      attr_reader :elements
    end

    class Element < Node
    end

    class Lines < Element
      attr_reader :lines
      def initialize(parent, lines = [])
        super(parent)
        @lines = lines
      end
    end

    class Line < Lines
      def line = lines.first
      def initialize(parent, line)
        super(parent, [lines])
      end
    end

    class Code < Element
    end

    class Paragraph < Element
      attr_reader :text
      def initialize(parent, text)
        super(parent)
        @text = Array(text).flatten.compact.join(" ")
      end
    end

    # An enumeration is a single-line text followed by an indented paragraph
    class Enumeration < Element
      attr_reader :enumerations # Array of (Line, Description) tuples
      def initialize(parent)
        super(parent)
      end
    end

    # A List is an enumeration with the single-line text replaced by a bullet
    class List < Enumeration
      attr_reader :bullet # ".", "%", "o", "*", "-"
      attr_reader :descriptions

      def initialize(bullet)
        constrain bullet, ".", "%", "o", "*", "-"
        @bullet = bullet
        @descriptions = []
      end
    end

    class Definition < Element
      def header(formatter) = abstract_method
      attr_accessor :description
    end

    class Section < Definition
      def header(formatter = nil)
        constrain formatter, Formatter::Formatter, nil
        [@header]
      end

      def initialize(header)
        constrain header, String
        @header = header
      end
    end

    class Group < Definition
      def header(formatter) = formatter.header(self)
      attr_reader :nodes
      def initialize()
        @nodes = []
      end
    end

    class OptionGroup < Group
      alias_method :options, :nodes
    end

    class CommandGroup < Group
      alias_method :commands, :nodes
    end
  end
end










