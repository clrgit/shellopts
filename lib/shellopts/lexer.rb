
module ShellOpts
  class Lexer
    OPTION_RE = /--?\S/

    # Commands are always lower-case. This prevents collision with named
    # arguments that are always upper-case
    COMMAND_RE = /[a-z][a-z0-9._-]*!/ 

    SPEC_RE = /\+\+/
    DESCR_RE = /--/
    BRIEF_RE = /@/

    DESCR_STOP_RE = /^(?:#{SPEC_RE}|#{DESCR_RE}|#{BRIEF_RE})/
    SPEC_STOP_RE = /^(?:#{SPEC_RE}|#{DESCR_RE}|#{BRIEF_RE})/

    # Match argument spec words. The words should begin with at least two
    # uppercase letters. This makes it possible to say +opts.FILE_ARGUMENT+
    # because it can't conflict with a single letter uppercase option and long
    # options are always downcased internally (TODO). Rather primitive for now
    ARG_RE = /^[A-Z0-9_-]{2,}$/

    SINGLE_LINE_WORDS = %w(-- ++ @)

    DECL_RE = /^(?:#{OPTION_RE}|#{COMMAND_RE}|#{DESCR_RE} |#{SPEC_RE} |#{BRIEF_RE})/

    SECTIONS = %w(NAME SYNOPSIS DESCRIPTION OPTIONS COMMANDS)
    SECTION_ALIASES = {
      "USAGE" => "SYNOPSIS",
      "OPTION" => "OPTIONS",
      "COMMAND" => "COMMANDS"
    }.merge SECTIONS.map { |n| [n, n] }.to_h

    using Ext::Array::ShiftWhile

    attr_reader :name # Name of program
    attr_reader :source # A multiline string
    attr_reader :tokens # List of tokens. Initialized by #lex
    
    def initialize(name, source)
      @name = name
      @source = source.end_with?("\n") ? source : source + "\n" # Always terminate source with a newline
      @last_token = nil
    end

    def lex(lineno = 1, charno = 1)
      # Split source into lines and tag them with lineno and charno. Only the
      # first line can have charno != 1 (this happens in one-line declarations)
      lines = source[0..-2].split("\n").map.with_index { |line,i|
        l = Line.new(i + lineno, charno, line)
        charno = 1
        l
      }

      # Skip initial comments and blank lines and compute indent level. All
      # lines starting with '#' is considered a comment here so a spec can't
      # start with an '#' list
      lines.shift_while { |line| line.text == "" || line.text.start_with?("#") }
      initial_indent = lines.first&.charno

      # Create artificial program token. The token has the program name as value
      @tokens = [Token.new(:program, 0, 0, name)]

      # Reference to last non-blank token. Used to detect code blocks
      last_nonblank = @tokens.first

      # Process lines
      while line = lines.shift
        if line.blank?
          # Code block. A code block is preceeded by a blank line and indented
          # beyond the last non-blank token's indentation (just the parent?).
          # It should also not look like declaration of an option or a command
          # - the first line in the block can be escaped with a \ to solve that
          if lines.first && lines.first.charno > last_nonblank.charno && lines.first !~ DECL_RE
            indent = lines.first.charno - 1
            code = lines
                .shift_while { |l| l.blank? || l.charno >= indent }
                .map { |line| line.source[indent..-1] }
            code[0] = code[0] && unescape(code[0])
            source = code.join("\n")
            add_token :code, line.lineno, line.charno, source, code
            next # 'next' ensures that last_nonblank is unchanged
          
          # Ordinary blank line. Charno is set to the charno of the last
          # non-blank line
          else
            add_token :blank, line.lineno, last_nonblank.charno, ""
          end

          next # 'next' ensures that last_nonblank is unchanged
        end
          
        # Ignore full-line comments. Full-line comments are lines with '#' as
        # the first non-space character and with an indent less than the
        # initial indent. This avoids conflicts with '#' as a bullet marker
        next if line.charno < initial_indent && line.text.start_with?("#")

        # Check indent
        line.charno >= initial_indent or lexer_error line.lineno, 1, false, "Illegal indent"

        # Sections
        if SECTION_ALIASES.key?(line.expr)
          value = SECTION_ALIASES[line.expr]
          add_token :section, line.lineno, line.charno, line.expr, value

        # Options, commands, usage, arguments, and briefs. The line is broken
        # into words to be able to handle one-line declarations (options with
        # briefs and one-line subcommands)
        elsif line.expr =~ DECL_RE
          words = line.words
          while (charno, word = words.shift)
            # Ensure mandatory arguments. This doesn't include the '@text' brief type
            if SINGLE_LINE_WORDS.include?(word) && words.empty?
              lexer_error line.lineno, charno, "Empty '#{word}' declaration"
            end

            case word
              when /@(.+)?/ # $1 can be nil. If so, we know that there are some arguments
                value = ([$1] + words.shift_while { true }.map(&:last)).compact.join(" ")
                add_token :brief, line.lineno, charno, word, value
              when "--"
                # Eat line until stop-word
                value = words.shift_while { |_,word| word !~ DESCR_STOP_RE }.map(&:last).join(" ") 
                add_token :arg_descr, line.lineno, charno, word, value
              when "++"
                add_token :arg_spec, line.lineno, charno, word
                words.shift_while { |charno,word|
                  word =~ ARG_RE and add_token :arg, line.lineno, charno, word
                }
              when /^-|\+/
                add_token :option, line.lineno, charno, word
              when /!$/
                add_token :command, line.lineno, charno, word
            else
              lexer_error(line.lineno, line.charno, "Unexpected word: '#{word}'")
            end
          end

        # Paragraph lines
        else
          add_token :text, line.lineno, line.charno, line.text, unescape(line.text)
        end

        # This works because we know that only non-blank tokens reach this line
        last_nonblank = @tokens.last
      end

      @tokens
    end

    def self.lex(name, source, lineno = 1, charno = 1)
      Lexer.new(name, source).lex(lineno, charno)
    end

    def lexer_error(lineno, charno, message) 
      token = Token.new(:text, lineno, charno, "")
      raise LexerError.new(token), message
    end

  protected
    # Unescape line by removing initial '\'
    def unescape(line) = line.sub(/^(\s*)\\/, '\1')

    def add_token(kind, lineno, charno, source, value_or_lines = source)
      if kind == :code
        token = CodeToken.new(lineno, charno, source, value_or_lines)
      else
        token = Token.new(kind, lineno, charno, source, value_or_lines)
      end
      @tokens << token
      token
    end
  end
end

