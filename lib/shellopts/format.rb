
# Not used atm.
module ShellOpts
  module Format
    def putm(member)
      puts "#{member}: #{self.send(member)}"
    end
  end
end
