module ShellOpts
  # TODO
  #   Problems with ident/lookup/initialization: Option #parse determines the
  #   ident but that runs after Option#initialize so we can't link up with
  #   parent in #initialize :-(

  # Canonical name:
  #   Options 
  #     The name of the first long option if present and otherwise the name of
  #     the first short option
  #   Commands
  #     The first name in a list of aliases
  #
  module Grammar
    class Node
      attr_reader :parent
      attr_reader :children # Map from ident to child node
      forward_to :children, :key?, :[]

      # Parent command object or nil if this is the Program node
      alias_method :command, :parent

      # Usually a Symbol but anonymous ArgSpec objects have Integer idents.
      # Initialized by the parser. Equal to :! for the top level Program object
      attr_reader :ident

      # Display-name of object (String). Defaults to #ident with special
      # characters removed
      def name = ident.to_s

      # Literal of node as the user enters it. Eg. '--option' or 'command'
      attr_accessor :literal

      # Aliases. List of literals (TODO: may be changed to list of idents -
      # depends on the parser)
      attr_accessor :aliases

      # Program#uid overrides this
      def uid = @uid ||= [parent.uid, ident].join(".").sub(/!\./, ".")

      # Associated Doc::Node object. Initialized by the parser
      attr_accessor :doc 

      # The associated token. A shorthand for +doc.token+
      forward_to :doc, :token

      def initialize(parent, ident)
        constrain parent, *(self.class <= Program ? [nil] : [Command])
        constrain ident, *(self.class <= ArgSpec ? [Symbol, Integer] : [Symbol])
        @ident = ident
        @children = {}
        parent&.send(:attach, self)
        Node.register_node(self)
      end

      # Return true if node has a child node identified by the given ident
      def key?(ident) children.find { |c| c.ident == ident } && true end

      # Access child nodes by identifier
      def [](ident) children.find { |c| c.ident == ident } end

      # Access node by relative UID
      def dot(relative_uid) = Node[[self.uid, relative_uid].compact.join(".").sub("!.", ".")]

      # Access node by absolute UID
      def self.[](uid) = @@nodes[uid]
      def self.[]=(uid, node) @@nodes[uid] = node end

    private
      # Map from UID to Node object
      @@nodes = {}
      def self.register_node(node) = @@nodes[node.uid] = node
      def self.program = @@nodes.first

      def attach(child)
        !@children.key?(child.ident) or raise ParserError, "Duplicate child: #{child.name}"
        @children[child.ident] = child
        child.instance_variable_set(:@parent, self)
      end
    end

    class Option < Node
      attr_reader :arg

      attr_reader :short_literals
      attr_reader :long_literals
      def literals = short_literals + long_literals

      def initialize(parent, ident)
        super
        command.options << self
      end
    end

    class Command < Node
      attr_reader :options # List of Option objects
      attr_reader :commands # List of Command objects
      attr_accessor :arg_specs # List of ArgSpec objects. nil if unspecified

      def name = ident.to_s[0..-2]

      def initialize(parent, ident)
        super
        @options = []
        @commands = []
        @arg_specs = nil
      end
    end

    class Program < Command
      def ident = :!
      def uid = ident.to_s
      attr_reader :name

      def initialize(name: nil)
        super(nil, self.ident)
        @name = name || File.basename($PROGRAM_NAME)
      end
    end

    class ArgSpec < Node
      attr_reader :ident # An Symbol or Integer (the default)
      attr_reader :args

      def uid = @uid ||= "#{parent.uid}[#{ident}]"
      def literal = ident.to_s # or fail

      # Note that +ident+ can be nil, if so it defaults to the index into the
      # parent's #args array
      def initialize(parent, ident)
        super(parent, ident || parent.args.size)
        parent.args << self
      end
    end

    class Arg
    end
  end
end


