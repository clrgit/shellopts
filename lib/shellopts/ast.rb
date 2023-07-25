module ShellOpts
  # The Ast module models the document structure. It is created by the parser
  # and later split into a Grammar and a Doc object by the analyzer
  #
  # A document consists of nested definitions that are composed of a subject
  # and a definition of that subject.  Subjects are commands, options,
  # sections, and list items and can contain nested definitions.
  #
  # The top-level node is a Ast definition with a command group of exactly one
  # Program element as subject
  #
  module Ast
    class Node < Tree::Tree
      attr_reader :token

      # Associated grammar object or nil. Initialized by the analyzer, may be
      # nil
      attr_accessor :grammar

      def initialize(parent, token)
        constrain parent, Node, nil
        constrain token, Token
        super(parent)
        @token = token
      end

      # TODO Call this method from the parser
      def accept?(klass) = self.class.accepts.any? { |acceptable| klass <= acceptable }

      def inspect = "'#{token.value}' (#{self.class})"

    protected
      # List of classes those objects are accepted as children of this node. It
      # is used in #attach to check the type of the node
      def self.accepts = []
      def accepts = self.class.accepts

      def attach(child)
        accept?(child.class) or raise ArgumentError, child.class
        super
      end
    end

    class Definition < Node
      def subject = children[0] # Can be nil
      def description = children[1] # Can be nil TODO: Maybe default to EmptyDescription?

      # The header of the definition as an array of strings
      def header = subject.header

      def self.accepts = [Subject, Description]
    end

    class CommandDefinition < Definition
      alias_method :command_group, :subject
      def commands = subject.commands
    end

    class Spec < CommandDefinition
      def name = token.value
      def program = subject.commands.first
      def commands = [program]

      def initialize(token)
        constrain token.kind, :program
        super nil, token
      end
    end

    class OptionDefinition < Definition
      alias_method :option_group, :subject
      def options = option_group.filter(Option)
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

    class Description < Node
      alias_method :definition, :parent
      alias_method :elements, :children

      # Only not-nil for option and command definitions
      def grammar = definition.grammar

      def self.accepts = [Node] # Anything can go into a description. FIXME
    end

    class EmptyDescription < Description
      def initialize(parent) super(parent, parent.token) end
    end

    # A special node that is used by the parser to set indentation level and
    # being a filler on the stack
    class Empty < Node
    end

    # A Brief object act as a paragraph
    class Brief < Node
      def text() = @token.value
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
      def initialize(parent, token, line = token.value)
        constrain line, String
        super(parent, token, [line])
      end

      def to_s = lines.first
    end

    class Code < Lines
      def initialize(parent, token)
        constrain token.kind, :code
        super(parent, token, token.lines)
      end
    end

    class ArgSpec < Node
      alias_method :command, :parent
      alias_method :args, :children
#     def initialize(parent, token, **opts)
#       constrain parent, Command
#       super
#     end
      def self.accepts = [Arg]
    end

    class Arg < Node
      attr_reader :name
      attr_reader :type

      def initialize(parent, token, name, type)
        super(parent, token)
        @name, @type = name, type
      end
    end

    # An ArgDescr is a free-text description of the arguments. It is not parsed
    # as an expression but is used in the documentation
    class ArgDescr < Node
    end

    class Paragraph < Node
      attr_reader :text
      def initialize(parent, token, text)
        super(parent, token)
        constrain text, String, [String], nil
        @text = Array(text).flatten.compact.join(" ")
      end
    end

    # A List is an enumeration with the single-line text replaced by a bullet
    #
    # TODO: Change brief marker to '$' and use '@' as a bullet
    class List < Node
      attr_reader :bullet # ".", "#", "o", "*", "-"
      alias_method :bullets, :children
      def descriptions = bullets.map(&:description)

      def initialize(parent, token, bullet = token.value)
        super(parent, token)
        constrain bullet, ".", "#", "o", "*", "-"
        @bullet = bullet
      end

      def self.accepts = [ListItem]
    end

    # The Bullet class is only necessary because ListItem is a Definition and
    # hence needs a subject
    class Bullet < Subject
      attr_reader :list_item, :parent
      def list = list_item.list

      def header = [list.bullet]
    end

    class ListItem < Definition
      alias_method :list, :parent

      def header = [list.bullet]

      def self.accepts = [Bullet, Description]
    end

    class Section < Subject
      attr_accessor :level # Assigned by the analyzer if nil
      attr_reader :header
      def name = header.first

      def initialize(parent, token, level, header = token.value)
        super(parent, token)
        constrain level, Integer, nil
        constrain header, String
        @level = level
        @header = [header]
      end
    end

    class BuiltinSection < Section
      def initialize(parent, token, header = Lexer::SECTION_ALIASES[token.value])
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
    end

    # An option group is a list of continuous subgroups without blank lines in
    # between, like a text paragraph. Options in a group share a common description
    class OptionGroup < Group
      def brief = description.find(Brief)
      def options = @options ||= filter(Option).to_a

      # Does not include Brief because it can't be attached directly to a
      # OptionGroup but belongs in the description
      def self.accepts = [OptionSubGroup] 
    end

    # An option subgroup is a list of options on the same line. Options in a
    # subgroup share a common brief
    class OptionSubGroup < Node
      alias_method :option_group, :parent
      def brief = find(Brief) || option_group.brief
      def self.accepts = [Option, Brief]
    end

    # An option and it's aliases. It is attached to an OptionSubGroup when it is
    # part of a description, or a Command when it is defined directly on the
    # command.  #option_subgroup, #option_group, and #brief returns nil in the
    # last case
    class Option < Node
      def name = token.value.sub(/^-+/, "")
      def option_subgroup = parent.is_a?(OptionSubGroup) ? parent : nil
      def option_group = option_subgroup&.option_group
      def brief = find(Brief) || option_subgroup&.brief

      attr_reader :name
      attr_reader :names
      attr_reader :short_names
      attr_reader :long_names

      attr_reader :ident
      attr_reader :idents
      attr_reader :short_idents
      attr_reader :long_idents

      def repeatable? = @repeatable
      def optional? = @optional

      def argument? = !argument.nil?
      def argument = @children.first

#     attr_reader :argument
#     attr_reader :argument_name
#     attr_reader :argument_type
    
      # Associated Grammar::Option object. Initialize by the analyzer
      alias_method :option, :grammar
    
      def initialize(parent, token, idents, repeatable, optional)
        constrain parent, OptionSubGroup, Command
        constrain idents, [Symbol]
        constrain repeatable, true, false
        constrain optional, true, false
#       constrain argument, Arg, nil
#       constrain argument_name, String, nil
#       constrain argument_type, Type::Type, nil
        super(parent, token)

        @idents = idents
        @repeatable = repeatable
        @optional = optional
#       @argument = argument
#       @argument_name = argument_name
#       @argument_type = argument_type

        @names = []
        @short_names = []
        @long_names = []
        @short_idents = []
        @long_idents = []
        @idents.each { |ident|
          name = ident.to_s
          if name.size == 1
            @names << "-#{name}"
            @short_names << "-#{name}"
            @short_idents << ident
          else
            @names << "--#{name}"
            @long_names << "--#{name}"
            @long_idents << ident
          end
        }

        @ident = @long_idents.first || @short_idents.first
        @name = @long_names.first || @short_names.first
      end
    
      def to_s = token.value
      def self.accepts = [Brief]

      def self.accepts = [Arg]
    end

    # A command group is a list of continuous commands without blank lines in
    # between, like a text paragraph
    class CommandGroup < Group
      def brief = description.find(Brief)
      def arg_descr = description.find(ArgDescr)
      def commands = @commands = filter(Command).to_a

      # Does not include Option, ArgSpec, ArgDescr, or Brief because they
      # belongs in the description
      def self.accepts = [Command]
    end

    # A Command
    class Command < Node
      def name = @name ||= token.value.sub(/^(?:.*\.)?(.*)!$/, '\1')
      def ident = @ident ||= "#{name}!".to_sym
      def path = token.value[0..-2].split(".").map { :"#{_1}!" }
      def qualification = path[0..-1]

      def qualified? = qualification.size > 1

      alias_method :command_group, :parent
      def brief = find(Brief) || command_group.brief
      def arg_descr = find(ArgDescr) || command_group.arg_descr

      # Associated Grammar::Command object. Initialized by the analyzer
      attr_accessor :command 

      def initialize(parent, token)
        constrain parent, CommandGroup
        super(parent, token)
        @supercommand = nil
        @subcommands = []
        @command = nil
      end

      def attach_command(command)
        command.supercommand = self
        subcommands << command
      end

      def to_s = token.value
      def self.accepts = [Option, ArgSpec, ArgDescr, Brief]
    end

    class Program < Command
    end
  end
end

