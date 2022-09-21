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

    protected
      # List of classes that this class accepts as children. It is used in
      # #attach to check the type of the node
      def self.accepts = []
      def accepts = self.class.accepts

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
    end

    class Line < Lines
      def line = lines.first # A String object
      def initialize(parent, token, line = nil)
        constrain line, String, nil
        super(parent, token, [line || token.source])
      end
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
    end

    class Program < Description
      def initialize(token) 
        constrain token.kind, :program
        super nil, token
      end
    end

    class Option < Node
      def initialize(parent, token, check: false)
        super(parent, token, check: check)
      end
      def self.accepts = [Brief]
    end

    class Command < Node
      def initialize(parent, token, check: false)
        super(parent, token, check: check)
      end
      def self.accepts = [Brief, ArgSpec, ArgDescr] # FIXME: Not used when :check is false
    end

    class Group < Definition
      def header(formatter) = formatter.header(self)
      def <<(element) attach(element) end
    end

    class OptionGroup < Group
      def self.accepts = [Brief, Description]
    protected
      def attach(node)
        raise if node.nil?
        super(node, check: !node.is_a?(Spec::Option))
      end
    end

    class CommandGroup < Group
      def self.accepts = [Brief, Description, CommandGroup, OptionGroup]
    protected
      def attach(node)
        super(node, check: !node.is_a?(Command))
      end
    end

    class ArgSpec < Node
    end

    class Arg < Node
    end

    class ArgDescr < Node
    end

  end
end










