
require './lib/shellopts/ext/case.rb'

describe "CaseMatcher" do
  # This class leaks out to the containing environment but Class.new doesn't
  # seem to honor 'include CaseMatcher'
  class Matcher 
    include CaseMatcher

    def self.match(v)
      case v
        when Ordinal
          "ordinal"
        when Integer
          "integer"
        when Empty
          "empty"
        when !Empty
          "not empty"
      else
        "something else"
      end
    end

    def match(v) self.class.match(v) end
  end

  def match(value) Matcher.new.match(value) end

  describe "Ordinal" do
    it "matches integers >= 1" do
      expect(match 0).to eq "integer"
      expect(match 1).to eq "ordinal"
      expect(match 2).to eq "ordinal"
    end
  end

  describe "Empty" do
    it "matches object with an #empty? method that returns true" do
      expect(match []).to eq "empty"
      expect(match [1]).not_to eq "empty"
      expect(match({})).to eq "empty"
      expect(match k: 1).not_to eq "empty"
      expect(match "").to eq "empty"
      expect(match "hello").not_to eq "empty"
      expect(match 42).not_to eq "empty"
    end
  end

  describe "NotEmpty" do
    it "matches objects with an #empty? method that returns false or is absent" do
      expect(match []).not_to eq "not empty"
      expect(match [1]).to eq "not empty"
      expect(match({})).not_to eq "not empty"
      expect(match k: 1).to eq "not empty"
      expect(match "").not_to eq "not empty"
      expect(match 42).not_to eq "not empty"
    end
  end

  describe "!Empty" do
    it "returns a NotEmpty class" do
      expect(!CaseMatcher::Empty).to eq CaseMatcher::NotEmpty
    end
  end
end


# it "makes Ordinal available in when clauses" do
#   
# end
#
#f(Empty.new)
#f(1)
#f(0)
#f(Time.now)
#f("hej")
#f("")
#f([1, 2, 3])
#f([])
#end
