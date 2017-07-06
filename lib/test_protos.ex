# 
#
# import ProtocolEx
#
# # Only wrapping everything up in modules to prevent having to make more `.ex` files
# defmodule Testering do
#
#   defprotocolEx Blah do
#     def empty(a)
#   end
#
# end
#
# defmodule Testering1 do
#   defimplEx Integer, i when is_integer(i), for: Testering.Blah do
#     def empty(_), do: 0
#   end
# end
#
# defmodule Testering2 do
#   defimplEx TaggedTuple.Vwoop, {Vwoop, i} when is_integer(i), for: Testering.Blah do
#     def empty(_), do: {Vwoop, 0}
#   end
# end
#
# defmodule TesteringResolved do # This thing could easily become a compiler plugin instead of an explicit call
#   ProtocolEx.resolveProtocolEx(Testering.Blah, [
#     Integer,
#     TaggedTuple.Vwoop,
#   ])
# end
