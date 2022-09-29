
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

    # Parse tokens and return stack.top-level Spec::Program object
    def parse
      parse_program
      @program
    end

  protected
    # Queue of tokens (TokenQueue object)
    attr_reader :tokens

    # First token of queue
    def token = tokens.head

    def parser_error(token, message) = raise ParserError, token, message

    # Saves some typing
    PARSER_MAP = {
      section: :parse_section,
      subsection: :parse_subsection,
      blank: :parse_blanks,
      text: :parse_text,
      code: :parse_code,
      option: :parse_option,
      command: :parse_command,
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

    def parse_section(parent)
      constrain parent, Spec::Description
      parent.definition.is_a?(Spec::Program) or parser_error token, "Sections can't be nested"
      
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
      !parent.definition.is_a?(Spec::Program) or parser_error token, "Subsections can't be on the top level"
      defn = Spec::Definition.new(parent, token)
      section = Spec::SubSection.new(defn, tokens.shift, nil)
      tokens.consume(:blank, nil, token.charno)
      parse_description(defn, breakon: [:section, :subsection])
    end

    def parse_program
      @program = Spec::Program.new(tokens.shift) # Also creates a subject
      parse_description(@program)
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

    def parse_option(parent)
      defn = Spec::Definition.new(parent, token)
      parse_option_group(defn)
      parse_description(defn)
    end

    def parse_option_group(parent)
      group = Spec::OptionGroup.new(parent, parent.token)
      head = token
      tokens.consume(:option, nil, token.charno) { |option|
        subgroup = Spec::OptionSubGroup.new(group, option)
        tokens.unshift option
        tokens.consume(:option, option.lineno, nil) { |t| Spec::Option.new(subgroup, t) }
        tokens.consume(:brief, option.lineno, nil) { |brief| Spec::Brief.new(subgroup, brief) }
      }
    end

    def parse_command(parent)
      defn = Spec::Definition.new(parent, token)
      parse_command_group(defn)
      parse_description(defn)
    end

    def parse_command_group(parent)
      group = Spec::CommandGroup.new(parent, parent.token)
      head = token
      tokens.consume(:command, nil, token.charno) { |command|
        subgroup = Spec::CommandSubGroup.new(group, command)
        tokens.unshift command
        tokens.consume(:command, command.lineno, nil) { |cmd| Spec::Command.new(subgroup, cmd) }
        tokens.consume([:arg_descr, :arg_spec, :brief], command.lineno, nil) { |t|
          tokens.unshift t
          parse_node(subgroup)
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

