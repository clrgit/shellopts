require 'spec_helper.rb'

#require 'shellopts/args.rb'

class RSpecMessenger
  attr_reader :message
  def error(*msgs) @message = msgs.join end
  def fail(*msgs) @message = msgs.join end
end

class RSpecShellOpts
  attr_reader :messenger
  def initialize(messenger)
    @messenger = messenger
  end
end

include ShellOpts

describe Args do
  let(:messenger) { RSpecMessenger.new }
  let(:shellopts) { RSpecShellOpts.new(messenger) }
  let(:args) { Args.new(shellopts, [1, 2, 3, 4, 5]) }
  let(:args0) { Args.new(shellopts, []) }
  let(:args1) { Args.new(shellopts, [1]) }
  let(:args2) { Args.new(shellopts, [1, 2]) }
  let(:args3) { Args.new(shellopts, [1, 2, 3]) }

  describe "#extract" do
    context "when given a count" do
      it "shifts elements from the beginning of the array" do
        expect(args.extract(2)).to eq [1, 2]
        expect(args).to eq [3, 4, 5]
      end
      it "shifts elements from the end of the array if count is negative" do
        expect(args.extract(-2)).to eq [4, 5]
        expect(args).to eq [1, 2, 3]
      end
      it "returns nil if count is 0" do
        expect(args3.extract(0)).to eq nil
        expect(args3).to eq [1, 2, 3]
      end
      it "returns an object if count is 1" do
        expect(args3.extract(1)).to eq 1
        expect(args3).to eq [2, 3]
      end
      it "returns an array if count is greater than 1" do
        expect(args3.extract(2)).to eq [1, 2]
        expect(args3).to eq [3]
      end
      it "expects at least count elements" do
        expect { args.extract(10) }.to raise_error ::ShellOpts::Error
      end
    end
    context "when given a range" do
      it "shifts elements from the beginning of the array" do
        expect(args.extract(2..3)).to eq [1, 2, 3]
        expect(args).to eq [4, 5]
      end
      it "returns an object if max length is 0 or 1" do
        expect(args0.expect(0..0)).to eq nil
        expect(args0.expect(0..1)).to eq nil
        expect(args1.expect(0..1)).to eq 1
        expect(args2.expect(0..2)).to eq [1, 2]
      end
      it "returns an array if max length is greater than 1" do
        expect(args1.extract(0..3)).to eq [1, nil, nil]
        expect(args2.extract(0..3)).to eq [1, 2, nil]
      end
      it "expects the range to require at most the full array" do
        expect { args.extract(6..10) }.to raise_error ShellOpts::Error
      end
    end
    it "emits a custom message if given" do
      expect { args.extract(6..10, "Custom") }.to raise_error ShellOpts::Error, "Custom"
    end
  end

  describe "#expect" do
    let(:inoa) { "Illegal number of arguments" }

    it "returns the elements of the array" do
      expect(args.expect(5)).to eq [1, 2, 3, 4, 5]
    end
    context "when given a count" do
      it "returns nil if count is 0" do
        expect(args0.expect(0)).to eq nil
      end
      it "returns an object if count is 1" do
        expect(args1.expect(1)).to eq 1
      end
      it "returns an array if count is greater than 1" do
        expect(args2.expect(2)).to eq [1, 2]
      end
      it "expects exactly count elements" do
        expect { args.expect(4) }.to raise_error inoa
        expect { args.expect(6) }.to raise_error inoa
        expect { args.expect(5) }.not_to raise_error 
      end
    end
    context "when given a range" do
      it "expects the range to include the number of elements" do
        expect { args.expect(0..4) }.to raise_error inoa
        expect { args.expect(6..10) }.to raise_error inoa
      end
      it "returns an object if max length is 0 or 1" do
        expect(args0.expect(0..0)).to eq nil
        expect(args0.expect(0..1)).to eq nil
        expect(args1.expect(0..1)).to eq 1
        expect(args2.expect(0..2)).to eq [1, 2]
      end
      it "returns an array if max length is greater than 1" do
        expect(args2.expect(0..2)).to eq [1, 2]
      end
    end
    it "emits a custom message if given" do
      expect { args.expect(10, "Custom") }.to raise_error ShellOpts::Error, "Custom"
    end
  end
end

