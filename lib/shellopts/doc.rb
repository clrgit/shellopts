module ShellOpts
  module Doc
    class DocNode
      attr_reader :parent
    end

    class Brief < DocNode
    end

    class Description < DocNode
      attr_reader :elements
    end

    class Element < DocNode
    end

    class Lines < Element
      attr_reader :lines
      def initialize()
        @lines = []
      end
    end

    class Code < Element
    end

    class Paragraph < Element
    end

    class List < Element
      attr_reader :bullet # ".", "%", "o", "*", "-"
      attr_reader :descriptions

      def initialize(bullet)
        constrain bullet, ".", "%", "o", "*", "-"
        @bullet = bullet
        @descriptions = []
      end
    end

    class Definition < Element
      def header = abstract_method
      attr_accessor :description
    end

    class Section < Definition
      attr_reader :header
      def initialize(header)
        constrain header, String
        @header = header
      end
    end

    class ProgramSection < Section
      attr_reader :program
      def initialize(name, program)
        super(name)
        constrain program, Idr::Program
        @program = program
      end
    end

    class NameSection < ProgramSection
      def initialize(program) = super("NAME", program) 
    end

    class SynopsisSection < ProgramSection
      def initialize(program) = super("SYNOPSIS", program) 
    end

    class DescriptionSection < ProgramSection
      def initialize(program) = super("DESCRIPTION", program) 
    end

    class OptionsSection < ProgramSection
      def initialize(program) = super("OPTIONS", program) 
    end

    class CommandsSection < ProgramSection
      def initialize(program) = super("COMMANDS", program) 
    end
  end
end










