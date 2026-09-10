import transform
type
    component* = object 
        transform*: Transform

    entity* = ref object of RootObj
        components*: seq[component]