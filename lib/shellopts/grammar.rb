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
    class Node < Tree::Set # TODO Make Node a Tree::Tree node
      # Parent command object or nil if this is the Program node
      alias_method :command, :parent

      # Associated Spec node
      attr_reader :spec

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
        @uid ||= 
            case ident
              when Symbol; [parent.uid, ident].compact.join(".").sub(/!\./, ".").to_sym
              when Integer; "#{parent.uid}[#{ident}]"
            else
              raise InternalError
            end
      end

      # Associated Doc::Node object. Initialized by the analyzer
      attr_accessor :doc 

      # The associated token. A shorthand for +doc.token+
      forward_to :doc, :token

      def initialize(parent, ident, spec: nil)
        constrain parent, *(self.class <= Program ? [nil] : [Option, Command, ArgSpec])
        constrain ident, *(self.class <= ArgSpec || self.class <= Arg ? [Symbol, Integer] : [Symbol])
        constrain spec, Spec::Node, nil
        @ident = ident
        @spec = spec
        super(parent)
        Node.register_node(self)
      end

      # Access node by relative UID. Eg. main.dot(option_name) or main.dot("[3].FILE")
      def dot(relative_uid) = Node[[self.uid, relative_uid].compact.join(".").sub("!.", ".")]

      # Access node in global pool by UID
      def self.[](uid) = @@nodes[uid]
      def self.[]=(uid, node) @@nodes[uid] = node end
      def self.key?(uid) = @@nodes.key?(uid) 
      def self.keys = @@nodes.keys
      def self.nodes = @@nodes.values
      def self.clear = @@nodes.clear # Used in RSpec tests

      # Limit error output
      def inspect = "#{token&.value} (#{self.class})"

    private
      # Map from UID to Node object
      @@nodes = {}
      def self.register_node(node) = @@nodes[node.uid] = node
      def self.program = @@nodes.first

      # Used by Tree
      def key = ident
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

      def initialize(parent, ident, short_idents, long_idents, **opts)
        constrain parent, Command
        constrain ident, Symbol, String
        super(parent, ident, **opts)
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
      def commands = children.select { |c| c.is_a? Command } # TODO: Rename to #subcommands
      def specs = children.select { |c| c.is_a? ArgSpec }

      def initialize(parent, ident, idents = [ident], **opts)
        constrain parent, (self.class == Program ? nil : Command)
        super(parent, ident, **opts)
        constrain idents, [Symbol]
        constrain idents.include?(ident) # Same semantics as Option
        @idents = idents
      end

      # FIXME Actually the same as self.key?(ident) and self[ident]
      # Check if ident is a name of a sub-command or of any sub-command alias # TODO: Rename to #subcommand
      def command?(ident) = commands.any? { |cmd| cmd.idents.include?(ident) } # TODO Optimize

      # Lookup ident in sub-commands. Aliases are supported
      def command(ident) = commands.find { |cmd| cmd.idents.include?(ident) }
    end

    class Program < Command
      def ident = :!
      attr_reader :name
      def uid = nil # To not prefix UID with program name in every Grammar class

      def initialize(name: nil, **opts)
        super(nil, self.ident, [self.ident], **opts)
        @name = name || File.basename($PROGRAM_NAME)
      end
    end

    class ArgSpec < Node
      alias_method :args, :children

      # Note that +ident+ can be nil, if so it defaults to the index into the
      # parent's #args array
      def initialize(parent, ident, **opts)
        super(parent, ident || parent.spec.size, **opts)
      end
    end

    class Arg < Node
      attr_reader :arg

      def intialize(parent, ident, arg, **opts)
        constrain parent, Command, Option
        super(parent, ident, **opts)
        @arg = arg
      end
    end
  end
end


