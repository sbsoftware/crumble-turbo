module CreateChildCircularAssociationSpec
  class Child < TestRecord
    id_column id : Int64
    column name : String
  end
end

require "./parent"

module CreateChildCircularAssociationSpec
  class Child
    belongs_to Parent
  end
end
