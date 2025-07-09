class Link < ApplicationRecord
  belongs_to :from_record, class_name: "Record"
  belongs_to :to_record, class_name: "Record"

  belongs_to :property
end
