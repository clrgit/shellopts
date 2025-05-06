
include ShellOpts

describe "Args" do
  describe "#extract" do
    let(:a) { Args.new %w(a b c d), exception: true }
    let(:e) { Args.new [], exception: true }

    context "when given an integer argument" do
      context "when arg > 1" do
        it "returns an array of extracted elements" do
          expect(a.extract(2)).to eq %w(a b)
          expect(a).to eq %w(c d)
        end
        it "raise a ShellOpts::Error if the array doens't contain enough elements" do
          expect { a.extract(5) }.to raise_error ShellOpts::Error
        end
      end

      context "when arg == 1" do
        it "returns a single extracted element" do
          expect(a.extract(1)).to eq "a"
        end
        it "raise a ShellOpts::Error if the array is empty" do
          expect { e.extract(1) }.to raise_error ShellOpts::Error
        end
      end

      context "when arg == 0" do
        it "returns an empty array" do
          expect(a.extract(0)).to eq []
          expect(e.extract(0)).to eq []
        end
      end

      context "when arg < 0" do
        it "returns an array of extracted elements from the end" do
          expect(a.extract(-2)).to eq %w(c d)
          expect(a).to eq %w(a b)
        end

        it "raise a ShellOpts::Error if the array doens't contain enough elements" do
          expect { a.extract(-5) }.to raise_error ShellOpts::Error
        end
      end
    end

    context "when given a range" do
      context "when given an endless range" do
        it "returns the rest of the arguments" do
          expect(a.extract(1..)).to eq %w(a b c d)
        end
        it "fails if the minimum number of elements is not present" do
          expect { a.extract(5..) }.to raise_error ShellOpts::Error
        end
      end
    end
  end

  describe "#extract?" do
    let(:a) { Args.new %w(a b c d), exception: true }
    let(:e) { Args.new [], exception: true }

    context "when given an integer" do
      it "returns true iff the elements can be extracted" do
        expect(a.extract? 1).to eq true
        expect(e.extract? 1).to eq false
      end
    end

    context "when given a range" do
      it "return true if the range of elements can be extracted" do
        expect(a.extract? 1..5).to eq true
        expect(e.extract? 1..5).to eq false
      end
      it "supports open ranges" do
        expect(a.extract? 1..).to eq true
      end
    end
  end


  describe "#expect" do
    let(:a) { Args.new %w(a b), exception: true }
    let(:a1) { Args.new %w(a), exception: true }
    let(:e) { Args.new [], exception: true }

    context "when given an integer argument" do
      context "when arg > 1" do
        it "returns an array of extracted elements" do
          expect(a.expect(2)).to eq %w(a b)
        end

        it "raise a ShellOpts::Error if the array is not emptied by the operation" do
          expect { a.expect(1) }.to raise_error ShellOpts::Error
        end

        it "raise a ShellOpts::Error if the array doens't contain enough elements" do
          expect { a.expect(5) }.to raise_error ShellOpts::Error
        end
      end

      context "when arg == 1" do
        it "returns a single extracted argument" do
          expect(a1.extract(1)).to eq "a"
          expect(a1).to be_empty
        end
        it "raise a ShellOpts::Error if the array is empty" do
          expect { e.extract(1) }.to raise_error ShellOpts::Error
        end
      end

      context "when arg == 0" do
        it "returns an empty array if the array is empty" do
          expect(e.expect(0)).to eq []
        end
        it "raises a ShellOpts::Error if the array is not empty" do
          expect { a.expect(0) }.to raise_error ShellOpts::Error
        end
      end

      context "when arg < 0" do
        it "raises a ShellOpts::Error" do
          expect { a.expect(-2) }.to raise_error ShellOpts::Error
        end
      end
    end

    context "when given a range" do
      context "when given an endless range" do
        it "returns the rest of the arguments" do
          expect(a.expect(1..)).to eq %w(a b)
        end
        it "fails if the minimum number of elements is not present" do
          expect { a.expect(3..) }.to raise_error ShellOpts::Error
        end
      end
    end
  end

  describe "#expect?" do
    let(:a) { Args.new %w(a b c d), exception: true }
    let(:e) { Args.new [], exception: true }

    context "when given an integer" do
      it "returns true iff the elements can be expected" do
        expect(a.expect? 4).to eq true
        expect(e.expect? 4).to eq false
      end
    end

    context "when given a range" do
      it "return true if the range of elements can be expected" do
        expect(a.expect? 1..4).to eq true
        expect(e.expect? 1..4).to eq false
      end
    end
  end

end









