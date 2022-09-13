module ShellOpts
  module Fragment
    class Node
      attr_reader :parent
      attr_reader :token
      def initialize(token)
        @token = token
      end
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
      def initialize(parent, token, lines = [])
        super(parent, token)
        @lines = lines
      end
    end

    class Line < Lines
      def line = lines.first
      def initialize(parent, token, line)
        super(parent, token, [lines])
      end
    end

    class Code < Element
    end

    class Paragraph < Element
      attr_reader :text
      def initialize(parent, token, text)
        super(parent, token)
        constrain text, String, [String], nil
        @text = Array(text).flatten.compact.join(" ")
      end
    end

    # An enumeration is a single-line text followed by an indented paragraph
    class Enumeration < Element
      attr_reader :enumerations # Array of (Line, Description) tuples
      def <<(line_and_description) @enumerations << line_and_description
    end

    # A List is an enumeration with the single-line text replaced by a bullet
    class List < Enumeration
      attr_reader :bullet # ".", "#", "o", "*", "-"
      def descriptions = enumerations.values

      def initialize(parent, token, bullet)
        super(parent, token)
        constrain bullet, ".", "#", "o", "*", "-"
        @bullet = bullet
      end

      def <<(description) = enumerations << [bullet, description]
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
      def <<(option)
        @nodes << option
        self
      end
    end

    class CommandGroup < Group
      alias_method :commands, :nodes
      def <<(command)
        @nodes << option
      end
    end
  end
end










