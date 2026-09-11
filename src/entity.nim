import transform
type
    component* = object 
        transform*: Transform

    entity* = ref object of RootObj
        components*: seq[component]

proc transform*(e: entity): var Transform =
  return e.components[0].transform