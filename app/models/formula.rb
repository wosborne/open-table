class Formula < ApplicationRecord
  belongs_to :property

  def calculate(item)
    parsed_formula_data = JSON.parse(formula_data)

    array = parsed_formula_data.map { |formula|
      case formula["type"]
      when "operator", "unit"
        formula["value"]
      when "property"
        item.properties[formula["value"]]
      end
    }

    calculator = Dentaku::Calculator.new
    calculator.evaluate(array.join(" "))
  end
end
