module SearchMe
  module Configuration
    class Config
      attr_accessor :time_field
      def initialize
        # Set Defaults
        @time_field = :created_at

        yield(self) if block_given?
      end
    end

    def search_me_config(&block)
      if block_given?
        @_search_me_config = Config.new(&block) 
      else
        @_search_me_config ||= Config.new
      end
    end
  end
end
