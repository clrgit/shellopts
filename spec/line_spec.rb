
describe "ShellOpts" do
  describe "Line" do
    let(:s) { "what a wonderful world" } # string
    let(:is) { "  #{s}" } # indented string

    def line(source) ShellOpts::Line.new(1, 1, source) end

    describe "#charno" do
      it "is the position of the first non-whitespace character" do
        expect(line(s).charno).to eq 1
        expect(line(is).charno).to eq 3
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
        expect(line(is).source).to eq is
      end
    end

    describe "#text" do
      it "is the #source with prefixed and suffixed spaces removed" do
        expect(line("#{is}  ").text).to eq s
      end
    end

#   describe "#words" do
#     it "return an array of Word objects for the line" do
#       expect(line(s).words.map(&:text)).to eq %w(what a wonderful world)
#       expect(line(s).words.map(&:charno)).to eq [1, 6, 8, 18]
#     end
#     it "the charno of the words are relative to source" do
#       expect(line(is).words.map(&:charno)).to eq [3, 8, 10, 20]
#       expect(ShellOpts::Line.new(1, 7, is).words.map(&:charno)).to eq [9, 14, 16, 26]
#     end
#   end

    describe "#initialize" do
      it "adds the given charno to the position of the first non-whitespace character" do
        expect(ShellOpts::Line.new(1, 7, s).charno).to eq 7
        expect(ShellOpts::Line.new(1, 7, is).charno).to eq 9
      end
    end
  end
end

