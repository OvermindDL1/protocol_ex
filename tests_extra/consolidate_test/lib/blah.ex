import ProtocolEx

defprotocolEx Blah do
  def empty(a)
  def succ(a)
  def add(a, b)
  def map(a, f) when is_function(f, 1)

  def a_fallback(a), do: inspect(a)
end

defprotocolEx Bloop do
  def get(thing)
  def get_with_fallback(thing), do: {:fallback, thing}
end
