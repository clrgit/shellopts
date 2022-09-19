module ShellOpts
# class Word
#   attr_reader :line
#   forward_to :line, :lineno
#   attr_reader :charno
#   attr_reader :text
#
#   def initialize(line, charno, text)
#     @line, @charno, @text = line, charno, text
#   end
#
#   def to_s = text
# end

  class Line
    # Line number (one based)
    attr_reader :lineno 

    # Position of first non-blank character in #source (one based). It is
    # past-the-end if source is empty or blank
    attr_reader :charno 

    # The whole line as given to #initialize
    attr_reader :source
#   def source=(source) @source = source; @text = 

    # The source with prefixed and suffixed spaces removed. #text is used by
    # methods that treat the line as text
    attr_reader :text

    # The text with in-line comments removed. This is only relevant for lines
    # that are part of a definition, paragraphs and other text elements can't
    # be commented. Computed lazily
    def expr = @expr ||= text.sub(/\s+#.*/, "")

    # The given charno should be 1 except for a line in a one-line program
    # specification (eg. in +SPEC="-a ARG"+ charno should be 7)
    def initialize(lineno, charno, source)
      @lineno, @source = lineno, source
      @charno = charno + ((@source =~ /(\S.*?)\s*$/) || @source.size)
      @text = $1 || ""
    end
    
    def empty? = @source.empty?
    def blank? = @text.empty?

    forward_to :@text, :=~, :!~, :to_s, :[]

    # Words in expr. Return array of [charno, word] tuples
    def words
      return @words if @words
      @words = []
      charno = self.charno
      expr.scan(/(\s*)(\S*)/)[0..-2].each { |spaces, word|
        charno += spaces.size
        @words << [charno, word]
        charno += word.size
      }
      @words
    end

    def dump() puts "#{lineno}:#{charno} #{text.inspect}" end
  end
end
