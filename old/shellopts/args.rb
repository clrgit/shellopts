
module ShellOpts
  # Specialization of Array for arguments lists. Args extends Array with a
  # #extract and an #expect method to extract elements from the array. The
  # methods raise a ShellOpts::UserError exception in case of errors
  class Args < Array
    def initialize(shellopts, *args)
      @shellopts = shellopts
      super(*args)
    end

    # Remove and return elements from beginning of the array
    #
    # If +count_or_range+ is a number, that number of elements will be
    # returned.  If the count is one, a simple value is returned instead of an
    # array. If the count is negative, the elements will be removed from the
    # end of the array. If +count_or_range+ is a range, the number of elements
    # returned will be in that range. The range can't contain negative numbers 
    #
    # #extract raise a ShellOpts::UserError exception if there's is not enough
    # elements in the array to satisfy the request
    def extract(count_or_range, message = nil) 
      case count_or_range
        when Range
          range = count_or_range
          range.min <= self.size or inoa(message)
          n_extract = [self.size, range.max].min
          n_extend = range.max > self.size ? range.max - self.size : 0
          r = self.shift(n_extract) + Array.new(n_extend)
          range.max <= 1 ? r.first : r
        when Integer
          count = count_or_range
          count.abs <= self.size or inoa(message)
          start = count >= 0 ? 0 : size + count
          r = slice!(start, count.abs)
          r.size <= 0 ? nil : (r.size == 1 ? r.first : r)
        else
          raise ArgumentError
      end
    end

    # As #extract except it doesn't allow negative counts and that the array is
    # expect to be emptied by the operation
    #
    # #expect raise a ShellOpts::UserError exception if the array is not emptied 
    # by the operation
    def expect(count_or_range, message = nil)
      case count_or_range
        when Range
          count_or_range === self.size or inoa(message)
        when Integer
          count_or_range >= 0 or raise ArgumentError, "Count can't be negative"
          count_or_range.abs == self.size or inoa(message)
      end
      extract(count_or_range) # Can't fail
    end

  private
    def inoa(message = nil) 
      raise Error.new(nil), message || "Illegal number of arguments"
    end
  end
end
