# == Callbacks ==
#
#   before_save  :do_something
#
# == End Callbacks ==

class AnnotatedModel < ApplicationRecord
  before_save :do_something

  def do_something
    true
  end
end
