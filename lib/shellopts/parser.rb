
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

    # The resulting Spec::Program object
    attr_reader :program

    def initialize(tokens)
      constrain tokens, [Token]
      @tokens = TokenQueue.new tokens
    end

    # Parse tokens and return Spec::Spec object
    def parse
      parse_spec
      @spec
    end

  protected
    SHORT_OPTION_NAME_RE = /[a-zA-Z0-9?]/
    LONG_OPTION_NAME_RE = /[a-zA-Z0-9][a-zA-Z0-9_-]*/
    OPTION_NAME_RE=/(?:#{SHORT_OPTION_NAME_RE}|#{LONG_OPTION_NAME_RE})/
    OPTION_NAME_LIST_RE = /#{OPTION_NAME_RE}(?:,#{OPTION_NAME_RE})*/

    # Queue of tokens (TokenQueue object)
    attr_reader :tokens

    # Current token, first token of queue
    def token = tokens.head

    def parser_error(token, message) = raise ParserError, token, message

    # Saves some typing
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
        raise NotImplementedError, "Missing handler for token kind '#{token.kind}'"
      end
    end

    def parse_spec
      @spec = Spec::Spec.new(tokens.shift) # Also creates a command group with a program object
      parse_program(@spec)
    end

    def parse_section(parent)
      constrain parent, Spec::Description
      parent.definition.is_a?(Spec::Spec) or parser_error token, "Sections can't be nested"
      
      defn = Spec::Definition.new(parent, token)
      if Lexer::SECTION_ALIASES.key? token.value
        section = Spec::BuiltinSection.new(defn, tokens.shift)
        if section.name == "SYNOPSIS"
          descr = Spec::Description.new(defn, token)
          parse_lines(descr)
          return # The SYNOPSIS section consume all lines
        end
      else
        section = Spec::Section.new(defn, tokens.shift, nil)
      end
      parse_description(defn, breakon: [:section])
    end

    def parse_subsection(parent)
      !parent.definition.is_a?(Spec::Spec) or parser_error token, "Subsections can't be on the top level"
      defn = Spec::Definition.new(parent, token)
      section = Spec::SubSection.new(defn, tokens.shift, nil)
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
        descr = Spec::Description.new(parent, token)
        parse_node(descr) while l.call(token)
      else
        Spec::EmptyDescription.new(parent)
      end
    end

    def parse_blanks(parent)
      tokens.consume(:blank, nil, nil)
    end

    def parse_text(parent)
      t = token
      lines = tokens.consume(:text, nil, t.charno, &:value)
      Spec::Paragraph.new(parent, t, lines)
    end

    def parse_lines(parent, blanks: false)
      t = token
      kinds = [:text] + (blanks ? [:blank] : [])
      lines = tokens.consume(kinds, nil, :>=, t.charno, &:value)
      Spec::Lines.new(parent, t, lines) if !lines.empty?
    end

    def parse_code(parent)
      Spec::Code.new(parent, tokens.shift)
    end

    def parse_brief(parent)
      Spec::Brief.new(parent, tokens.shift)
    end

    def parse_option_definition(parent)
      defn = Spec::OptionDefinition.new(parent, token)
      parse_option_group(defn)
      parse_description(defn)
    end

    def parse_option_group(parent)
      constrain token.kind, :option
      group = Spec::OptionGroup.new(parent, parent.token)
      tokens.consume(:option, nil, token.charno) { |option|
        subgroup = Spec::OptionSubGroup.new(group, option)
        tokens.unshift option
        parse_option(subgroup)
        tokens.consume(:brief, option.lineno, nil) { |brief| Spec::Brief.new(subgroup, brief) }
      }
    end

    def parse_option(parent)
      constrain parent, Spec::Command, Spec::OptionSubGroup
#     constrain token.kind, :option
      tokens.consume(:option, token.lineno, :>=, token.charno) { |option|
        option.source =~ /^(-|--|\+|\+\+)(#{OPTION_NAME_LIST_RE})(?:=(.+?)(\?)?)?$/ or 
            parser_error option, "Illegal option: #{option.source.inspect}"
        initial = $1
        names = $2
        arg = $3
        optional = !$4.nil?
        repeatable = %w(+ ++).include?(initial)
        idents = names.split(",").map(&:to_sym)

        named = true
        if arg.nil?
          argument_name = nil
          argument_type = nil
        else
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
              argument_name ||= "VAL"
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
              named && argument_name.nil? or parser_error option, "Illegal type expression: #{arg.inspect}"
              argument_name = arg
              argument_type = Type::StringType.new
          end
          optional = !optional.nil?
        end
        Spec::Option.new(parent, option, idents, repeatable, optional, argument_name, argument_type) 
      }
    end

    def parse_command_definition(parent)
      defn = Spec::CommandDefinition.new(parent, token)
      parse_command_group(defn)
      parse_description(defn)
    end

    def parse_program(defn)
      group = Spec::CommandGroup.new(defn, defn.token)
      command = Spec::Program.new(group, defn.token)
      parse_description(defn)
    end

    def parse_command_group(parent)
      group = Spec::CommandGroup.new(parent, parent.token)
      tokens.consume(:command, nil, token.charno) { |command|
        cmd = Spec::Command.new(group, command)
        tokens.consume([:option, :arg_descr, :arg_spec, :brief], command.lineno, nil) { |t|
          if t.kind == :option # Special handling because these options does not belong to a group
            tokens.unshift t
            parse_option(cmd)
#           Spec::Option.new(cmd, t)
          else
            tokens.unshift t
            parse_node(cmd)
          end
        }
      }
    end

    def parse_arg_spec(parent)
      spec = Spec::ArgSpec.new(parent, tokens.shift)
      tokens.consume(:arg, token.lineno, nil) { |t| Spec::Arg.new(spec, t) }
    end

    def parse_arg_descr(parent)
      Spec::ArgDescr.new(parent, tokens.shift)
    end

    def parse_list(parent)
      list = Spec::List.new(parent, token)
      tokens.consume(:bullet, nil, token.charno) { |t|
        t.value == list.bullet or 
            parser_error t, "Can't change bullet type to '#{t.value} in list of '#{list.bullet}' bullets"
        list_item = Spec::ListItem.new(list, t)
        Spec::Bullet.new(list_item, t)
        parse_description(list_item)
      }
    end

  end
end

#           # TODO TODO TODO Move to #parse_option
#           option = parse_option
#           option_doc = option.doc
#           push_node option
#
#           # Collect following options with the same indent
#           next_token = @tokens.first
#           while next_token.charno == token.charno && next_token.kind == :option
#             token = @tokens.shift
#             next_token = @token.first
#             option = Option.parse(cmds.top, token)
#             group << option
#           end
#
#           nodes.push option

