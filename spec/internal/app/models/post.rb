# frozen_string_literal: true

class Post < ApplicationRecord
  belongs_to :user

  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
end
