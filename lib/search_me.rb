require_relative 'search_me/search'
require_relative 'search_me/filters'

module SearchMe

  class Config
    attr_accessor :time_field
    def initialize
      # Set Defaults
      @time_field = :created_at

      yield(self) if block_given?
    end
  end

  extend self

  def self.config(&block)
    if block_given?
      @config = Config.new(&block) 
    else
      @config ||= Config.new
    end
  end
end
