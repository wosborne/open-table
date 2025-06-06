module DateHelper
  def format_options
    [
      [ "dd/mm/yyyy", "%d/%m/%Y" ],
      [ "dd-mm-yyyy", "%d-%m-%Y" ],
      [ "mm/dd/yyyy", "%m/%d/%Y" ],
      [ "mm-dd-yyyy", "%m-%d-%Y" ],
      [ "yyyy/mm/dd", "%Y/%m/%d" ],
      [ "yyyy-mm-dd", "%Y-%m-%d" ]
    ]
  end
end
