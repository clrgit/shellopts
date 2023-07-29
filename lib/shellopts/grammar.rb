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

      # Associated Ast node
      attr_reader :ast

      # Associated Doc::Node object. Initialized by #analyzer
      attr_accessor :doc 

      # The associated token. A shorthand for +ast.token+
      forward_to :ast, :token

      def initialize(parent, ident, ast, name: nil, literal: nil)
        constrain parent, Node, nil
        constrain !parent.nil? || self.is_a?(Grammar), true
        constrain ident, Symbol, Integer, nil
        constrain !ident.nil? || self.is_a?(Grammar), true
        constrain ast, Ast::Node
        @name = name || ident&.to_s
        @ident = ident
        @idents = [ident].compact
        @ast = ast
        @literal = literal || @name
        @literals = [@literal]
        super(parent)
        ast.grammar = self if ast
      end

      # Top-level grammar node
      def self.grammar = @@grammar

      # Limit error output
      def inspect = "#{token&.value} (#{self.class})"

      def dot(expr) # TODO: Tests
        constrain expr, Symbol, String
        expr
          .to_s.gsub(/\./, "!.")
          .split(/\./)
          .map { |expr| expr =~ /^(.*)\[(.*)\]$/ ? ["#$1!".to_sym, $2.to_i] : expr.to_sym }
          .flatten
          .inject(self) { |node, expr| node.dot_eval(expr) }
      end

    protected
      # Used by Tree
      def key = ident

      def dot_eval(expr) = dot_error expr
      def dot_error(expr) = raise ArgumentError, "Illegal expression in #{self.class}#dot: #{expr.inspect}"

    private
      # Top-level Grammar object. Initialized in Grammar#initialize
      @@grammar = nil
    end

    # A grammar object acts like a map of symbol/option pairs and
    # integer/argument pairs
    class Command < Node
      alias_method :group, :parent

      # True if command can be called on the command line. Qualified commands
      # where the parent commands are not defined individually are not callable
      # Default true
      attr_reader :callable # <- FIXME That's why the class hierarchy is wrong

      # List of options
      def options = children.select { |c| c.is_a? Option }

      # List of arguments
      def args = children.select { |c| c.is_a? Arg }

      def initialize(parent, ident, ast, name: nil, callable: true, **opts)
        constrain parent, Group, nil
        name ||= ident.to_s[0..-2]
        @callable = callable
        super(parent, ident, ast, name: name, **opts)
      end

    protected
      def dot_eval(expr)
        constrain expr, Symbol, Integer
        case expr
          when Symbol
            if group.subcommand?(expr) # subcommand or group-option
              group.subcommands.find { |cmd| cmd.ident == expr }
            elsif self.key?(expr) # command-option
              self[expr]
            elsif group.key?(expr) # group-option
              group[expr]
            else
              dot_error expr
            end
          when Integer
            if (0...args.size).include?(expr) # args
              args[expr]
            else
              dot_error expr
            end
        end
      end
    end

    class Program < Command
      IDENT = :!
      def initialize(parent, ast, name: nil, **opts)
        constrain parent, Grammar
        name ||= File.basename($PROGRAM_NAME)
        super(parent, IDENT, ast, name: name, **opts)
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

      def initialize(parent, ident, ast, **opts)
        constrain ident, Integer, nil
        constrain !ident.nil? || self.is_a?(Grammar)
        super #(parent, ident, ast, **opts)
      end

      # Subcommands. Sub-commands are the commands of the sub-groups
      def subcommand?(ident) = groups.any? { _1.key?(ident) }
      def subcommands = groups.map(&:commands).flatten
    end

    # The top-level grammar object is a group
    class Grammar < Group
      def program = commands.first
      def initialize(ast, **opts) = super(nil, nil, ast, **opts)

      def dot(expr) = expr == :! ? program : program.dot(expr)
    end

    class Arg < Node
      attr_reader :type

      def initialize(parent, ident, type, ast, **opts)
        constrain parent, Command, Option
        constrain ident, Symbol, Integer
        constrain type, Type::Type
        constrain ast, Ast::Node
        super(parent, ident, ast, **opts)
        @type = type
      end
    end

    class Option < Node
      # Has to come before alias_method below
      forward_to :ast, :name, :names, :short_names, :long_names, 
                       :ident, :idents, :short_idents, :long_idents,  # FIXME Node#ident and Ast#ident connflicts
                       :repeatable?, :optional?,
                       :brief, :description

      # Override Node#literal to include '-' or '--'
      def literal = literals.first
      alias_method :literals, :names

      def argument = children.first
      def argument? = !children.empty?

      def initialize(parent, ast, **opts) # FIXME Add an :ident option
        constrain parent, Command
        constrain ast, Ast::Option
        super(parent, ast.ident, ast, **opts)
      end
    end

    class BuiltinOption < Option; end
  end
end

