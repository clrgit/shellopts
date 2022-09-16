
module ShellOpts
  class Token
    # Each kind should have a corresponding Grammar class with the same name
    KINDS = [
        :program, :section, :option, :command, :arg_spec, :argument, :arg_descr,
        :arg_descr_string, :brief, :text, :blank 
    ]

    ONE_LINE_KINDS = [
        :program, :option, :command, :argument, :brief
    ]

    # Kind of token
    attr_reader :kind

    # Line number (one-based)
    attr_reader :lineno

    # Char number (one-based). The lexer may adjust the char number (eg. for
    # blank lines)
    attr_accessor :charno

    # Source of the token
    attr_reader :source

    def initialize(kind, lineno, charno, source)
      constrain kind, :program, *KINDS
      @kind, @lineno, @charno, @source = kind, lineno, charno, source
    end

    forward_to :source, :to_s, :empty?

    def pos(start_lineno = 1, start_charno = 1) 
      "#{start_lineno + lineno - 1}:#{start_charno + charno - 1}" 
    end

    def to_s() source end

    def inspect() 
      "<#{self.class.to_s.sub(/.*::/, "")} #{pos} #{kind.inspect} #{source.inspect}>"
    end

    def dump
      puts "#{kind}@#{lineno}:#{charno} #{source.inspect}"
    end
  end
end
