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
    def self.grammar = Node.grammar

    class Node < Tree::Set # TODO Make Node a Tree::Tree node
      # Display-name of object (String). Defaults to #ident with special
      # characters removed
      attr_reader :name

      # Usually a Symbol but anonymous ArgSpec objects have Integer idents.
      # Initialized by the parser. Equal to :! for the top level grammar
      # object. Can be nil for internal nodes, those nodes are registered by
      # object id
      attr_reader :ident

      # Alias idents. Must include #ident. Equal to the empty array if ident is
      # nil
      attr_reader :idents

      # Literal of the node's #ident as the user sees it (String). Eg.
      # '--option' or 'command'. Defaults to #name
      def literal = name

      # Alias literals. Must include #literal
      def literals = [literal]

      # Associated Spec node
      attr_reader :spec

      # Associated Doc::Node object. Initialized by the analyzer
      attr_accessor :doc 

      # The associated token. A shorthand for +spec.token+
      forward_to :spec, :token

      def initialize(parent, ident, name: nil, spec: nil)
        constrain parent, Node, nil
        constrain ident, Symbol, Integer, nil
        constrain spec, Spec::Node, nil
        @name = name || ident&.to_s
        @ident = ident
        @spec = spec
        super(parent)
        spec.grammar = self if spec
      end

      # Access node by relative UID. Eg. main.dot(option_name) or main.dot("[3].FILE")
      # def dot(relative_uid) = Node[[self.uid, relative_uid].compact.join(".").sub("!.", ".")]

      # Top-level grammar node
      def self.grammar = @@grammar

      # Limit error output
      def inspect = "#{token&.value} (#{self.class})"

    protected
      # Used by Tree
      def key = ident.nil? ? object_id : ident

    private
      # Top-level Grammar object. Initialized in Grammar#initialize
      @@grammar = nil
    end

    class Command < Node
      alias_method :group, :parent

      def command_options = children.select { |c| c.is_a? Option }
      def command_args = children.select { |c| c.is_a? ArgSpec }

      def options = group.options + command_options
      def args = group.args + command_args
      def subcommands = group.subcommands
      def groups = group.groups

      def initialize(parent, ident, name: nil, **opts)
        constrain parent, Group, nil
        name ||= ident.to_s[0..-2]
        super(parent, ident, name: name, **opts)
      end

      def key?(key) = values.find { _1.ident == key }
      def keys = values.map(&:ident)
      def [](key) = values.find { _1.ident == key }
      def values = group.values + options
    end

    class Program < Command
      IDENT = :!

      def initialize(parent, name: nil, **opts)
        name ||= File.basename($PROGRAM_NAME)
        super(parent, IDENT, name: name, **opts)
      end
    end

    # Commands are organized in groups that share options, arguments and
    # documentation and that may have a parent group of commands
    class Group < Command
      def name = commands.first.name
      def ident = commands.first&.ident

      def commands = children.select { |c| c.is_a?(Command) && !c.is_a?(Group) }
      def subcommands = groups.map(&:commands).flatten
      def options = children.select { |c| c.is_a? Option }
      def args = children.select { |c| c.is_a? ArgSpec }
      def groups = children.select { |c| c.is_a? Group }

      def initialize(parent, **opts)
        constrain parent, Group, nil
        super(parent, nil, **opts)
      end

      def values = options + subcommands
    end

    # The top-level grammar object is a group
    class Grammar < Group
      def program = commands.first
      def initialize(**opts) = super(nil, **opts)

      def values = super + [program] # Special case for :!
    end

    class ArgSpec < Node
      alias_method :args, :children

      # Option kind, :group or :command
      def kind = abstract_method

      # Note that +ident+ can be nil, if so it defaults to the index into the
      # parent's #args array
      def initialize(parent, ident, **opts)
        super(parent, ident || parent.spec.size, **opts)
      end
    end

    class GroupArgSpec < ArgSpec
      alias_method :group, :parent
      def kind = :group
    end

    class CommandArgSpec < ArgSpec
      alias_method :command, :parent
      def kind = :command
    end

    class Arg < Node
      attr_reader :arg

      def intialize(parent, ident, arg, **opts)
        constrain parent, Command, Option
        super(parent, ident, **opts)
        @arg = arg
      end
    end

    class Option < Node
      # Option kind, :group or :command
      def kind = abstract_method

      # Has to come before alias_method below
      forward_to :spec, :name, :names, :short_names, :long_names, 
                        :ident, :idents, :short_idents, :long_idents, 
                        :repeatable?, :optional?, :argument_name, :argument_type

      # Override Node#literal to include '-' or '--'
      alias_method :literal, :name
      alias_method :literals, :names

      def arg
        @children.size <= 1 or raise InternalError, "More than one child"
        @chidren.first
      end

      def initialize(parent, spec: nil, **opts)
        constrain parent, Command
        constrain spec, Spec::Option
        super(parent, spec.ident, spec: spec, **opts)
      end
    end

    class GroupOption < Option
      alias_method :group, :parent
      def kind = :group
    end

    class CommandOption < Option
      alias_method :command, :parent
      def kind = :command
    end
  end
end


