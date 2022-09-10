
require 'shellopts/ext/follow.rb'

describe "Algorithm" do
  describe "::follow" do
    context "when given a method" do
      let(:node_class) {
        Class.new do
          attr_reader :parent
          attr_reader :name
          def initialize(name, parent) @name, @parent = name, parent end
        end
      }

      let(:root) { node_class.new("root", nil) }
      let(:child) { node_class.new("child", root) }
      let(:grandchild) { node_class.new("grandchild", child) }

      it "returns a list of objects" do
        expect(Algorithm.follow(grandchild, :parent).map(&:name)).to eq %w(grandchild child root)
        expect(Algorithm.follow(child, :parent).map(&:name)).to eq %w(child root)
        expect(Algorithm.follow(root, :parent).map(&:name)).to eq %w(root)
      end
    end
    context "when given a block" do
      it "returns a list of objects" do
        expect(Algorithm.follow(3) { |current| current < 10 ? current + 1 : nil }.to_a).to eq (3..10).to_a
      end
    end
  end
end

