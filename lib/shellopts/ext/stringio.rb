
module Ext
  module StringIO
    module Redirect
      # Refining the singleton class causes methods to be defined as class methods
      refine ::StringIO.singleton_class do

        # :call-seq:
        #   redirect(devices...) { ... }
        #   redirect(devices-including-stdin..., string) { ... }
        #
        # Redirects the given standard input/output device to/from a string by
        # setting the global $stdin, $stdout, $stderr variables(!)
        #
        # +devices+ can be one of :stdin, :stdout, :stderr or any combination
        # of them. +string+ should be set to the input string if :stdin is
        # included in the devices
        #
        # Returns a string containing the output of stdout/stderr or nil if it
        # only redirected :stdin
        #
        def redirect(arg, *args, &block)
          args = ([arg] + args).flatten.uniq
          string = args.pop and string.is_a?(String) or raise ArgumentError if args.include? :stdin
          args.all? { |a| [:stdin, :stdout, :stderr].include? a } or raise ArgumentError

          stdin = $stdin
          stdout = $stdout
          stderr = $stderr
          out = nil

          begin
            if args.include? :stdin
              $stdin = ::StringIO.new(string)
              args.delete :stdin
            end

            if !args.empty?
              out = ::StringIO.new
              $stdout = out if args.include? :stdout
              $stderr = out if args.include? :stderr
            end

            yield
          ensure
            $stdin = stdin
            $stdout = stdout
            $stderr = stderr
          end

          out&.string
        end
      end
    end
  end
end

