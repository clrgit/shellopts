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
    def self.program = Node.program

    class Node < Tree::Set # TODO Make Node a Tree::Tree node
      # Display-name of object (String). Defaults to #ident with special
      # characters removed
      attr_reader :name

      # Usually a Symbol but anonymous ArgSpec objects have Integer idents.
      # Initialized by the parser. Equal to :! for the top level Program
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

      # UID of object. This can be used in Node::[] to get the object.
      # nil if ident is nil
      #
      # FIXME: :[] should only be defined for objects where it makes sense
      def uid
        @uid ||= 
            case ident
              when nil; nil #parent&.uid
              when Symbol; [parent.uid, ident].compact.join(".").sub(/!\./, ".").to_sym
              when Integer; "#{parent.uid}[#{ident}]"
            else
              raise InternalError
            end
      end

      # Associated Spec node
      attr_reader :spec

      # Associated Doc::Node object. Initialized by the analyzer
      attr_accessor :doc 

      # The associated token. A shorthand for +spec.token+
      forward_to :spec, :token

      def initialize(parent, ident, name: nil, spec: nil)
#       constrain parent, *(self.class <= ProgramGroup ? [nil] : [Group, Option, Command, ArgSpec])
        constrain parent, Node, nil
        constrain ident, *(self.class <= ArgSpec || self.class <= Arg ? [Symbol, Integer] : [Symbol]), nil
        constrain spec, Spec::Node, nil
        @name = name || ident&.to_s
        @ident = ident
        @spec = spec
        super(parent)
        spec.grammar = self if spec
      end

      # Access node by relative UID. Eg. main.dot(option_name) or main.dot("[3].FILE")
      def dot(relative_uid) = Node[[self.uid, relative_uid].compact.join(".").sub("!.", ".")]

      # Top-level program node
      def self.program = @@nodes[nil]

      # Limit error output
      def inspect = "#{token&.value} (#{self.class})"

    private
      # Used by Tree
      def key = ident.nil? ? object_id : ident
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

    class Group < Node
      alias_method :group, :parent

      def commands = children.select { |c| c.is_a? Command }
      def groups = children.select { |c| c.is_a? Group }
      def options = children.select { |c| c.is_a? Option }
      def specs = children.select { |c| c.is_a? ArgSpec }

      def initialize(parent, **opts) 
        constrain parent, Group, nil
        super(parent, nil, **opts)
      end
    end

    class ProgramGroup < Group
      def initialize(**opts) = super(nil, **opts)
    end

    class Command < Node
      alias_method :group, :parent
      def options = group.options + children.select { |c| c.is_a? Option }
      def specs = group.specs + children.select { |c| c.is_a? ArgSpec }
      def commands = group.groups.map(&:commands).flatten

      def initialize(parent, ident, name: nil, **opts)
        constrain parent, Group, nil
        name ||= ident.to_s[0..-2]
        super(parent, ident, name: name, **opts)
      end

      def [](key) = self.key?(key) ? self[key] : group[key]
      def key?(key) = self.key?(key) || group.key?(key)
      def keys() = group.keys + self.keys
    end

    class Program < Command
      IDENT = :!
      def uid = nil # To not prefix UID with program name in every Grammar class

      def initialize(parent, name: nil, **opts)
        name ||= File.basename($PROGRAM_NAME)
        super(parent, IDENT, name: name, **opts)
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


