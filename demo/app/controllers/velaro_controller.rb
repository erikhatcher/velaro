class VelaroController < ApplicationController
  layout false
  
  def index
    @var = "whatever"
  end
  
  def example
    @foo = "FOO"
  end

  def example2
    @bar = "BAR"
  end
end
