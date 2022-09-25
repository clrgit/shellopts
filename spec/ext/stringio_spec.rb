
require './lib/shellopts/ext/stringio.rb'

class RSpec_Ext_StringIO_Redirect
  using Ext::StringIO::Redirect
  def self.redirect(*args, &block) = ::StringIO.redirect(*args, &block)
end

describe "Ext::StringIO::Redirect" do
  let(:klass) { RSpec_Ext_StringIO_Redirect }

  describe "::redirect" do
    it "redirects $stdout" do
      s = klass.redirect(:stdout) { print "StdOut" }
      expect(s).to eq "StdOut"
    end
    it "redirects $stderr" do
      s = klass.redirect(:stderr) { $stderr.print "StdErr" }
      expect(s).to eq "StdErr"
    end
    it "redirects $stdin" do
      s = klass.redirect(:stdin, :stdout, "StdIn") {
        ss = $stdin.read
        $stdout.print ss
      }
      expect(s).to eq "StdIn"
    end
  end
end
