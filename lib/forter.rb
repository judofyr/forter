require 'rubygems'
require 'delegate'
require 'treetop'
Treetop.load(File.dirname(__FILE__) + '/grammar.tt')

class ForterParser
  def parse!(s)
    if res = parse(s)
      res
    else
      raise failure_reason
    end
  end
  
  def parse(s)
    super(cleanup(s))
  end
  
  def cleanup(s)
    newline = false  # previous was a newline
    colon = false    # previous was a colon
    quote = false    # inside a quote
    
    s.gsub(/./m) do |c|
      # remove all spaces unless it's in quotes
      # remove newlines after a newline or a colon
      res = if !quote && c =~ /\s/ && (c != "\n" || colon || newline)
        ''
      else
        c
      end 
      quote = !quote if (c == '"')
      colon = (c == ":")
      newline = (c == "\n")
      res
    end.strip + "\n"
  end
end

module Forter
  class Value < SimpleDelegator
    def redefine(value)
      return self if value == self
      if __getobj__.is_a?(Value)
        __getobj__.redefine(value)
      else
        __setobj__(value)
      end
    end
  end

  class Evaluator
    attr_accessor :end
    
    def initialize
      @end = false
      @lines = {}
      @current_line = -1
      @values = {}
    end
    
    def add_line(line, *commands)
      @lines[line] = commands
    end
    
    def run!
      until @end
        self.next
      end
    end
    
    def next
      line, commands = @lines.sort_by { |l, c| l }.detect { |l, c| l > @current_line }
      commands.each { |command| command.evaluate(self) }
      @current_line = line
    end
    
    def value(i)
      @values[i] ||= Value.new(i)
    end
  end
end