
class Parser

  # How to control indent?
  #   stack?
  #   explicit parameter?
  #   adding token as parameter?
  #   set a limit on the Parser object?

  PARSER_MAP = {
    program: :parse_program,
    section: :parse_section,
    ...
  }

  def token = tokens.head

# def parse_definition(parent)
#   if PARSER_MAP.key?(token.kind)
#     self.send(PARSER_MAP[token.kind], parent)
#   else
#     raise "Oops"
#   end
# end


  # SECTION (indent or no-indent)
  #   Text
  #
  #   SUBSECTION (no-indent)
  #
  #   Text
  #
  #     code()
  #     some_more_code()
  #
  #   o Bullet
  #     more text
  #
  #   --option
  #     Text
  #
  #   @brief # one-line parsing
  #   -- ARG
  #   ++ ARG
  #
  #

  # Every #parse_... method is supposed to consume all lines with an indent >=
  # the parent token's charno or >= the current token's charno 



  def parse_lines(parent, blanks: false)
    t = token
    kinds = [:text] + (blanks ? [:blank] : [])
    lines = tokens.consume(kinds, nil, :>=, t.charno, &:value)
    Spec::Lines.new(parent, t, lines) if !lines.empty?
  end

  def parse_section(parent)
    parent == @program or parser_error token, "Sections can't be nested"
    defn = Spec::Definition.new(parent, token)

    if Lexer::SECTION_ALIASES.key? token.value
      section = Spec::BuiltinSection.new(defn, token)
      if section.name == "SYNOPSIS"
        descr = Spec::Description.new(parent, token)
        parse_lines(descr)
        return # The SYNOPSIS section consume all lines
      end
    else
      section = Spec::Section.new(defn, token, nil)
    end

    # Skip blank lines so that the first token has the correct indent
    # TODO: Handle code blocks
    tokens.consume(:blank, nil, token.charno)
    
    # Parse section content. TODO: Handle outdent
    parse_description(defn)
  end

  def parse_subsection(parent)
    t = tokens.head
    Spec::Subsection.new(parent, token)

    # Skip blank lines
    tokens.consume(:blank, nil, t.charno) # TODO: Make consume return false if no token was found

    parse_description(parent)
  end

  def parse_description(parent)
    # TODO: Check if token.charno >= parent.token.charno

    descr = Description.new(parent, token)

    if PARSER_MAP.key?(token.kind)
      self.send(PARSER_MAP[token.kind], descr)
    else
      raise "oops"
    end
  end
end

__END__


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
