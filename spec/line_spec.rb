
describe "ShellOpts" do
  describe "Line" do
    let(:s) { "what a wonderful world" } # string
    let(:ss) { "  #{s}  " } # spaced string
    let(:cs) { "what a # wonderful world" } # commented string

    def line(source) ShellOpts::Line.new(1, 1, source) end

    describe "#charno" do
      it "is the position of the first non-whitespace character" do
        expect(line(s).charno).to eq 1
        expect(line(ss).charno).to eq 3
      end

      it "is one if empty" do
        l = line("")
        expect(l.charno).to eq 1
        expect(l.source[l.charno-1]).to eq nil
      end

      it "is one beyond length of line if blank" do
        l = line("  ")
        expect(l.charno).to eq 3
        expect(l.source[l.charno-1]).to eq nil
      end
    end

    describe "#source" do
      it "is the whole line as given to #initialize" do
        expect(line(ss).source).to eq ss
      end
    end

    describe "#text" do
      it "is the #source with prefixed and suffixed spaces removed" do
        expect(line(ss).text).to eq s
      end
    end

    describe "#expr" do
      it "is #text with in-line comments removed" do
        expect(line(cs).expr).to eq "what a"
      end
    end

    describe "#words" do
      it "returns an array of [charno, word] tuples" do
        expect(line(s).words.map(&:first)).to eq [1, 6, 8, 18]
        expect(line(s).words.map(&:last)).to eq %w(what a wonderful world)
      end
      it "is based on #expr" do
        expect(line(cs).words.map(&:last)).to eq %w(what a)
      end
    end

    describe "#initialize" do
      it "adds the given charno to the position of the first non-whitespace character" do
        expect(ShellOpts::Line.new(1, 7, s).charno).to eq 7
        expect(ShellOpts::Line.new(1, 7, ss).charno).to eq 9
      end
    end
  end
end

