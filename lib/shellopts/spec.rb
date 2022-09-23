module ShellOpts
  module Spec
    class Node
      attr_reader :parent
      attr_reader :children # Array of child Node objects
      attr_reader :token

      def initialize(parent, token, check: true, mode: nil)
        constrain parent, Node, nil
        constrain token, Token
        constrain mode, :single, :multi, nil
        @token = token
        @children = []
        @mode = mode || parent&.mode || :multi
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

      # Mode of processing: :multi - elements are nested using indentation,
      # :single - elements are all on the same line. The mode can be specified
      # explicity but is otherwise inherited from the parent node. Default is
      # :multi
      attr_reader :mode

      def self.whole? = false
      def group? = self.class.whole?

      def self.part? = false
      def part? = self.class.part?

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
#       constrain accepts.any? { |klass| node.is_a? klass } if check
        @children << node
        node.instance_variable_set(:@parent, self)
      end

      # Shorthand when there is only one child
      def child
        constrain children.size, 1
        children.first
      end

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
      def initialize(parent, token, line = nil)
        constrain line, String, nil
        super(parent, token, [line || token.source])
      end

      def rs = line
    end

    class Code < Lines
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

    # An enumeration is a single-line text followed by an indented paragraph
    class Enumeration < Node
      alias_method :definitions, :children
      def descriptions = definitions.map(&:description)

      def self.accepts = [Definition]
    end

    # A List is an enumeration with the single-line text replaced by a bullet
    class List < Enumeration
      attr_reader :bullet # ".", "#", "o", "*", "-"

      def initialize(parent, token, bullet)
        super(parent, token)
        constrain bullet, ".", "#", "o", "*", "-"
        @bullet = bullet
      end

      def self.accepts = [Bullet]
    end

    class Definition < Node
      def header(formatter) = abstract_method
      def description = children.first

      def self.accepts = [Description]
    end

    class Bullet < Definition
      attr_reader :list
      def header(formatter) list.bullet end
    end

    class Section < Definition
      def header(formatter = nil)
        constrain formatter, Formatter::Formatter, nil
        [@header]
      end

      def initialize(parent, token, header)
        super(parent, token)
        constrain header, String
        @header = header
      end
    end

    class Description < Node
      alias_method :elements, :children
      def self.accepts = [Node] # Anything can go into a description. FIXME
      def rs = nil
    end

    class Program < Description
      def initialize(token) 
        constrain token.kind, :program
        super nil, token
      end
      def rs = Node.instance_method(:rs).bind(self).call # override Description's override
    end

    # Options are processed line-by-line and collected into option groups.
    # Common definitions for the option group (briefs and description) are
    # attached to the group and not the individual options
    class Option < Node
      def initialize(parent, token, check: false)
        super(parent, token, check: check, mode: :single)
      end
      def self.accepts = [Brief]
      def self.pass = true
      def self.part? = true
    end

    class Command < Node
      def initialize(parent, token, check: false)
        super(parent, token, check: check, mode: :single)
      end
      def self.accepts = [Brief, ArgSpec, ArgDescr, OptionGroup]
      def self.pass = true
      def self.part? = true
    end

    class Group < Definition
      def header(formatter) = formatter.header(self)
      def <<(element) attach(element) end

      def self.whole? = true

      def rs = "group"
    end

    class OptionGroup < Group
      def self.accepts = [Brief, Description]
    protected
      # Modify #attach to accept Option nodes too
      def attach(node) = super(node, check: !node.is_a?(Option))
    end

    class CommandGroup < Group
      def self.accepts = [Brief, Description, CommandGroup, OptionGroup]
    protected
      # Modify #attach to accept Command nodes too
      def attach(node) = super(node, check: !node.is_a?(Command))
    end

    class ArgSpec < Node
    end

    class Arg < Node
    end

    class ArgDescr < Node
    end

  end
end










