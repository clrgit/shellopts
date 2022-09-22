
module ShellOpts
  class Token
    include ::CaseMatcher

    # The tokens are
    #
    # :program
    #   artificial token that is the first token
    #
    # :section
    #   all-caps string
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
    # :blank
    #   a blank line
    #   
    KINDS = [
        :program, :section, :option, :command, :arg_spec, :arg, :arg_descr, :brief,
        :text, :code, :blank
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

    # True if this token is on the same line as the previous token
    def same? = @same

    # Token source. Equal to #value except for section, brief, and descr tokens
    attr_reader :source

    # Token string value. This is usually equal to source
    attr_reader :value

    # +lineno+ and +charno+ are zero for the :program token and >= 1 otherwise
    def initialize(kind, lineno, charno, same, source, value = source)
      constrain kind, *KINDS
      constrain [lineno, charno], [kind == :program ? Integer : Ordinal] # lol
      constrain same, true, false
      constrain source, String
      constrain value, String
      @kind, @lineno, @charno, @same, @value, @source = kind, lineno, charno, same, value, source
    end

    forward_to :value, :to_s, :empty?, :blank?, :=~, :!~

    # Emit a "<lineno>:<charno>" string
    def location(start_lineno = 1, start_charno = 1) 
      "#{start_lineno + lineno - 1}:#{start_charno + charno - 1}" 
    end

#   def same?(other) = charno == other.charno
#   def indented?(other) = charno < other.charno
#   def outdented?(other) = charno > other.charno

    def inspect() 
      "<#{self.class.to_s.sub(/.*::/, "")} #{location} #{kind.inspect} #{value.inspect}>"
    end

    def dump
      puts "#{kind}@#{lineno}:#{charno} #{value.inspect}"
    end
  end
end
