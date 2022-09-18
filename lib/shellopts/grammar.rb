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

      # Display-name of object (String). Defaults to #ident with special
      # characters removed
      def name = ident.to_s

      # Usually a Symbol but anonymous ArgSpec objects have Integer idents.
      # Initialized by the parser. Equal to :! for the top level Program object
      attr_reader :ident

      # Alias idents. Must include #ident
      attr_reader :idents

      # Literal of the node's #ident as the user sees it (String). Eg.
      # '--option' or 'command'. Defaults to #name
      def literal = name

      # Alias literals. Must include #literal
      def literals = abstract_method

      # UID of object. This can be used in Node::[] to get the object
      def uid
        case ident
          when Symbol; [parent.uid, ident].join(".").sub(/!\./, ".")
          when Integer; "#{parent.uid}[#{ident}]"
        else
          raise InternalError
        end
      end

      # Associated Doc::Node object. Initialized by the parser
      attr_accessor :doc 

      # The associated token. A shorthand for +doc.token+
      forward_to :doc, :token

      def initialize(parent, ident)
        constrain parent, *(self.class <= Program ? [nil] : [Option, Command, ArgSpec])
        constrain ident, *(self.class <= ArgSpec || self.class <= Arg ? [Symbol, Integer] : [Symbol])
        @ident = ident
        @children = {}
        parent&.send(:attach, self)
        Node.register_node(self)
      end

      # Return true if node has a child node identified by the given ident
      def key?(ident) children.find { |c| c.ident == ident } && true end

      # Access child nodes by identifier
      def [](ident) children.find { |c| c.ident == ident } end

      # Access node by relative UID. Eg. main.dot(option_name) or main.dot("[3].FILE")
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
      # Override Node#literal to include '-' or '--'
      def literal = @literal ||= short_idents.include?(ident) ? "-#{ident}" : "--#{ident}"

      attr_reader :short_idents
      attr_reader :long_idents
      def idents = @idents ||= @short_idents + @long_idents

      def short_literals = @short_literals ||= @short_idents.map { |i| "-#{i}" }
      def long_literals = @long_literals ||= @long_idents.map { |i| "--#{i}" }
      def literals = @literals ||= short_literals + long_literals

      def arg
        @children.size <= 1 or raise InternalError, "More than one child"
        @chidren.first
      end

      def initialize(parent, ident, short_idents, long_idents)
        p parent
        constrain parent, Command
        super(parent, ident)
        constrain short_idents, [Symbol]
        constrain long_idents, [Symbol]
        constrain short_idents.include?(ident) || long_idents.include?(ident)
        @short_idents, @long_idents = short_idents, long_idents
      end
    end

    class Command < Node
      def name = ident.to_s[0..-2]

      attr_reader :idents
      def literals = @literals ||= idents.map { |i| i.to_s[0..-2] }

      def options = children.select { |c| c.is_a? Option }
      def commands = children.select { |c| c.is_a? Command }
      def specs = children.select { |c| c.is_a? ArgSpec }

      def initialize(parent, ident, idents)
        constrain parent, (self.class == Program ? nil : Command)
        super(parent, ident)
        constrain idents, [Symbol]
        constrain idents.include?(ident) # Same semantics as Option
        @idents = idents
      end
    end

    class Program < Command
      def ident = :!
      attr_reader :name
      def uid = nil # To not prefix UID with program name in every Grammar class

      def initialize(name: nil)
        super(nil, self.ident, [self.ident])
        @name = name || File.basename($PROGRAM_NAME)
      end
    end

    class ArgSpec < Node
      alias_method :args, :children

      # Note that +ident+ can be nil, if so it defaults to the index into the
      # parent's #args array
      def initialize(parent, ident)
        super(parent, ident || parent.spec.size)
      end
    end

    class Arg < Node
      attr_reader :arg

      def intialize(parent, ident, arg)
        constrain parent, Command, Option
        super(parent, ident)
        @arg = arg
      end
    end
  end
end


