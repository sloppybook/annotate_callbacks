# frozen_string_literal: true

module Legacy
  class Account < ApplicationRecord
    before_save :normalize_name
    after_create :send_notification

    def normalize_name
      self.name = name.strip
    end

    def send_notification
      Notifier.call(self)
    end
  end
end
