require "shellopts/version"

require 'shellopts/compiler.rb'
require 'shellopts/parser.rb'
require 'shellopts/utils.rb'
require 'shellopts/options_hash.rb'
require 'shellopts/messenger.rb'

# ShellOpts is a library for parsing command line options and sub-commands. The
# library API consists of the methods {ShellOpts.process}, {ShellOpts.error},
# and {ShellOpts.fail} and the result class {ShellOpts::ShellOpts}
#
# ShellOpts inject the constant PROGRAM into the global scope. It contains the 
# name of the program
#
module ShellOpts
  # Base class for ShellOpts exceptions
  class Error < RuntimeError; end

  # Raised when a syntax error is detected in the usage string
  class CompilerError < Error
    def initialize(start, message)
      super(message)
      set_backtrace(caller(start))
    end
  end

  # Raised when an internal error is detected
  class InternalError < Error; end

  # Return the hidden +ShellOpts::ShellOpts+ object (see .process)
  def self.shellopts()
    @shellopts
  end

  # Prettified usage string used by #error and #fail. Default is +usage+ of
  # the current +ShellOpts::ShellOpts+ object
  def self.usage() @usage || @shellopts&.usage end

  # Set the usage string. You will often use a custom-made usage string to
  # split up a complex usage description over multiple lines when the command
  # line contains several sub-commands each with their own set of options
  def self.usage=(usage) @usage = usage end

  # Process command line. If a block is given, options are feed to the block in
  # name-value option pairs and a list of remaning command-line arguments is
  # returned. If not given a block, #each returns a ShellOpts::ShellOpts object
  # those name-value pairs can be iterated using ShellOpts::ShellOpts#each so
  # the following is equivalent:
  #
  #   args = ShellOpts.each(USAGE, ARGS) { |name, value| ... }
  #
  #   opts, args = ShellOpts.each(USAGE, ARGS)
  #   opts.each { |name, value| ... }
  # 
  # The value of an option is its argument, the value of a command is an array
  # of name/value pairs of options and subcommands
  #
  def self.each(usage, args, program_name: PROGRAM, &block)
    @shellopts.nil? or raise InternalError, "ShellOpts class variable already initialized"
    @shellopts = ShellOpts.new(usage, argv, program_name: program_name)
    if block_given?
      @shellopts.each(&block)
      @shellopts.args
    else
      [@shellopts, @shellopts.args]
    end
  end

  def self.process(usage, args, program_name: PROGRAM, &block)
    self.each(usage, args, program_name, &block)
  end 

  # Process command line and return a hash-like ShellOpts::Hash object and a list of the
  # remaining command line arguments:
  #
  #   opts, args = ShellOpts.hash(usage, ARGV)
  #
# def self.hash(usage, args, program_name: PROGRAM)
#   @shellopts.nil? or raise InternalError, "ShellOpts class variable already initialized"
#   @shellopts = ShellOpts.new(usage, argv, program_name: PROGRAM)
#   [::ShellOpts::OptionsHash.new(@shellopts.ast), @shellopts.args]
# end

  # Process command line and return a ShellOpts::Struct object and a list of the remaining 
  # command line arguments:
  #
  #   opts, args = ShellOpts.struct(usage, ARGV)
  #
  def self.struct(usage, args, program_name: PROGRAM)
    @shellopts.nil? or raise InternalError, "ShellOpts class variable already initialized"
    @shellopts = ShellOpts.new(usage, argv, program_name: PROGRAM)
    [::ShellOpts::OptionsStruct.new(@shellopts.ast), @shellopts.args]
  end

  # Reset the hidden +ShellOpts::ShellOpts+ class variable so that you can process
  # another command line
  def self.reset()
    @shellopts = nil
    @usage = nil
  end

  # Print error message and usage string and exit with status 1. It use the
  # current ShellOpts object if defined. This method should be called in
  # response to user-errors (eg. specifying an illegal option)
  #
  # If there is no current ShellOpts object +error+ will look for USAGE to make
  # it possible to use +error+ before the command line is processed and also as
  # a stand-alone error reporting method
  def self.error(*msgs)
    program = @shellopts&.program_name || PROGRAM
    usage_string = usage || (defined?(USAGE) && USAGE ? Grammar.compile(PROGRAM, USAGE).usage : nil)
    emit_and_exit(program, @usage.nil?, usage_string, *msgs)
  end

  # Print error message and exit with status 1. It use the current ShellOpts
  # object if defined. This method should not be called in response to
  # user-errors but system errors (like disk full)
  def self.fail(*msgs)
    program = @shellopts&.program_name || PROGRAM
    emit_and_exit(program, false, nil, *msgs)
  end

private
  @shellopts = nil

  def self.emit_and_exit(program, use_usage, usage, *msgs)
    $stderr.puts "#{program}: #{msgs.join}"
    if use_usage
      $stderr.puts "Usage: #{program} #{usage}" if usage
    else
      $stderr.puts usage if usage
    end
    exit 1
  end
end

PROGRAM = File.basename($PROGRAM_NAME)










__END__

  # Process command line options and arguments.  #process takes a usage string
  # defining the options and the array of command line arguments to be parsed
  # as arguments
  #
  # If called with a block, the block is called with name and value of each
  # option or command and #process returns a list of remaining command line
  # arguments. If called without a block a ShellOpts::ShellOpts object is
  # returned
  #
  # Example
  #
  #   # Define options
  #   USAGE = 'a,all g,global +v,verbose h,help save! snapshot f,file=FILE h,help'
  #
  #   # Define defaults
  #   all = false
  #   global = false
  #   verbose = 0
  #   save = false
  #   snapshot = false
  #   file = nil
  #
  #   # Process options
  #   argv = ShellOpts.process(USAGE, ARGV) do |name, value|
  #     case name
  #       when '-a', '--all'; all = true
  #       when '-g', '--global'; global = value
  #       when '-v', '--verbose'; verbose += 1
  #       when '-h', '--help'; print_help(); exit(0)
  #       when 'save'
  #         save = true
  #         value.each do |name, value|
  #           case name
  #             when '--snapshot'; snapshot = true
  #             when '-f', '--file'; file = value
  #             when '-h', '--help'; print_save_help(); exit(0)
  #           end
  #         end
  #     else
  #       raise "Not a user error. The developer forgot or misspelled an option"
  #     end
  #   end
  #
  #   # Process remaining arguments
  #   argv.each { |arg| ... }
  #
  # Example
  #   # Define options
  #   USAGE = 'a,all g,global +v,verbose h,help save! snapshot f,file=FILE h,help'
  #
  #   # Process options
  #   opts, argv = ShellOpts.process(USAGE, ARGV)
  #
  #
  #   # Get option values # TODO Lookup rails multiassign
  #   all = opts[:all] # true or nil
  #   global = opts[:global]
  #   verbose = opts.count(:verbose)
  #   if save = opts[:save]
  #     save.key?(:help) and save_help
  #     snapshot = save[:snapshot]
  #     file = save[:file]
  #   end
  #
  #   all, global = opts[:all, :global]
  #   verbose = opts.count(:verbose)
  #
  # ########################################
  #
  #   # Require shellopts. Also defines PROGRAM
  #   require 'shellopts'
  #
  #   # Define options
  #   USAGE = 'a,all g,global +v,verbose h,help save! snapshot f,file=FILE? h,help'
  #
  #   # Process options. args is a ShellOpts::Args object derived from Array
  #   shellopts = ShellOpts.create(USAGE, ARGV) # Returns ShellOpts::ShellOpts object
  #   args = ShellOpts.each(USAGE, ARGV) { ... }
  #   array, args = ShellOpts.each(USAGE, ARGV)
  #   hash, args = ShellOpts.hash(USAGE, ARGV)
  #   opts, args = ShellOpts.struct(USAGE, ARGV)
  #
  #   opts.all => true or nil
  #   opts.global => true or nil
  #   opts.help? => true or false
  #   opts.file? => true or false
  #   opts.verbose? => true or false
  #   opts.verbose! => count
  #   opts.verbose => [] or a list of nil
  #   opts.verbose.size
  #   opts.file => string or nil (because argument is optional)
  #
  #   # Getting command line arguments
  #   arg1, arg2 = args.expect(:>=, 2)
  #   arg1, arg2 = args.expect { |a| a.size >= 2 }
  #
  #   # Error handling
  #   ShellOpts.error("Illegal number of arguments")
  #   ShellOpts.fail("Filesystem full")
  #
  #   USAGE = 'a,all g,global +v,verbose h,help save! snapshot f,file=FILE? h,help'
  #   OPTS, ARGS = ShellOpts.opts(USAGE, ARGV)
  #
  #   OPTS.all => ...
  #
  #
  #
  #
  #
  #
  # If an error is encountered while compiling the usage string, a
  # +ShellOpts::Compiler+ exception is raised. If the error happens while
  # parsing the command line arguments, the program prints an error message and
  # exits with status 1. Failed assertions raise a +ShellOpts::InternalError+
  # exception
  #
  # Note that you can't process more than one command line at a time because
  # #process saves a hidden {ShellOpts::ShellOpts} class variable used by the
  # class methods #error and #fail. Call #reset to clear the global object if
  # you really need to parse more than one command line. Alternatively you can
  # create +ShellOpts::ShellOpts+ objects yourself and also use the object methods
  # #error and #fail:
  #
  #   shellopts = ShellOpts::ShellOpts.new(USAGE, ARGS)
  #   shellopts.each { |name, value| ... }
  #   shellopts.args.each { |arg| ... }
  #   shellopts.error("Something went wrong")
  #
  # Use #shellopts to get the hidden +ShellOpts::ShellOpts+ object
  #

