
describe "ShellOpts::ShellOpts" do
  def make(*args, **opts) = ShellOpts::ShellOpts.new(*args, **opts)

  describe "#name" do
    it "can be set using an option" do
      s = make(name: "prg")
      expect(s.name).to eq "prg"
    end
    it "defaults to the name of the executable" do
      s = make
      expect(s.name).to eq "rspec"
    end
  end

  describe "#spec" do
    it "is initially nil" do
      s = make
      expect(s.spec).to eq nil
    end
    it "is set by #compile" do
      s = make
      src = "-a"
      s.compile(src)
      expect(s.spec).to eq src
    end
  end

end
