module ShellOpts
  # Canonical name:
  #   Options 
  #     The name of the first long option if present and otherwise the name of
  #     the first short option
  #   Commands
  #     The first name in a list of aliases (aliases are not implemented so it
  #     is just its name). Command groups are unnamed
  #   Groups
  #     The index of the group within its parent group
  #   Arguments
  #     Either the Option's name or the index of the argument within its parent
  #     command
  #
  module Grammar
    def self.grammar = Node.grammar

    class Node < Tree::Set
      # Display-name of object (String). Defaults to #ident with special
      # characters removed. Group names are the subcommands' names concatenated
      # with '+'
      attr_reader :name

      # Unique identifier of the node within its context. Usually a Symbol but
      # command arguments and groups have Integer idents
      #
      # Nil for the top-level grammar object and :! for the top level program
      # object
      attr_reader :ident

      # Alias idents. Must include #ident. Equal to the empty array for the
      # top-level Grammar object that has ident equal to nil
      attr_reader :idents

      # Literal of the node's #ident as the user sees it (String). Eg.
      # '--option' or 'command'. Defaults to #name. TODO: Move to Doc?
      attr_reader :literal

      # Alias literals. Must include #literal
      attr_reader :literals

      # Associated Spec node
      attr_reader :spec

      # Associated Doc::Node object. Initialized by #analyzer
      attr_accessor :doc 

      # The associated token. A shorthand for +spec.token+
      forward_to :spec, :token

      def initialize(parent, ident, spec, name: nil, literal: nil)
        constrain parent, Node, nil
        constrain !parent.nil? || self.is_a?(Grammar), true
        constrain ident, Symbol, Integer, nil
        constrain !ident.nil? || self.is_a?(Grammar), true
        constrain spec, Spec::Node
        @name = name || ident&.to_s
        @ident = ident
        @idents = [ident].compact
        @spec = spec
        @literal = literal || @name
        @literals = [@literal]
        super(parent)
        spec.grammar = self if spec
      end

      # Top-level grammar node
      def self.grammar = @@grammar

      # Limit error output
      def inspect = "#{token&.value} (#{self.class})"

    protected
      # Used by Tree
      def key = ident

    private
      # Top-level Grammar object. Initialized in Grammar#initialize
      @@grammar = nil
    end

    class Command < Node
      alias_method :group, :parent

      # True if command can be called on the command line. Qualified commands
      # where the parent commands are not defined individually are not callable
      # Default true
      attr_reader :callable

      # List of options
      def options = children.select { |c| c.is_a? Option }

      # List of arguments
      def args = children.select { |c| c.is_a? Arg }

      def initialize(parent, ident, spec, name: nil, callable: true, **opts)
        constrain parent, Group, nil
        name ||= ident.to_s[0..-2]
        @callable = callable
        super(parent, ident, spec, name: name, **opts)
      end
    end

    class Program < Command
      IDENT = :!
      def initialize(parent, spec, name: nil, **opts)
        constrain parent, Grammar
        name ||= File.basename($PROGRAM_NAME)
        super(parent, IDENT, spec, name: name, **opts)
      end
    end

    # Commands are organized in groups that share options, arguments and
    # documentation and that may have a parent group of commands
    class Group < Command
      def name = commands.map(&:name).join("+")

      # Commands in this group
      def commands = children.select { |c| c.is_a?(Command) && !c.is_a?(Group) }

      # Subgroups
      def groups = children.select { |c| c.is_a? Group }

      def initialize(parent, ident, spec, **opts)
        constrain ident, Integer, nil
        constrain !ident.nil? || self.is_a?(Grammar)
        super #(parent, ident, spec, **opts)
      end

      # Subcommands. Sub-commands are the commands of the sub-groups
      def subcommand?(ident) = groups.any? { _1.key?(ident) }
      def subcommands = groups.map(&:commands).flatten
    end

    # The top-level grammar object is a group
    class Grammar < Group
      def program = commands.first
      def initialize(spec, **opts) = super(nil, nil, spec, **opts)
    end

    class Arg < Node
      attr_reader :type

      def initialize(parent, ident, type, spec, **opts)
        constrain parent, Command, Option
        constrain ident, Symbol, Integer
        constrain type, Type::Type
        constrain spec, Spec::Node
        super(parent, ident, spec, **opts)
        @type = type
      end
    end

    class Option < Node
      # Has to come before alias_method below
      forward_to :spec, :name, :names, :short_names, :long_names, 
                        :ident, :idents, :short_idents, :long_idents, 
                        :repeatable?, :optional?

      # Override Node#literal to include '-' or '--'
      alias_method :literal, :name
      alias_method :literals, :names

      def argument = children.first
      def argument? = !children.empty?

      def initialize(parent, spec, **opts)
        constrain parent, Command
        constrain spec, Spec::Option
        super(parent, spec.ident, spec, **opts)
      end
    end
  end
end

