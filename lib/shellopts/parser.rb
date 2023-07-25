
module ShellOpts
  def program_name
    @program_name ||= File.basename($PROGRAM_NAME)
  end
end

module ShellOpts
  # The implementation of the parser sits in a spot between a recursive descent
  # parser and a state transition based parser with a stack. Maybe rewrite as a
  # full recursive descent parser because the stack handling gets hairy here
  # and there
  class Parser
    using Ext::Array::ShiftWhile
    using Ext::Array::PopWhile

    # The resulting Ast::Program object
    attr_reader :program

    def initialize(tokens, singleline: false)
      constrain tokens, [Token]
      @tokens = TokenQueue.new tokens
      @singleline = singleline
    end

    # Parse tokens and return Ast::Spec object
    def parse
      if @singleline
        parse_singleline
      else
        parse_multiline
      end
      @ast
    end

    def self.parse(tokens) = self.new(tokens).parse

  protected
    SHORT_OPTION_NAME_RE = /[a-zA-Z0-9?]/
    LONG_OPTION_NAME_RE = /[a-zA-Z0-9][a-zA-Z0-9_-]*/
    OPTION_NAME_RE=/(?:#{SHORT_OPTION_NAME_RE}|#{LONG_OPTION_NAME_RE})/
    OPTION_NAME_LIST_RE = /#{OPTION_NAME_RE}(?:,#{OPTION_NAME_RE})*/

    RESERVED_NAME_RE = /^__.*__$/

    # Queue of tokens (TokenQueue object)
    attr_reader :tokens

    # Current token, first token of queue
    def token = tokens.head

    def parser_error(token, message) = raise ParserError, token, message

    # Saves some typing. Maps from token kind to Parser method
    PARSER_MAP = {
      section: :parse_section,
      subsection: :parse_subsection,
      blank: :parse_blanks,
      text: :parse_text,
      code: :parse_code,
      option: :parse_option_definition,
      command: :parse_command_definition,
      brief: :parse_brief,
      arg_spec: :parse_arg_spec,
      arg_descr: :parse_arg_descr,
      bullet: :parse_list
    }

    def parse_node(parent)
      if PARSER_MAP.key?(token.kind)
        self.send(PARSER_MAP[token.kind], parent)
      else
        raise NotImplementedError, "No handler for '#{token.kind}' token"
      end
    end

    def parse_singleline
      token = tokens.shift
      @ast = Ast::Spec.new(token) # Also creates a command group with a program object

      command_group = Ast::CommandGroup.new(@ast, token)
      command = Ast::Program.new(command_group, token)
      descr = Ast::Description.new(@ast, token)

      tokens.consume(nil, nil, nil) { |token|
        indent {
        case token.kind
          when :option
            parse_singleline_option(descr, token)
          when :command
            parse_singleline_command(descr, token)
          when :arg_spec
            raise NotImplemented
          when :arg_descr
            raise NotImplemented
          when :brief
            raise NotImplemented
        else
          parser_error token, "Illegal syntax"
        end
        }

      }
      tokens.empty? or parser_error tokens.head, "Unexpected token"
    end

    def parse_singleline_option(parent, token)
      constrain parent, Ast::Description
      defn = Ast::OptionDefinition.new(parent, token)
      descr = Ast::Description.new(defn, token)
      group = Ast::OptionGroup.new(defn, token)
      subgroup = Ast::OptionSubGroup.new(group, token)
      parse_option_token(subgroup, token)
    end

    def parse_singleline_command(parent, token)
      constrain parent, Ast::Description
      defn = Ast::CommandDefinition.new(parent, token)
      group = Ast::CommandGroup.new(defn, token)
      cmd = Ast::Command.new(group, token)
      descr = Ast::Description.new(defn, token)
      tokens.consume(:option, nil, nil) { |token| parse_singleline_option(descr, token) }
    end

    def parse_multiline
      @ast = Ast::Spec.new(tokens.shift) # Also creates a command group with a program object
      parse_program(@ast)
    end

    def parse_section(parent)
      constrain parent, Ast::Description
      parent.definition.is_a?(Ast::Spec) or parser_error token, "Sections can't be nested"
      
      defn = Ast::Definition.new(parent, token)
      if Lexer::SECTION_ALIASES.key? token.value
        section = Ast::BuiltinSection.new(defn, tokens.shift)
        if section.name == "SYNOPSIS"
          descr = Ast::Description.new(defn, token)
          parse_lines(descr)
          return # The SYNOPSIS section consume all lines
        end
      else
        section = Ast::Section.new(defn, tokens.shift, nil)
      end
      parse_description(defn, breakon: [:section])
    end

    def parse_subsection(parent)
      !parent.definition.is_a?(Ast::Spec) or parser_error token, "Subsections can't be on the top level"
      defn = Ast::Definition.new(parent, token)
      section = Ast::SubSection.new(defn, tokens.shift, nil)
      tokens.consume(:blank, nil, token.charno)
      parse_description(defn, breakon: [:section, :subsection])
    end

    def parse_description(parent, breakon: nil)
      constrain breakon, Symbol, [Symbol], nil

      if breakon
        breakon = Array(breakon).flatten
        l = lambda { |token|
          token && (
            token.charno > parent.token.charno ||
            token.charno == parent.token.charno && !breakon.include?(token.kind)
          )
        }
      else
        l = lambda { |token| token && token.charno > parent.token.charno }
      end

      tokens.consume(:blank, nil, nil)

      if l.call(token)
        descr = Ast::Description.new(parent, token)
        parse_node(descr) while l.call(token)
      else
        Ast::EmptyDescription.new(parent)
      end
    end

    def parse_blanks(parent)
      tokens.consume(:blank, nil, nil)
    end

    def parse_text(parent)
      t = token
      lines = tokens.consume(:text, nil, t.charno, &:value)
      Ast::Paragraph.new(parent, t, lines)
    end

    def parse_lines(parent, blanks: false)
      t = token
      kinds = [:text] + (blanks ? [:blank] : [])
      lines = tokens.consume(kinds, nil, :>=, t.charno, &:value)
      Ast::Lines.new(parent, t, lines) if !lines.empty?
    end

    def parse_code(parent)
      Ast::Code.new(parent, tokens.shift)
    end

    def parse_brief(parent)
      Ast::Brief.new(parent, tokens.shift)
    end

    def parse_option_definition(parent)
      defn = Ast::OptionDefinition.new(parent, token)
      parse_option_group(defn)
      parse_description(defn)
    end

    def parse_option_group(parent)
      constrain token.kind, :option
      group = Ast::OptionGroup.new(parent, parent.token)
      tokens.consume(:option, nil, token.charno) { |option|
        subgroup = Ast::OptionSubGroup.new(group, option)
        tokens.unshift option
        parse_option(subgroup)
        tokens.consume(:brief, option.lineno, nil) { |brief| Ast::Brief.new(subgroup, brief) }
      }
    end

    def parse_option(parent)
      constrain parent, Ast::Command, Ast::OptionSubGroup
      tokens.consume(:option, token.lineno, :>=, token.charno) { |token| parse_option_token(parent, token) }
    end

    def parse_option_token(parent, token)
      token.source =~ /^(-|--|\+|\+\+)(#{OPTION_NAME_LIST_RE})(?:=(.+?)(\?)?)?$/ or 
          parser_error token, "Illegal option: #{token.source.inspect}"
      initial = $1
      names = $2.split(",")
      arg = $3
      optional = !arg.nil? && !$4.nil?
      names.each { |name| name !~ RESERVED_NAME_RE or parser_error token, "Reserved name: #{name}" }
      idents = names.map(&:to_sym)
      repeatable = %w(+ ++).include?(initial)
      option = Ast::Option.new(parent, token, idents, repeatable, optional) 
      parse_argument(option, token, arg) if !arg.nil?
      option
    end

    def parse_argument(parent, token, arg)
      return if arg.nil?

      named = true
      if arg =~ /^([^:]+)(?::(.*))/
        argument_name = $1
        named = true
        arg = $2
      elsif arg =~ /^:(.*)/
        arg = $1
        named = false
      end

      case arg
        when "", nil
          argument_name ||= "STR"
          argument_type = Type::StringType.new
        when "#"
          argument_name ||= "INT"
          argument_type = Type::IntegerType.new
        when "$"
          argument_name ||= "NUM"
          argument_type = Type::FloatType.new
        when "FILE", "DIR", "PATH", "EFILE", "EDIR", "EPATH", "NFILE", "NDIR", "NPATH", "IFILE", "OFILE"
          argument_name ||= arg.sub(/^(?:E|N|I|O)/, "")
          argument_type = Type::FileType.new(arg.downcase.to_sym)
        when /,/
          argument_name ||= arg
          argument_type = Type::EnumType.new(arg.split(","))
        else
          named && argument_name.nil? or parser_error token, "Illegal type expression: #{arg.inspect}"
          argument_name = arg
          argument_type = Type::StringType.new
      end

      Ast::Arg.new(parent, token, argument_name, argument_type)
    end

    def parse_command_definition(parent)
      defn = Ast::CommandDefinition.new(parent, token)
      parse_command_group(defn)
      parse_description(defn)
    end

    def parse_program(defn)
      group = Ast::CommandGroup.new(defn, defn.token)
      command = Ast::Program.new(group, defn.token)
      parse_description(defn)
    end

    def parse_command_group(parent)
      group = Ast::CommandGroup.new(parent, parent.token)
      tokens.consume(:command, nil, token.charno) { |command|
        cmd = Ast::Command.new(group, command)
        tokens.consume([:option, :arg_descr, :arg_spec, :brief], command.lineno, nil) { |t|
          if t.kind == :option # Special handling because these options does not belong to a group
            tokens.unshift t
            parse_option(cmd) # FIXME: Why not parse_node(cmd) ?
          else
            tokens.unshift t
            parse_node(cmd)
          end
        }
      }
    end

    def parse_arg_spec(parent)
      spec = Ast::ArgSpec.new(parent, tokens.shift)
      tokens.consume(:arg, token.lineno, nil) { |token| 
        parse_argument(spec, token, token.value)
      }
    end

    def parse_arg_descr(parent)
      Ast::ArgDescr.new(parent, tokens.shift)
    end

    def parse_list(parent)
      list = Ast::List.new(parent, token)
      tokens.consume(:bullet, nil, token.charno) { |t|
        t.value == list.bullet or 
            parser_error t, "Can't change bullet type to '#{t.value} in list of '#{list.bullet}' bullets"
        list_item = Ast::ListItem.new(list, t)
        Ast::Bullet.new(list_item, t)
        parse_description(list_item)
      }
    end
  end
end

