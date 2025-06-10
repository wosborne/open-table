module PropertyHelper
  def property_symbol(type)
    case type
    when "id"
      "fa-square-binary"
    when "text"
      "fa-font"
    when "number"
      "fa-hashtag"
    when "select"
      "fa-caret-down"
    when "date"
      "fa-calendar"
    when "formula"
      "fa-calculator"
    when "linked_record"
      "fa-arrows-up-down"
    when "checkbox"
      "fa-square-check"
    else ""
    end
  end
end
