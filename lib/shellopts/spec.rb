module ShellOpts
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

      def dump
        puts dump_header
        indent { children.each(&:dump) }
      end

      def rs = token.value
      def dn(device = $stdout) # dn - dump node
        if rs
          device.puts rs
          device.indent { |dev| children.each { |node| node.dn(dev) } }
        else
          children.each { |node| node.dn(device) }
        end
      end

#   protected
      # List of classes that this class accepts as children. It is used in
      # #attach to check the type of the node
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
          raise Constrain::MatchError.new(nil, nil, message: "Can't attach a #{node.class} to #{self.class}")
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

      def rs = "#{token.value}"

      def dump_header
        "#{self.class.to_s.sub(/.*::/, "")}: #{token.location}, children: #{children.size}"
      end
    end

    # A Brief object act as a paragraph
    class Brief < Node
      def text() @token.value end

      def rs = "@#{text}"

      def dump
        super
        indent { puts text.inspect }
      end
    end

    # Lines are not wrapped
    class Lines < Node
      attr_reader :lines # Array of String objects
      def initialize(parent, token, lines = [])
        constrain lines, [String]
        super(parent, token)
        @lines = lines
      end

      def rs = @lines.inspect
    end

    class Line < Lines
      def line = lines.first # A String object
      def initialize(parent, token, line = token.value)
        constrain line, String
        super(parent, token, [line])
      end

      def to_s = lines.first

      def rs = line
    end

    class Code < Lines
      def initialize(parent, token)
        constrain token.kind, :code
        super(parent, token, token.lines)
      end
      def rs = nil
      def dn(device = $stdout)
        device.puts "()"
        device.indent { |dev|
          dev.puts lines
        }
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
      def rs = "-- " + super
    end

    class Paragraph < Node
      attr_reader :text
      def initialize(parent, token, text)
        super(parent, token)
        constrain text, String, [String], nil
        @text = Array(text).flatten.compact.join(" ")
      end

      def dump
        super
        indent { puts text.inspect }
      end

      def rs = text
    end

    class Description < Node
      alias_method :elements, :children
      def self.accepts = [Node] # Anything can go into a description. FIXME
      def rs = nil
    end

    # A List is an enumeration with the single-line text replaced by a bullet
    #
    # TODO: Change brief marker to '$' and use '@' as a bullet
    class List < Node
      attr_reader :bullet # ".", "#", "o", "*", "-"

      def initialize(parent, token, bullet = token.value)
        super(parent, token)
        constrain bullet, ".", "#", "o", "*", "-"
        @bullet = bullet
      end

      def self.accepts = [Description]
    end

    class Definition < Node
      def subject = children[0]
      def description = children[1] # Can be nil TODO: Maybe default to EmptyDescription?

      # The header of the definition as an array of strings
      def header = subject.header

      def self.accepts = [Subject, Description]

      def dn(device = $stdout) # dn - dump node
        subject.dn(device)
        device.indent { |dev| description&.dn(dev) }
      end
    end

    class Program < Definition
      def initialize(token)
        constrain token.kind, :program
        super nil, token
        Spec::ProgramSection.new(self, token)
      end
      def rs = Node.instance_method(:rs).bind(self).call # override Description's override
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

    class Section < Subject
      # TODO: Swap order with header
      attr_accessor :level # Assigned by the analyzer if nil
      attr_reader :header

      def initialize(parent, token, level, header = token.value)
        super(parent, token)
        constrain level, Integer, nil
        constrain header, String
        @level = level
        @header = [header]
      end

#     def rs = "<#{super}: #{self.class.name}>"
    end

    class BuiltinSection < Section
      def initialize(parent, token, header = token.value)
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

      def rs = "group"
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

