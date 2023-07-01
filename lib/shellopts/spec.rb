module ShellOpts
  # The Spec module models the document structure. It is created by the parser
  # and later split into a Grammar and a Doc object by the analyzer
  #
  # A document consists of nested definitions that are composed of a subject
  # and a definition of that subject.  Subjects are commands, options,
  # sections, and list items and can contain nested definitions.
  #
  # The top-level node is a Spec definition with a command group of exactly one
  # Program element as subject
  #
  module Spec
    class Node < Tree::Tree
      attr_reader :token

      def initialize(parent, token, check: true)
        constrain parent, Node, nil
        constrain token, Token
        super(parent)
        @token = token
      end

      # TODO Call this method from the parser
      def accept?(klass) = self.class.accepts.any? { |acceptable| klass <= acceptable }

    protected
      # List of classes those objects are accepted as children of this node. It
      # is used in #attach to check the type of the node
      def self.accepts = []
      def accepts = self.class.accepts

      def attach(child)
        accept?(child.class) or raise ArgumentError
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

    class Spec < Definition
      def name = token.value
      def program = subject.commands.first

      def initialize(token)
        constrain token.kind, :program
        super nil, token
      end
    end

    class CommandDefinition < Definition
      def commands = subject.commands
    end

    class OptionDefinition < Definition
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
      def self.accepts = [Arg]
    end

    class Arg < Node
    end

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

    class OptionGroup < Group
      def brief = description.find(Brief)
      def options = @options = filter(Command).to_a

      # Does not include Brief because it can't be attached directly to a
      # OptionGroup but belongs in the description
      def self.accepts = [OptionSubGroup] 
    end

    class OptionSubGroup < Node
      alias_method :option_group, :parent
      def brief = find(Brief) || option_group.brief
      def self.accepts = [Option, Brief]
    end

    # An option can be attached to a OptionSubGroup or a Command.
    # #option_subgroup and #option_group returns nil in the last case
    class Option < Node
      def name = token.value.sub(/^-+/, "")
      def option_subgroup = parent.is_a?(OptionSubGroup) ? parent : nil
      def option_group = option_subgroup&.option_group
      def brief = find(Brief) || option_subgroup&.brief

      # Associated Grammar::Command object. Initialized by the analyzer
      attr_accessor :command 

      # Associated Grammar::Option object. Initialize by the analyzer
      attr_accessor :option

      def initialize(parent, token, check: false)
        constrain parent, OptionSubGroup, Command
        super(parent, token, check: check)
      end

      def to_s = token.value
      def self.accepts = [Brief]
    end

    class CommandGroup < Group
      def brief = description.find(Brief)
      def arg_descr = description.find(ArgDescr)
      def commands = @commands = filter(Command).to_a

      # Does not include Option, ArgSpec, ArgDescr, or Brief because they
      # belongs in the description
      def self.accepts = [Command]
    end

    class Command < Node
      def name = @name ||= token.value.sub(/^(?:.*\.)?(.*)!$/, '\1')
      def ident = @ident ||= "#{name}!".to_sym
      def qual
        if q = token.value.match(/^(.*?)\.[^.]*$/)&.[](1)
          "#{q}!".to_sym
        else
          nil
        end
      end

      alias_method :command_group, :parent
      def brief = find(Brief) || command_group.brief
      def arg_descr = find(ArgDescr) || command_group.arg_descr

#     # Parent command. Note dotted commands are not resolved. Initialized by
#     # the analyzer
#     attr_accessor :supercommand
#
#     # List of (possibly dotted) subcommands. Initialized by the analyzer
#     attr_accessor :subcommands 

      # Associated Grammar::Command object. Initialized by the analyzer
      attr_accessor :command 

      def initialize(parent, token, check: false)
        constrain parent, CommandGroup
        super(parent, token, check: check)
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

