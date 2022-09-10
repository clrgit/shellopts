module ShellOpts
  class Line
    attr_reader :source
    attr_reader :lineno 
    attr_reader :charno
    attr_reader :text

    def initialize(lineno, charno, source)
      @lineno, @source = lineno, source
      @charno = charno + ((@source =~ /(\S.*?)\s*$/) || 0)
      @text = $1 || ""
    end

    def blank?() @text == "" end

    forward_to :@text, :=~, :!~

    # Split on whitespace while keeping track of character position. Returns
    # array of char, word tuples
    def words
      return @words if @words
      @words = []
      charno = self.charno
      text.scan(/(\s*)(\S*)/)[0..-2].each { |spaces, word|
        charno += spaces.size
        @words << [charno, word] if word != ""
        charno += word.size
      }
      @words
    end

    def to_s() text end
    def dump() puts "#{lineno}:#{charno} #{text.inspect}" end
  end
end
