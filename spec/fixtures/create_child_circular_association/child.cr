require "./parent"

module CreateChildCircularAssociationSpec
  class Child < TestRecord
    id_column id : Int64
    column name : String
    belongs_to Parent
  end
end
