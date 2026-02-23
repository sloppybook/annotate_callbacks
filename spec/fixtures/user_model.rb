class User < ApplicationRecord
  has_many :posts
  has_many :comments

  before_validation :normalize_email
  before_save :encrypt_password
  after_create :send_welcome_email
  after_save :update_cache, if: :saved_change_to_name?
  before_destroy :check_admin, :cleanup_data

  scope :active, -> { where(active: true) }

  def normalize_email
    self.email = email.downcase.strip
  end

  def encrypt_password
    self.password_digest = BCrypt::Password.create(password)
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end

  def update_cache
    Rails.cache.delete("user_#{id}")
  end

  def check_admin
    throw(:abort) if admin?
  end

  def cleanup_data
    posts.destroy_all
  end
end
