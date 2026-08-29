require "./parent"

module CreateChildCircularAssociationSpec
  class Child < TestRecord
    id_column id : Int64
    belongs_to Parent
    column name : String
  end
end
