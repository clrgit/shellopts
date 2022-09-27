module ShellOpts

  # The Spec module models the document structure
  #
  # A document consists of nested definitions. A definition composed of a
  # subject and a definition of that subject that can contain other
  # definitions. Subjects are commands, options, sections, and list items
  #
  #
  # The top-level node is a Program definition with a ProgramSection as subject
  # and the rest of the documentatin as its description
  #
  module Spec
    class Node
      attr_reader :parent
      attr_reader :children # Array of child Node objects
      attr_reader :token

      def initialize(parent, token, check: true)
        constrain parent, Node, nil
        constrain token, Token
        @token = token
        @children = []
        parent&.send(:attach, self)
      end

      def accept?(klass) = self.class.accepts.include?(klass) 

#   protected
      # List of classes those objects are accepted as children of this node. It
      # is used in #attach to check the type of the node
      def self.accepts = []
      def accepts = self.class.accepts

      # If true, tokens that are not compatible with the current node are
      # passed on to the parent node (after the current node has been popped
      # off the stack)
      def self.pass = false
      def pass = self.class.pass

      # Attach a node to self and set node's parent. There is currently no
      # #detach method
      def attach(node, check: true)
        if check && !accepts.any? { |klass| node.is_a? klass } 
          raise Constrain::MatchError.new(
              nil, nil, message: "Can't attach a #{node.class.name} to a #{self.class.name}")
        end
        constrain accepts.any? { |klass| node.is_a? klass } if check
        @children << node
        node.instance_variable_set(:@parent, self)
      end

      # Shorthand when there is only one child
      def child
        constrain children.size, 1
        children.first
      end
    end

    # A special node that is used by the parser to set indentation level and
    # being a filler on the stack
    class Empty < Node
    end

    # A Brief object act as a paragraph
    class Brief < Node
      def text() @token.value end
    end

    # Lines are not wrapped
    class Lines < Node
      attr_reader :lines # Array of String objects
      def initialize(parent, token, lines = [])
        constrain lines, [String]
        super(parent, token)
        @lines = lines
      end
    end

    class Line < Lines
      def line = lines.first # A String object
      def initialize(parent, token, line = token.value)
        constrain line, String
        super(parent, token, [line])
      end

      def to_s = lines.first
    end

    class Code < Lines
      def initialize(parent, token)
        constrain token.kind, :code
        super(parent, token, token.lines)
      end
    end

    class Option < Node
      def initialize(parent, token, check: false)
        constrain parent, OptionGroup, Command
        super(parent, token, check: check)
      end
      def to_s = token.value
      def self.accepts = [Brief]
    end

    class Command < Node
      def initialize(parent, token, check: false)
        constrain parent, CommandGroup
        super(parent, token, check: check)
      end
      def to_s = token.value
      def self.accepts = [Option, ArgSpec, ArgDescr, Brief]
    end

    class ArgSpec < Node
      def self.accepts = [Arg]
    end

    class Arg < Node
    end

    class ArgDescr < Node
    end

    class Paragraph < Node
      attr_reader :text
      def initialize(parent, token, text)
        super(parent, token)
        constrain text, String, [String], nil
        @text = Array(text).flatten.compact.join(" ")
      end
    end

    class Description < Node
      alias_method :elements, :children
      def self.accepts = [Node] # Anything can go into a description. FIXME
    end

    # A List is an enumeration with the single-line text replaced by a bullet
    #
    # TODO: Change brief marker to '$' and use '@' as a bullet
    class List < Node
      attr_reader :bullet # ".", "#", "o", "*", "-"
      alias_method :bullets, :children
      def descriptions = bullets.map(&:description)

      def initialize(parent, token, bullet = token.value)
        super(parent, token)
        constrain bullet, ".", "#", "o", "*", "-"
        @bullet = bullet
      end

      def self.accepts = [ListItem]
    end

    class Definition < Node
      def subject = children[0] # Can be nil
      def description = children[1] # Can be nil TODO: Maybe default to EmptyDescription?

      # The header of the definition as an array of strings
      def header = subject.header

      def self.accepts = [Subject, Description]
    end

    class Program < Definition
      def initialize(token)
        constrain token.kind, :program
        super nil, token
        Spec::ProgramSection.new(self, token)
      end
    end

    class ListItem < Definition
      alias_method :list, :parent

      def header = [list.bullet]

      def self.accepts = [Bullet, Description]
    end

    # A subject is something that can be described. It always belongs to a
    # description that in turn always has a description
    class Subject < Node
      alias_method :definition, :parent
      forward_to :definition, :description

      # Returns the subject header as an array of strings
      def header = abstract_method

      def initialize(parent, token)
        constrain parent, Definition
        super
      end
    end

    class Bullet < Subject
      attr_reader :list_item, :parent
      def list = list_item.list

      def header = [list.bullet]
    end

    class Section < Subject
      attr_accessor :level # Assigned by the analyzer if nil
      attr_reader :header
      alias_method :name, :header

      def initialize(parent, token, level, header = token.value)
        super(parent, token)
        constrain level, Integer, nil
        constrain header, String
        @level = level
        @header = [header]
      end
    end

    class BuiltinSection < Section
      def initialize(parent, token, header = Lexer::SECTION_ALIASES[token.value])
        constrain header, *Lexer::SECTIONS
        super(parent, token, 1)
      end
    end

    class ProgramSection < Section
      def initialize(parent, token)
        super(parent, token, 0)
      end
    end

    class SubSection < Section
    end

    class Group < Subject
      def header = children.map(&:to_s)
    end

    class OptionGroup < Group
      def self.accepts = Option.accepts
    protected
      # Modify #attach to accept Option nodes too
      def attach(node) = super(node, check: !node.is_a?(Option))
    end

    class CommandGroup < Group
      def self.accepts = Command.accepts + [CommandGroup]
    protected
      # Modify #attach to accept Command nodes too
      def attach(node) = super(node, check: !node.is_a?(Command))
    end
  end
end

