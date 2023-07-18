

# The following code doesn't model class relationships so we need to be sure
# that Grammar has already been included
raise if !defined? ShellOpts::Grammar

module ShellOpts
  module Grammar
    module Format
      FORMATS = [:debug, :rspec, :rspec_command, :rspec_option]

      def self.set(format)
        constrain format, *FORMATS
        @@format = format
      end

      def self.get() = @@format

      @@format = :debug
    end

    class Node
      # Main format switcher for Spec objects. It instantiates a formatter
      # object from a class corresponding to the :format argument and let it
      # handle the output. The formatter class refines Spec, augmenting its
      # classes with methods to do the actual output
      def dump(format: nil)
        constrain format, *Format::FORMATS, nil
        formatter = 
            case format || Format.get
              when :debug; Format::Short::Formatter.new
              when :rspec; Format::RSpec::Formatter.new
              when :rspec_command; Format::RSpecCommand::Formatter.new
              when :rspec_option; Format::RSpecOption::Formatter.new
            else
              raise 
            end
        formatter.format(self)
      end
    end
  end
end

#p ShellOpts::Grammar::Format::Short::Formatter

require_relative './grammar_debug.rb'
require_relative './grammar_rspec.rb'
