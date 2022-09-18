
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
    # :blank
    #   a blank line
    #   
    KINDS = [
        :program, :section, :option, :command, :arg_spec, :arg, :arg_descr, :brief,
        :text, :blank
    ]

    # Kind of token
    attr_reader :kind

    # Line number (one-based)
    attr_reader :lineno

    # Char number (one-based). The lexer may adjust the char number (eg. to
    # make blank lines have the same indent level as the previous token)
    attr_accessor :charno

    # Token string value. This is usually equal to source
    attr_reader :value

    # Token source. Equal to #value except for section, brief, and descr tokens
    attr_reader :source

    # +lineno+ and +charno+ are zero for the :program token and >= 1 otherwise
    def initialize(kind, lineno, charno, value, source = value)
      constrain kind, *KINDS
      constrain [lineno, charno], [kind == :program ? Integer : Ordinal] # lol
      constrain value, String
      constrain source, String
      @kind, @lineno, @charno, @value, @source = kind, lineno, charno, value, source
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
