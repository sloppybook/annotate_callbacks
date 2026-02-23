class PlainModel < ApplicationRecord
  has_many :items

  scope :recent, -> { order(created_at: :desc) }

  def full_name
    "#{first_name} #{last_name}"
  end
end
