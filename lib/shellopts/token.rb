
module ShellOpts
  class Token
    using Ext::Array::PopWhile

    # The tokens are
    #
    # :program
    #   artificial token at line 0, character 0. The lexer create this as the
    #   first token
    #
    # :section
    #   a string in Lexer::SECTIONS or matching /^\*.*\*$/
    #
    # :option
    #   a string starting with '-' or '--'
    #
    # :command
    #   a string matching /\w!/
    #
    # :arg_spec
    #   a string matching /^++\s+/
    #
    # :arg
    #   a word following a spec token
    #
    # :arg_descr
    #   a string matching /^--\s+.*$/
    #
    # :brief
    #   a string matching /^@\s+.*$/
    #
    # :text
    #   any other text
    #
    # :code
    #   a multiline string of code
    #
    # :bullet
    #   a list bullet
    #
    # :blank
    #   a blank line
    #   
    KINDS = [
        :program, :section, :subsection, :option, :command, :arg_spec, :arg, :arg_descr, :brief,
        :text, :code, :bullet, :blank
    ]

    # Kind of token
    attr_reader :kind

    # Line number (one-based)
    attr_reader :lineno

    # Char number (one-based). The lexer may adjust the char number (eg. to
    # make blank lines have the same indent level as the previous token)
    attr_accessor :charno

    # Location. A tuple of [lineno, charno]. Implemented for convenience
    def location = [lineno, charno]

    # Token source
    attr_reader :source

    # Token string value. This is usually equal to source
    def value = @value ||= (lines ? lines.join("\n") : source)

    # Token lines. Nil except for :code tokens
    attr_reader :lines

    # +lineno+ and +charno+ are zero for the :program token and >= 1 otherwise.
    # 1 is also used for artificial tokens
    def initialize(kind, lineno, charno, source, value = source, lines = nil)
      constrain kind, *KINDS
      constrain lineno, Integer
      constrain charno, Integer
      constrain source, String
      constrain value, String, nil
      constrain lines, [String], nil
      @kind, @lineno, @charno, @value, @source, @lines = kind, lineno, charno, value, source, lines
    end

    forward_to :value, :to_s, :empty?, :=~, :!~

    # Emit a "<lineno>:<charno>" string
    def location(start_lineno = 1, start_charno = 1) 
      "#{start_lineno + lineno - 1}:#{start_charno + charno - 1}" 
    end

    alias_method :pos, :location # FIXME Rename pos -> location

    def inspect
      "<#{self.class.name} #{location} #{kind.inspect} #{value.inspect}>"
    end

    def dump
      puts "#{kind}@#{lineno}:#{charno} #{value.inspect}"
    end
  end
end
