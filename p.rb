
class Parser

  PARSER_MAP = {
    program: :parse_program,
    section: :parse_section,
    ...
  }

  def parse_token(token)
    self.send(PARSER_MAP[token.kind])
  end

  def parse_program
  end

  def parse_section
    ...
    stack.push Section.new(stack.top, tokens.shift)
    parse_description(tokens.while { not_a_new_section })
  end

  def parse_description(tokens)
    stack.push Description.new(stack.top, tokens.head)
    while token = tokens.shift
      case token
        when :this
        when :that
          ...
          parse_description(tokens.while { ... })
      end

      case token
        when :section; ...
        when :subsection; ...
        when :option; ...
        when :command; ...
        when ...
      else
      end

    end
  end

  def parse_option_grup(tokens)
    defn = Spec::Definition.new(stack.top, tokens.head)
    group = Spec::OptionGroup
    while tokens.charno == token.charno
      parse_option(...)
    end
  end

  def parse_option(tokens)
  end

  def parse_group
  end

end
